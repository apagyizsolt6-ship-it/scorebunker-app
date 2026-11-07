import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/fixture.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);

  @override
  String toString() => message;
}

String errorText(Object e) => e is ApiException ? e.message : 'Hiba: $e';

class SportApi {
  final String key;
  const SportApi(this.key);

  static const _base = 'https://sportapi.ai/api';

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$_base$path'), headers: {'X-Api-Key': key})
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException('Időtúllépés, próbáld újra.');
    } catch (_) {
      throw const ApiException('Nincs kapcsolat a szerverrel.');
    }
    if (res.statusCode == 401) {
      throw const ApiException('Hiányzó vagy érvénytelen API-kulcs.', 401);
    }
    if (res.statusCode == 429) {
      throw const ApiException('Elérted a napi/havi kérés-limitet.', 429);
    }
    if (res.statusCode == 404) {
      throw const ApiException('Nem található.', 404);
    }
    if (res.statusCode != 200) {
      throw ApiException('Szerverhiba (${res.statusCode}).', res.statusCode);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Váratlan válasz a szervertől.');
    }
    return body;
  }

  List<Fixture> _fixtures(dynamic data) => [
        for (final x in (data as List? ?? const []))
          if (x is Map<String, dynamic>) Fixture.fromJson(x),
      ];

  Future<List<Fixture>> fixturesByDate(DateTime d) async {
    final j = await _get('/fixtures/date/${DateFormat('yyyy-MM-dd').format(d)}');
    return _fixtures(j['data']);
  }

  Future<List<FixtureEvent>> events(int fixtureId) async {
    final j = await _get('/fixtures/$fixtureId/events');
    return [
      for (final x in (j['data'] as List? ?? const []))
        if (x is Map<String, dynamic>) FixtureEvent.fromJson(x),
    ];
  }

  Future<List<Fixture>> h2h(int team1, int team2) async {
    final j = await _get('/fixtures/h2h/$team1/$team2');
    return _fixtures(j['data']);
  }

  /// teamId -> utolsó meccsek eredménye (W/D/L), a legrégebbi elöl.
  Future<Map<int, List<String>>> leagueForm(int leagueId) async {
    final j = await _get('/standings/$leagueId');
    final out = <int, List<String>>{};

    void readRows(dynamic rows) {
      if (rows is! List) return;
      for (final r in rows) {
        if (r is! Map) continue;
        final team = r['team'];
        final id = team is Map ? (team['id'] as num?)?.toInt() : null;
        if (id == null) continue;
        final form = r['form'];
        out[id] = [
          if (form is List)
            for (final f in form)
              if (f is Map) f['result'].toString(),
        ];
      }
    }

    readRows(j['data']);
    final groups = j['groups'];
    if (groups is List) {
      for (final g in groups) {
        if (g is Map) readRows(g['table'] ?? g['data']);
      }
    }
    return out;
  }
}
