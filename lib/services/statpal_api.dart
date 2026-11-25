import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

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

class StatPalApi {
  final String key;
  final void Function(ApiQuota quota)? onQuota;

  StatPalApi(this.key, {this.onQuota});

  static const _base = 'https://statpal.io/api/v2/soccer';

  /// ETag-gyorsítótár: ha az adat nem változott, a szerver 304-et ad,
  /// és a korábbi választ használjuk újra.
  static final LinkedHashMap<String, _Cached> _cache =
      LinkedHashMap<String, _Cached>();

  /// A napi/élő feedből megőrzött nyers meccsadatok. A részletek így
  /// külön, felesleges API-hívás nélkül is megjeleníthetők.
  static final Map<int, Map<String, dynamic>> _matchPayloads = {}; 

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
      return 'Elérted a havi StatPal kérés-limitet.$when';
    }
    return 'Elérted a StatPal kérés-limitet.$when';
  }

  /// `ttl`: ennyi ideig a lemezre mentett válasz kérés nélkül is használható.
  /// `force`: kihagyja a lemezes gyorsítótárat.
  Future<Map<String, dynamic>> _get(
    String path, {
    Duration? ttl,
    bool force = false,
  }) async {
    final cacheKey = '${key.hashCode}:$path';
    if (ttl != null && !force) {
      final hit = await DiskCache.read(path, ttl);
      if (hit != null) return hit;
    }
    final cached = _cache[cacheKey];
    final headers = <String, String>{
      'Accept': 'application/json',
      if (cached != null) 'If-None-Match': cached.etag,
    };

    final http.Response res;
    try {
      final requested = Uri.parse('$_base$path');
      final query = <String, String>{...requested.queryParameters, 'access_key': key};
      res = await http
          .get(requested.replace(queryParameters: query), headers: headers)
          .timeout(const Duration(seconds: 20));
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
      _cache.remove(cacheKey);
      _cache[cacheKey] = _Cached(etag, body);
      if (_cache.length > 80) _cache.remove(_cache.keys.first);
    }
    return body;
  }

  List<Fixture> _fixtures(dynamic data, {bool live = false}) {
    final out = <Fixture>[];
    if (data is List) {
      for (final x in data) {
        if (x is Map) out.add(Fixture.fromJson(Map<String, dynamic>.from(x)));
      }
      return out;
    }
    if (data is! Map) return out;
    dynamic root = data;
    if (root['league'] is! List) {
      root = data.values.whereType<Map>().firstWhere(
        (v) => v['league'] is List, orElse: () => const <String, dynamic>{});
    }
    final leagues = root is Map ? root['league'] : null;
    if (leagues is! List) return out;
    for (final leagueValue in leagues) {
      if (leagueValue is! Map) continue;
      final league = Map<String, dynamic>.from(leagueValue);
      final matches = league['match'];
      if (matches is! List) continue;
      for (final matchValue in matches) {
        if (matchValue is Map) {
          final match = Map<String, dynamic>.from(matchValue);
          final fixture = Fixture.fromStatPal(match, league, forceLive: live);
          if (fixture.id != 0) {
            _matchPayloads[fixture.id] = {
              ...match,
              '_league': league,
            };
          }
          out.add(fixture);
        }
      }
    }
    out.sort(byKickoff);
    return out;
  }

  /// StatPal napi mérkőzéslista; az offset a mai naphoz képest értendő.
  Future<List<Fixture>> fixturesByDate(DateTime d, {Duration? ttl, bool force = false}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final offset = day.difference(today).inDays;
    if (offset < -7 || offset > 7) {
      throw const ApiException('A StatPal napi végpontja legfeljebb 7 nappal előre vagy hátra kérdezhető le.');
    }
    final j = await _get('/matches/daily?offset=$offset', ttl: ttl, force: force);
    return _fixtures(j);
  }

  /// Élő mérkőzések lekérése; StatPal REST frissítés.
  Future<List<Fixture>> liveMatches({bool force = true}) async {
    final j = await _get('/matches/live', force: force);
    return _fixtures(j, live: true);
  }

  /// A meccs eseményei és félidei állása a napi/élő feedből.
  /// A StatPal napi és élő válasza tartalmazza ezeket az adatokat.
  Future<FixtureDetail?> fixtureDetail(int fixtureId) async {
    final payload = _matchPayloads[fixtureId];
    if (payload == null) return null;
    return FixtureDetail.fromStatPal(payload);
  }

  /// Mérkőzés-statisztikák a liga mérkőzés-statisztika végpontjáról.
  Future<MatchStats?> stats(int leagueId, int fixtureId) async {
    if (leagueId <= 0 || fixtureId <= 0) return null;
    final j = await _get(
      '/leagues/$leagueId/matches/stats?match_id=$fixtureId',
      ttl: const Duration(minutes: 2),
    );
    final data = j['data'] is Map ? Map<String, dynamic>.from(j['data']) : j;
    final s = MatchStats.fromJson(data);
    return s.isEmpty ? null : s;
  }

  /// Kezdőcsapatok és cserék a StatPal meccs-összeállítás végpontjáról.
  Future<Lineups?> lineups(int fixtureId) async {
    if (fixtureId <= 0) return null;
    final j = await _get(
      '/team-lineups?match_id=$fixtureId',
      ttl: const Duration(minutes: 15),
    );
    final data = j['data'] is Map ? Map<String, dynamic>.from(j['data']) : j;
    final l = Lineups.fromJson(data);
    return l.isEmpty ? null : l;
  }

  /// Egymás elleni mérkőzések a StatPal H2H végpontjáról.
  Future<List<Fixture>> h2h(int team1, int team2) async {
    if (team1 <= 0 || team2 <= 0) return [];
    final j = await _get(
      '/head-to-head?team1_id=$team1&team2_id=$team2',
      ttl: const Duration(hours: 24),
    );
    final data = j['data'] ?? j;
    final out = <Fixture>[];
    final league = <String, dynamic>{
      'id': 0,
      'name': 'Egymás ellen',
      'country': '',
    };
    dynamic matches = data;
    if (data is Map) {
      matches = data['matches'] ?? data['match'] ?? data['fixtures'] ?? data['history'];
      if (matches == null && data['league'] is List) return _fixtures(data);
      if (matches == null && data['home'] is Map && data['away'] is Map) {
        matches = [data];
      }
    }
    if (matches is! List) return _fixtures(data);
    for (final item in matches) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      if (m['home'] is Map && m['away'] is Map) {
        final f = Fixture.fromStatPal(m, league);
        if (f.id != 0) out.add(f);
      } else {
        final f = Fixture.fromJson(m);
        if (f.id != 0) out.add(f);
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// Élő oddsok. Élő meccseknél a rövid cache a frissítési ütemet követi.
  Future<Map<String, dynamic>> liveOdds(int matchId) => _get(
        '/odds/live?match_id=$matchId',
        ttl: const Duration(seconds: 10),
      );

  /// Élő odds-piacok és market állapotok.
  Future<Map<String, dynamic>> liveOddsMarkets(int matchId) => _get(
        '/odds/live/markets?match_id=$matchId',
        ttl: const Duration(seconds: 10),
      );

  /// Mérkőzés előtti oddsok a liga odds-végpontjáról.
  Future<Map<String, dynamic>> prematchOdds(int leagueId, int matchId) => _get(
        '/leagues/$leagueId/odds/prematch?match_id=$matchId',
        ttl: const Duration(minutes: 30),
      );

  /// Sérülések és eltiltások egy csapatra.
  Future<Map<String, dynamic>> injuriesSuspensions(int teamId) {
    if (teamId <= 0) return Future.value(const <String, dynamic>{});
    return _get('/injuries-suspensions?team_id=$teamId',
        ttl: const Duration(hours: 1));
  }

  /// Teljes tabella a csapatok utolsó meccseivel (form).
  /// 4 óráig a lemezről jön, ha nincs `force`.
  Future<LeagueTable> standings(int leagueId, {bool force = false}) async {
    final j = await _get(
      '/leagues/$leagueId/standings',
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
