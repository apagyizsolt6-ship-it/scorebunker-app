import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/live_score.dart';

/// A SportAPI WebSocket (wss://sportapi.ai/ws) kezelése: kapcsolódás,
/// feliratkozás az összes élő meccsre, ping és újracsatlakozás.
class LiveSocket {
  final void Function(LiveScore score) onScore;
  final void Function(LiveConn conn) onStatus;

  LiveSocket({required this.onScore, required this.onStatus});

  String? _key;
  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;
  Timer? _ping;
  Timer? _retry;
  int _attempt = 0;
  bool _stopped = true;
  bool _disposed = false;
  LiveConn _conn = LiveConn.off;

  void start(String key) {
    if (_disposed) return;
    if (!_stopped && _key == key && _conn != LiveConn.off) return;
    _key = key;
    _stopped = false;
    _attempt = 0;
    _retry?.cancel();
    _teardown();
    Future.microtask(_connect);
  }

  /// Ha a kapcsolat megszakadt (pl. háttérből visszatérve), azonnal újra próbál.
  void ensure() {
    if (_disposed || _stopped || _key == null) return;
    if (_conn == LiveConn.on) return;
    _retry?.cancel();
    _attempt = 0;
    _teardown();
    Future.microtask(_connect);
  }

  void stop() {
    _stopped = true;
    _key = null;
    _retry?.cancel();
    _teardown();
    _set(LiveConn.off);
  }

  void dispose() {
    _disposed = true;
    _stopped = true;
    _retry?.cancel();
    _teardown();
  }

  void _set(LiveConn c) {
    if (_disposed || _conn == c) return;
    _conn = c;
    onStatus(c);
  }

  void _teardown() {
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    final ch = _ch;
    _ch = null;
    if (ch != null) {
      try {
        ch.sink.close();
      } catch (_) {}
    }
  }

  Future<void> _connect() async {
    if (_stopped || _disposed) return;
    final key = _key;
    if (key == null || key.isEmpty) {
      _set(LiveConn.off);
      return;
    }
    _set(LiveConn.connecting);
    WebSocketChannel? ch;
    try {
      ch = WebSocketChannel.connect(Uri(
        scheme: 'wss',
        host: 'sportapi.ai',
        path: '/ws',
        queryParameters: {'key': key},
      ));
      _ch = ch;
      await ch.ready;
      if (_disposed || _stopped || !identical(_ch, ch)) return;
      _attempt = 0;
      _set(LiveConn.on);
      final channel = ch;
      _sub = channel.stream.listen(
        _onData,
        onDone: () => _onClosed(channel),
        onError: (Object _) => _onClosed(channel),
      );
      channel.sink.add(jsonEncode({'action': 'subscribe_all'}));
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _ch?.sink.add(jsonEncode({'action': 'ping'}));
        } catch (_) {}
      });
    } catch (_) {
      if (identical(_ch, ch)) _onClosed(ch);
    }
  }

  void _onClosed(WebSocketChannel? ch) {
    if (_disposed || _stopped) return;
    if (!identical(_ch, ch)) return;
    _teardown();
    _set(LiveConn.off);
    _retry?.cancel();
    final secs = math.min(60, 3 * math.pow(2, _attempt).toInt());
    _attempt = math.min(_attempt + 1, 6);
    _retry = Timer(Duration(seconds: secs), _connect);
  }

  void _onData(dynamic data) {
    if (_disposed) return;
    try {
      final text = data is String ? data : utf8.decode(data as List<int>);
      final s = LiveScore.tryParse(jsonDecode(text));
      if (s != null) onScore(s);
    } catch (_) {}
  }
}
