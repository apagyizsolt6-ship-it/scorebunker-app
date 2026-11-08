import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'data/league_catalog.dart';
import 'models/backtest.dart';
import 'models/fixture.dart';
import 'models/leaders.dart';
import 'models/live_score.dart';
import 'models/match_extras.dart';
import 'models/player_stats.dart';
import 'models/slip.dart';
import 'models/standing.dart';
import 'models/team.dart';
import 'models/trend.dart';
import 'services/api_key_store.dart';
import 'services/backtest_store.dart';
import 'services/disk_cache.dart';
import 'services/estimator.dart';
import 'services/live_socket.dart';
import 'services/alerts.dart';
import 'services/prefs_store.dart';
import 'services/slip_store.dart';
import 'services/sport_api.dart';
import 'services/trend_engine.dart';

// ==================== API-KULCS ====================
class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ApiKeyStore.load();

  Future<void> setKey(String key) async {
    await ApiKeyStore.save(key);
    state = AsyncData(key);
  }

  Future<void> clear() async {
    await ApiKeyStore.clear();
    state = const AsyncData(null);
  }
}

final apiKeyProvider =
    AsyncNotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

/// Az utolsó válaszfejlécekből kiolvasott napi / havi kérés-keret.
final quotaProvider = StateProvider<ApiQuota?>((ref) => null);

final apiProvider = Provider<SportApi?>((ref) {
  final k = ref.watch(apiKeyProvider).valueOrNull;
  if (k == null || k.isEmpty) return null;
  var alive = true;
  ref.onDispose(() => alive = false);
  return SportApi(
    k,
    onQuota: (q) {
      Future.microtask(() {
        if (alive) ref.read(quotaProvider.notifier).state = q;
      });
    },
  );
});

// ==================== BEÁLLÍTÁSOK ====================
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    state = await SettingsStore.load();
  }

  void setShowLogos(bool v) {
    state = state.copyWith(showLogos: v);
    SettingsStore.save(state);
  }

  void setThemeMode(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    SettingsStore.save(state);
  }

  void setNotifyKickoff(bool v) {
    state = state.copyWith(notifyKickoff: v);
    SettingsStore.save(state);
  }

  void setKickoffMinutes(int m) {
    state = state.copyWith(kickoffMinutes: m);
    SettingsStore.save(state);
  }

  void setNotifyGoals(bool v) {
    state = state.copyWith(notifyGoals: v);
    SettingsStore.save(state);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ==================== KEDVENCEK ====================
class FavoritesNotifier extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() {
    _load();
    return const <int, String>{};
  }

  Future<void> _load() async {
    final m = await FavoritesStore.load();
    if (m.isNotEmpty) state = m;
  }

  void toggle(int id, String name) {
    if (id == 0) return;
    final next = <int, String>{...state};
    if (next.containsKey(id)) {
      next.remove(id);
    } else {
      next[id] = name;
    }
    state = next;
    FavoritesStore.save(next);
  }

  void remove(int id) {
    final next = <int, String>{...state}..remove(id);
    state = next;
    FavoritesStore.save(next);
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Map<int, String>>(
        FavoritesNotifier.new);

// ==================== ÉLŐ (WEBSOCKET) ====================
class LiveNotifier extends Notifier<LiveState> {
  late LiveSocket _socket;

  @override
  LiveState build() {
    _socket = LiveSocket(
      onScore: (s) {
        state = state.copyWith(scores: {...state.scores, s.fixtureId: s});
      },
      onStatus: (c) {
        state = state.copyWith(conn: c);
      },
    );
    ref.onDispose(_socket.dispose);
    ref.listen<AsyncValue<String?>>(
      apiKeyProvider,
      (_, next) => _applyKey(next.valueOrNull),
      fireImmediately: true,
    );
    return const LiveState();
  }

  void _applyKey(String? k) {
    if (k == null || k.isEmpty) {
      _socket.stop();
    } else {
      _socket.start(k);
    }
  }

  void ensureConnected() => _socket.ensure();
}

final liveProvider =
    NotifierProvider<LiveNotifier, LiveState>(LiveNotifier.new);

// ==================== MECCSLISTA ====================
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Keresőmező szövege a Meccsek fülön (csapat / bajnokság / ország).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Összecsukott országok (a zóna neve alapján).
final collapsedCountriesProvider =
    StateProvider<Set<String>>((ref) => <String>{});

enum MatchFilter { all, live, upcoming, finished }

final matchFilterProvider =
    StateProvider<MatchFilter>((ref) => MatchFilter.all);

/// Csak a kedvenc csapatok meccsei.
final favOnlyProvider = StateProvider<bool>((ref) => false);

/// A REST-ről érkezett nyers lista.
final fixturesProvider = FutureProvider<List<Fixture>>((ref) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.fixturesByDate(ref.watch(selectedDateProvider));
});

/// A nyers lista + a WebSocketen érkezett friss állások.
/// Az app minden képernyője ezt használja.
final liveFixturesProvider = Provider<AsyncValue<List<Fixture>>>((ref) {
  final base = ref.watch(fixturesProvider);
  final scores = ref.watch(liveProvider.select((s) => s.scores));
  return base.whenData((list) {
    if (scores.isEmpty) return list;
    return [
      for (final f in list)
        if (scores[f.id] != null) f.withLive(scores[f.id]!) else f,
    ];
  });
});

// ==================== MECCSRÉSZLETEK ====================
final detailProvider =
    FutureProvider.autoDispose.family<FixtureDetail?, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) return null;
  return api.fixtureDetail(id);
});

final statsProvider =
    FutureProvider.autoDispose.family<MatchStats?, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) return null;
  return api.stats(id);
});

final lineupsProvider =
    FutureProvider.autoDispose.family<Lineups?, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) return null;
  return api.lineups(id);
});

final h2hProvider =
    FutureProvider.family<List<Fixture>, (int, int)>((ref, ids) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.h2h(ids.$1, ids.$2);
});

/// Teljes tabella (forma-meccsekkel). A munkamenet alatt gyorsítótárazott.
final standingsProvider =
    FutureProvider.family<LeagueTable, int>((ref, leagueId) async {
  final api = ref.watch(apiProvider);
  if (api == null || leagueId == 0) return LeagueTable.empty;
  try {
    return await api.standings(leagueId);
  } on ApiException catch (e) {
    if (e.status == 404) return LeagueTable.empty;
    rethrow;
  }
});

// ==================== TRENDEK ====================
/// Alapból a nap MINDEN meccsét elemezzük (minden bajnokság tabelláját
/// betöltjük). Bekapcsolva csak a top ligák és a kedvencek maradnak.
final trendsTopOnlyProvider = StateProvider<bool>((ref) => false);

final trendGroupFilterProvider = StateProvider<TrendGroup?>((ref) => null);

/// A munkamenet alatt letöltött tabellák (bajnokság-azonosító -> tabella).
/// A `clear()` a lemezes tabella-gyorsítótárat is törli, így az
/// "Újraszámolás" gomb valóban friss adatot kér.
class _StandingsMemory extends MapView<int, LeagueTable> {
  _StandingsMemory() : super(<int, LeagueTable>{});

  @override
  void clear() {
    super.clear();
    DiskCache.clearSync('/standings');
  }
}

final standingsCacheProvider =
    Provider<Map<int, LeagueTable>>((ref) => _StandingsMemory());

/// Betöltési haladás: (kész, összes) tabella.
final trendsProgressProvider = StateProvider<(int, int)>((ref) => (0, 0));

/// Azok a bajnokságok, amelyek tabelláját a trendekhez le kell tölteni.
final trendLeagueIdsProvider = Provider<List<int>>((ref) {
  final list = ref.watch(fixturesProvider).valueOrNull ?? const <Fixture>[];
  final topOnly = ref.watch(trendsTopOnlyProvider);
  final favIds = ref.watch(favoritesProvider).keys.toSet();
  final ids = <int>{};
  for (final f in list) {
    if (!f.isScheduled || f.leagueId == 0) continue;
    final fav = favIds.contains(f.homeId) || favIds.contains(f.awayId);
    if (!topOnly || fav || topLeagueOf(f) != null) ids.add(f.leagueId);
  }
  return ids.toList()..sort();
});

final trendsProvider = FutureProvider<TrendsResult>((ref) async {
  final api = ref.watch(apiProvider);
  final fixtures = ref.watch(fixturesProvider).valueOrNull ?? const <Fixture>[];
  final ids = ref.watch(trendLeagueIdsProvider);
  final cache = ref.read(standingsCacheProvider);
  final progress = ref.read(trendsProgressProvider.notifier);

  if (api == null || ids.isEmpty) {
    return const TrendsResult(trends: [], matches: 0, leagues: 0, failed: 0);
  }

  var alive = true;
  ref.onDispose(() => alive = false);

  final missing = [
    for (final id in ids)
      if (!cache.containsKey(id)) id,
  ];
  Future.microtask(() => progress.state = (0, missing.length));

  var failed = 0;
  var done = 0;
  ApiException? limit;

  // Csomagokban töltünk, hogy ne zúdítsunk egyszerre száz kérést a szerverre.
  for (var i = 0; i < missing.length; i += 8) {
    if (!alive || limit != null) break;
    final batch = missing.sublist(i, math.min(i + 8, missing.length));
    await Future.wait([
      for (final id in batch)
        () async {
          try {
            cache[id] = await api.standings(id);
          } on ApiException catch (e) {
            if (e.status == 404) {
              cache[id] = LeagueTable.empty;
            } else {
              failed++;
              if (e.status == 429 || e.status == 401) limit = e;
            }
          } catch (_) {
            failed++;
          }
        }(),
    ]);
    done += batch.length;
    progress.state = (done, missing.length);
  }

  final idSet = ids.toSet();
  final lim = limit;
  final haveAny = idSet.any(cache.containsKey);
  if (lim != null && !haveAny) throw lim;

  final trends = <Trend>[];
  final estimateLog = <EstimateLogEntry>[];
  final estimates = <FixtureEstimate>[];
  var matches = 0;
  var leagues = 0;
  final seenLeagues = <int>{};
  for (final f in fixtures) {
    if (!f.isScheduled || !idSet.contains(f.leagueId)) continue;
    final t = cache[f.leagueId];
    if (t == null || t.rows.isEmpty) continue;
    matches++;
    if (seenLeagues.add(f.leagueId)) leagues++;
    trends.addAll(trendsFor(f, t.rowOf(f.homeId), t.rowOf(f.awayId)));
    final est = estimateMatch(t, f.homeId, f.awayId);
    if (est != null) {
      estimates.add(FixtureEstimate(f, est));
      estimateLog.add(EstimateLogEntry(
        fixtureId: f.id,
        date: f.date,
        home: est.home,
        draw: est.draw,
        away: est.away,
        over25: est.over25,
        btts: est.bttsYes,
      ));
    }
  }
  trends.sort((a, b) {
    final s = b.strength.compareTo(a.strength);
    if (s != 0) return s;
    final h = b.hits.compareTo(a.hits);
    if (h != 0) return h;
    return byKickoff(a.fixture, b.fixture);
  });
  // Napló a későbbi visszamérésekhez (háttérben, a végeredmény után értékeljük).
  BacktestStore.add(
    trends: [
      for (final t in trends)
        if (t.pick != null)
          TrendLogEntry(
            fixtureId: t.fixture.id,
            date: t.fixture.date,
            kind: t.kind.index,
            pick: t.pick!.name,
            strength: t.strength,
          ),
    ],
    estimates: estimateLog,
  );

  return TrendsResult(
    trends: trends,
    estimates: estimates,
    matches: matches,
    leagues: leagues,
    failed: failed,
  );
});

// ==================== SZELVÉNY ====================
class DraftLeg {
  final Fixture fixture;
  final Pick pick;
  final double? odds;
  const DraftLeg(this.fixture, this.pick, this.odds);
}

/// A most épített (még nem mentett) szelvény: meccsazonosító -> tipp.
class DraftNotifier extends Notifier<Map<int, DraftLeg>> {
  @override
  Map<int, DraftLeg> build() => const <int, DraftLeg>{};

  void set(Fixture f, Pick pick, double? odds) {
    state = {...state, f.id: DraftLeg(f, pick, odds)};
  }

  void setOdds(int id, double? odds) {
    final l = state[id];
    if (l == null) return;
    state = {...state, id: DraftLeg(l.fixture, l.pick, odds)};
  }

  void remove(int id) {
    final next = <int, DraftLeg>{...state}..remove(id);
    state = next;
  }

  void clear() => state = const <int, DraftLeg>{};
}

final draftProvider =
    NotifierProvider<DraftNotifier, Map<int, DraftLeg>>(DraftNotifier.new);

/// Mentett szelvények.
class SlipsNotifier extends Notifier<List<Slip>> {
  @override
  List<Slip> build() {
    _load();
    return const <Slip>[];
  }

  Future<void> _load() async {
    final l = await SlipStore.load();
    if (l.isNotEmpty) state = l;
  }

  void add(Slip s) {
    state = [s, ...state];
    SlipStore.save(state);
  }

  void remove(int id) {
    state = [
      for (final s in state)
        if (s.id != id) s,
    ];
    SlipStore.save(state);
  }

  void setSettled(int id, List<int> results) {
    state = [
      for (final s in state)
        if (s.id == id) s.withSettled(results) else s,
    ];
    SlipStore.save(state);
  }
}

final slipsProvider =
    NotifierProvider<SlipsNotifier, List<Slip>>(SlipsNotifier.new);

/// A mentett, még el nem dőlt szelvények meccsei (napi lekérésekkel).
final slipFixturesProvider =
    FutureProvider.autoDispose<Map<int, Fixture>>((ref) async {
  final api = ref.watch(apiProvider);
  final slips = ref.read(slipsProvider);
  if (api == null) return <int, Fixture>{};

  final dates = <String>{};
  for (final s in slips) {
    if (s.settled != null) continue;
    for (final l in s.legs) {
      if (l.date.isNotEmpty) dates.add(l.date);
    }
  }

  final now = DateTime.now();
  final out = <int, Fixture>{};
  for (final d in dates) {
    final dt = DateTime.tryParse(d);
    if (dt == null || dt.isAfter(now)) continue;
    try {
      for (final f in await api.fixturesByDate(dt)) {
        out[f.id] = f;
      }
    } on ApiException catch (e) {
      if (e.status == 429 || e.status == 401) rethrow;
    }
  }
  return out;
});

// ==================== GÓLLÖVŐK, CSAPATOLDAL, ESÉLY-BECSLÉS ====================
final leadersProvider = FutureProvider.autoDispose
    .family<List<LeaderRow>, (int, LeaderKind)>((ref, k) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.leaders(k.$1, k.$2);
});

final teamProvider =
    FutureProvider.autoDispose.family<TeamInfo?, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) return null;
  return api.team(id);
});

final squadProvider =
    FutureProvider.autoDispose.family<List<SquadPlayer>, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.squad(id);
});

final trophiesProvider =
    FutureProvider.autoDispose.family<List<Trophy>, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.trophies(id);
});

/// Becsült esélyek egy meccsre: (bajnokság, hazai, vendég) azonosítók alapján.
/// Null, ha nincs elég tabella-adat.
final estimateProvider =
    FutureProvider.family<MatchEstimate?, (int, int, int)>((ref, k) async {
  if (k.$1 == 0) return null;
  final tableFuture = ref.watch(standingsProvider(k.$1).future);
  // A H2H hibája nem akaszthatja meg a becslést: a hibát azonnal elnyeljük.
  final h2hSafe = ref
      .watch(h2hProvider((k.$2, k.$3)).future)
      .then<List<Fixture>?>((v) => v, onError: (Object _) => null);
  try {
    final t = await tableFuture;
    final h2h = await h2hSafe;
    return estimateMatch(t, k.$2, k.$3, h2h: h2h);
  } catch (_) {
    return null;
  }
});

// ==================== VISSZAMÉRÉS ====================
/// A naplózott trendek és becslések kiértékelése a lejátszott meccsek alapján.
final backtestReportProvider =
    FutureProvider.autoDispose<BacktestReport>((ref) async {
  final api = ref.watch(apiProvider);
  final log = await BacktestStore.load();
  final today = DateTime.now();

  final dates = <String>{
    for (final e in log.trends) e.date,
    for (final e in log.estimates) e.date,
  };

  final fx = <int, Fixture>{};
  if (api != null) {
    for (final d in dates) {
      final dt = DateTime.tryParse(d);
      if (dt == null || dt.isAfter(today)) continue;
      try {
        final list =
            await api.fixturesByDate(dt, ttl: const Duration(minutes: 30));
        for (final f in list) {
          fx[f.id] = f;
        }
      } on ApiException catch (e) {
        if (e.status == 429 || e.status == 401) rethrow;
      }
    }
  }
  return buildReport(log, fx);
});

// ==================== JÁTÉKOS ====================
/// (név, csapatazonosító, mezszám) alapján. Null, ha nincs adat.
final playerStatsProvider = FutureProvider.autoDispose
    .family<PlayerStats?, (String, int, int)>((ref, k) async {
  final api = ref.watch(apiProvider);
  if (api == null) return null;
  try {
    return await api.playerStats(k.$1, k.$2, k.$3 <= 0 ? null : k.$3);
  } on ApiException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
});

// ==================== ÉRTESÍTÉSEK ====================
/// A kedvenc csapatok következő meccseire (ma + 2 nap) kezdés-értesítést ütemez.
/// Minden szinkronnál előbb lemondja a korábban ütemezetteket.
class NotifSyncNotifier extends Notifier<DateTime?> {
  bool _busy = false;
  bool _again = false;

  @override
  DateTime? build() => null;

  Future<void> sync() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _run();
      } while (_again);
    } finally {
      _busy = false;
    }
  }

  Future<void> _run() async {
    final s = ref.read(settingsProvider);
    final api = ref.read(apiProvider);
    final favs = ref.read(favoritesProvider);

    final old = await NotifStore.load();
    for (final id in old) {
      await Alerts.cancel(id);
    }
    if (!s.notifyKickoff || api == null || favs.isEmpty) {
      await NotifStore.save(const <int>[]);
      state = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final ids = <int>[];
    for (var d = 0; d < 3; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      List<Fixture> list;
      try {
        list = await api.fixturesByDate(day, ttl: const Duration(minutes: 60));
      } catch (_) {
        continue;
      }
      for (final f in list) {
        final kick = f.kickoff;
        if (!f.isScheduled || kick == null) continue;
        if (!(favs.containsKey(f.homeId) || favs.containsKey(f.awayId))) {
          continue;
        }
        final at = kick.subtract(Duration(minutes: s.kickoffMinutes));
        if (!at.isAfter(now.add(const Duration(minutes: 1)))) continue;
        await Alerts.scheduleKickoff(
          id: f.id,
          title: '⚽ ${f.homeLabel} – ${f.awayLabel}',
          body: '${leagueHu(f.leagueName)} • kezdés '
              '${DateFormat('HH:mm').format(kick)}',
          at: at,
        );
        ids.add(f.id);
      }
    }
    await NotifStore.save(ids);
    state = DateTime.now();
  }
}

final notifSyncProvider =
    NotifierProvider<NotifSyncNotifier, DateTime?>(NotifSyncNotifier.new);
