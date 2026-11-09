import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/fixture.dart';
import '../models/leaders.dart';
import '../models/league_info.dart';
import '../models/match_extras.dart';
import '../models/player_stats.dart';
import '../models/standing.dart';
import '../models/team.dart';
import 'disk_cache.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);

  @override
  String toString() => message;
}

String errorText(Object e) => e is ApiException ? e.message : 'Hiba: $e';

/// A válaszfejlécekből kiolvasott kérés-keret (napi / havi).
class ApiQuota {
  final int? dayLimit;
  final int? dayRemaining;
  final DateTime? dayReset;
  final int? monthLimit;
  final int? monthRemaining;
  final DateTime? monthReset;
  final DateTime at;

  const ApiQuota({
    this.dayLimit,
    this.dayRemaining,
    this.dayReset,
    this.monthLimit,
    this.monthRemaining,
    this.monthReset,
    required this.at,
  });
}

class _Cached {
  final String etag;
  final Map<String, dynamic> body;
  const _Cached(this.etag, this.body);
}

class SportApi {
  final String key;
  final void Function(ApiQuota quota)? onQuota;

  SportApi(this.key, {this.onQuota});

  static const _base = 'https://sportapi.ai/api';

  /// ETag-gyorsítótár: ha az adat nem változott, a szerver 304-et ad,
  /// és a korábbi választ használjuk újra.
  static final LinkedHashMap<String, _Cached> _cache =
      LinkedHashMap<String, _Cached>();

  static ApiQuota? _quotaFrom(Map<String, String> h) {
    int? i(String k) => int.tryParse(h[k] ?? '');
    DateTime? t(String k) {
      final s = i(k);
      return s == null ? null : DateTime.fromMillisecondsSinceEpoch(s * 1000);
    }

    final dl = i('x-ratelimit-limit');
    final dr = i('x-ratelimit-remaining');
    final ml = i('x-ratelimit-month-limit');
    final mr = i('x-ratelimit-month-remaining');
    if (dl == null && dr == null && ml == null && mr == null) return null;
    return ApiQuota(
      dayLimit: dl,
      dayRemaining: dr,
      dayReset: t('x-ratelimit-reset'),
      monthLimit: ml,
      monthRemaining: mr,
      monthReset: t('x-ratelimit-month-reset'),
      at: DateTime.now(),
    );
  }

  static String _dur(int s) {
    if (s >= 3600) return '${(s / 3600).round()} óra';
    if (s >= 60) return '${(s / 60).round()} perc';
    return '$s mp';
  }

  static String _limitMessage(http.Response res) {
    var scope = 'day';
    try {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      if (b is Map && b['scope'] is String) scope = b['scope'] as String;
    } catch (_) {}
    final retry = int.tryParse(res.headers['retry-after'] ?? '');
    final when = retry == null ? '' : ' Újra elérhető kb. ${_dur(retry)} múlva.';
    if (scope == 'month') {
      return 'Elérted a havi kérés-limitet (Free csomag: 14 000/hó).$when';
    }
    return 'Elérted a napi kérés-limitet.$when';
  }

  /// `ttl`: ennyi ideig a lemezre mentett válasz kérés nélkül is használható.
  /// `force`: kihagyja a lemezes gyorsítótárat.
  Future<Map<String, dynamic>> _get(
    String path, {
    Duration? ttl,
    bool force = false,
  }) async {
    if (ttl != null && !force) {
      final hit = await DiskCache.read(path, ttl);
      if (hit != null) return hit;
    }
    final cached = _cache[path];
    final headers = <String, String>{
      'X-Api-Key': key,
      'Accept': 'application/json',
      if (cached != null) 'If-None-Match': cached.etag,
    };

    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$_base$path'), headers: headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException('Időtúllépés, próbáld újra.');
    } catch (_) {
      throw const ApiException('Nincs kapcsolat a szerverrel.');
    }

    final q = _quotaFrom(res.headers);
    if (q != null && onQuota != null) onQuota!(q);

    if (res.statusCode == 304 && cached != null) {
      if (ttl != null) unawaited(DiskCache.write(path, cached.body));
      return cached.body;
    }
    if (res.statusCode == 401) {
      throw const ApiException('Hiányzó vagy érvénytelen API-kulcs.', 401);
    }
    if (res.statusCode == 429) {
      throw ApiException(_limitMessage(res), 429);
    }
    if (res.statusCode == 404) {
      throw const ApiException('Nem található.', 404);
    }
    if (res.statusCode != 200) {
      throw ApiException('Szerverhiba (${res.statusCode}).', res.statusCode);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw const ApiException('Váratlan válasz a szervertől.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Váratlan válasz a szervertől.');
    }
    final Map<String, dynamic> body = decoded;

    if (ttl != null) unawaited(DiskCache.write(path, body));

    final etag = res.headers['etag'];
    if (etag != null && etag.isNotEmpty) {
      _cache.remove(path);
      _cache[path] = _Cached(etag, body);
      if (_cache.length > 80) _cache.remove(_cache.keys.first);
    }
    return body;
  }

  List<Fixture> _fixtures(dynamic data) => [
        for (final x in (data as List? ?? const []))
          if (x is Map<String, dynamic>) Fixture.fromJson(x),
      ];

  /// `ttl`: ha meg van adva, a lemezes gyorsítótárból is jöhet a lista.
  Future<List<Fixture>> fixturesByDate(DateTime d, {Duration? ttl}) async {
    final j = await _get(
      '/fixtures/date/${DateFormat('yyyy-MM-dd').format(d)}',
      ttl: ttl,
    );
    return _fixtures(j['data']);
  }

  /// Egy meccs részletei + események egyetlen hívásban.
  Future<FixtureDetail?> fixtureDetail(int fixtureId) async {
    final j = await _get('/fixtures/$fixtureId');
    final f = j['fixture'];
    if (f is! Map) return null;
    return FixtureDetail.fromJson(Map<String, dynamic>.from(f));
  }

  /// Meccsstatisztika; null, ha nincs elérhető adat.
  Future<MatchStats?> stats(int fixtureId) async {
    final j = await _get('/fixtures/$fixtureId/stats');
    if (j['available'] != true) return null;
    final d = j['data'];
    if (d is! Map) return null;
    final s = MatchStats.fromJson(Map<String, dynamic>.from(d));
    return s.isEmpty ? null : s;
  }

  /// Összeállítások; null, ha nincs elérhető adat.
  Future<Lineups?> lineups(int fixtureId) async {
    final j = await _get('/fixtures/$fixtureId/lineups');
    if (j['available'] != true) return null;
    final d = j['data'];
    if (d is! Map) return null;
    final l = Lineups.fromJson(Map<String, dynamic>.from(d));
    return l.isEmpty ? null : l;
  }

  Future<List<Fixture>> h2h(int team1, int team2) async {
    final j = await _get(
      '/fixtures/h2h/$team1/$team2',
      ttl: const Duration(hours: 24),
    );
    return _fixtures(j['data']);
  }

  /// Teljes tabella a csapatok utolsó meccseivel (form).
  /// 4 óráig a lemezről jön, ha nincs `force`.
  Future<LeagueTable> standings(int leagueId, {bool force = false}) async {
    final j = await _get(
      '/standings/$leagueId',
      ttl: const Duration(hours: 4),
      force: force,
    );
    return LeagueTable.fromJson(j);
  }

  /// Góllövők / gólpasszok / lapok egy bajnokságban (6 óráig gyorsítótárazva).
  Future<List<LeaderRow>> leaders(
    int leagueId,
    LeaderKind kind, {
    int limit = 25,
  }) async {
    final j = await _get(
      '/leagues/$leagueId/${kind.path}?limit=$limit',
      ttl: const Duration(hours: 6),
    );
    final d = j['data'];
    return [
      if (d is List)
        for (final x in d)
          if (x is Map) LeaderRow.fromJson(Map<String, dynamic>.from(x), kind),
    ];
  }

  Future<TeamInfo> team(int teamId) async {
    final j = await _get('/teams/$teamId', ttl: const Duration(hours: 3));
    return TeamInfo.fromJson(j);
  }

  Future<List<SquadPlayer>> squad(int teamId) async {
    final j = await _get(
      '/teams/$teamId/squad',
      ttl: const Duration(hours: 12),
    );
    final d = j['squad'];
    return [
      if (d is List)
        for (final x in d)
          if (x is Map) SquadPlayer.fromJson(Map<String, dynamic>.from(x)),
    ];
  }

  Future<List<Trophy>> trophies(int teamId) async {
    final j = await _get(
      '/teams/$teamId/trophies',
      ttl: const Duration(hours: 24),
    );
    final d = j['trophies'];
    return [
      if (d is List)
        for (final x in d)
          if (x is Map) Trophy.fromJson(Map<String, dynamic>.from(x)),
    ];
  }

  /// Játékos szezon-statisztikája név + csapat (+ mezszám) alapján.
  Future<PlayerStats?> playerStats(String name, int teamId, int? shirt) async {
    final q = 'name=${Uri.encodeComponent(name)}&team_id=$teamId'
        '${shirt == null ? '' : '&shirt_number=$shirt'}';
    final j = await _get('/players/stats?$q', ttl: const Duration(hours: 6));
    return PlayerStats.fromJson(j);
  }

  /// Az összes bajnokság (országonként csoportosítva), 24 óráig gyorsítótárazva.
  Future<List<LeagueInfo>> leagues() async {
    final j = await _get('/leagues', ttl: const Duration(hours: 24));
    return LeagueInfo.parseAll(j['data']);
  }
}
