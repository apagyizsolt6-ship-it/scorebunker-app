import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'data/league_catalog.dart';
import 'models/backtest.dart';
import 'models/calibration.dart';
import 'models/fixture.dart';
import 'models/leaders.dart';
import 'models/league_info.dart';
import 'models/live_score.dart';
import 'models/match_extras.dart';
import 'models/player_stats.dart';
import 'models/reminder.dart';
import 'models/slip.dart';
import 'models/standing.dart';
import 'models/team_adjust.dart';
import 'models/team.dart';
import 'models/trend.dart';
import 'services/api_key_store.dart';
import 'services/backtest_store.dart';
import 'services/calibration_store.dart';
import 'services/elo.dart';
import 'services/disk_cache.dart';
import 'services/estimator.dart';
import 'services/live_socket.dart';
import 'services/alerts.dart';
import 'services/prefs_store.dart';
import 'services/season_sim.dart';
import 'services/team_index.dart';
import 'services/slip_store.dart';
import 'services/sport_api.dart';
import 'services/trend_engine.dart';
import 'services/update_check.dart';

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

  void setNotifyStatus(bool v) {
    state = state.copyWith(notifyStatus: v);
    SettingsStore.save(state);
  }

  void setNotifyRed(bool v) {
    state = state.copyWith(notifyRed: v);
    SettingsStore.save(state);
  }

  void setQuietEnabled(bool v) {
    state = state.copyWith(quietEnabled: v);
    SettingsStore.save(state);
  }

  void setQuietHours(int start, int end) {
    state = state.copyWith(quietStart: start, quietEnd: end);
    SettingsStore.save(state);
  }

  void setAccent(int index) {
    state = state.copyWith(accentIndex: index);
    SettingsStore.save(state);
  }

  void setOled(bool v) {
    state = state.copyWith(oledBlack: v);
    SettingsStore.save(state);
  }

  void setMorningEnabled(bool v) {
    state = state.copyWith(morningEnabled: v);
    SettingsStore.save(state);
  }

  void setMorningHour(int h) {
    state = state.copyWith(morningHour: h);
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

/// Kézi frissítéskor megkerüli a lemezes cache-t.
final forceFixturesFetchProvider = StateProvider<bool>((ref) => false);

/// A REST-ről érkezett nyers lista. A mai élő adat rövid, a jövőbeni
/// program és a lezárt napok hosszabb cache-élettartamot kapnak.
final fixturesProvider = FutureProvider<List<Fixture>>((ref) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  final date = ref.watch(selectedDateProvider);
  final force = ref.read(forceFixturesFetchProvider);
  final now = DateTime.now();
  final selectedDay = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final ttl = selectedDay == today
      ? const Duration(seconds: 20)
      : selectedDay.isAfter(today)
          ? const Duration(minutes: 10)
          : const Duration(hours: 24);

  try {
    final list = await api.fixturesByDate(date, ttl: ttl, force: force);
    if (force) {
      try {
        ref.read(forceFixturesFetchProvider.notifier).state = false;
      } catch (_) {}
    }
    // A látott csapatok bekerülnek a csapatkeresőbe.
    Future.microtask(() {
      try {
        ref.read(teamIndexProvider.notifier).add(list);
      } catch (_) {}
    });
    return list;
  } catch (_) {
    if (force) {
      try {
        ref.read(forceFixturesFetchProvider.notifier).state = false;
      } catch (_) {}
    }
    rethrow;
  }
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
  final calib = ref.watch(calibrationProvider);
  final elo = ref.watch(eloProvider);

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
    final est = estimateMatch(t, f.homeId, f.awayId, elo: elo);
    if (est != null) {
      estimates.add(FixtureEstimate(f, calibrateEstimate(est, calib)));
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
  final calib = ref.watch(calibrationProvider);
  final elo = ref.watch(eloProvider);
  final adjust = ref.watch(teamAdjustProvider);
  final tableFuture = ref.watch(standingsProvider(k.$1).future);
  // A H2H hibája nem akaszthatja meg a becslést: a hibát azonnal elnyeljük.
  final h2hSafe = ref
      .watch(h2hProvider((k.$2, k.$3)).future)
      .then<List<Fixture>?>((v) => v, onError: (Object _) => null);
  try {
    final t = await tableFuture;
    final h2h = await h2hSafe;
    final raw =
        estimateMatch(t, k.$2, k.$3, h2h: h2h, elo: elo, adjust: adjust);
    return raw == null ? null : calibrateEstimate(raw, calib);
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
        final isPast = dt.isBefore(DateTime(today.year, today.month, today.day));
        final list = await api.fixturesByDate(
          dt,
          ttl: isPast ? const Duration(hours: 12) : const Duration(minutes: 30),
        );
        for (final f in list) {
          fx[f.id] = f;
        }
      } on ApiException catch (e) {
        if (e.status == 429 || e.status == 401) rethrow;
      }
    }
  }
  // A lejátszott meccsekből frissítjük a kalibrációs táblát is.
  final calib = buildCalibration(log, fx);
  final reliability = buildReliability(log, fx);
  Future.microtask(() {
    try {
      final cur = ref.read(calibrationProvider);
      if (!cur.sameAs(calib)) ref.read(calibrationProvider.notifier).set(calib);
      ref.read(reliabilityProvider.notifier).setIfChanged(reliability);
    } catch (_) {}
  });
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
const int _morningIdBase = 1400000000;

class _MorningPick {
  final String label;
  final String match;
  final double p;
  const _MorningPick(this.label, this.match, this.p);
}

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
    for (var i = 0; i < 3; i++) {
      await Alerts.cancel(_morningIdBase + i);
    }

    final wantKick = s.notifyKickoff && favs.isNotEmpty;
    if (api == null || (!wantKick && !s.morningEnabled)) {
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

      if (wantKick) {
        for (final f in list) {
          final kick = f.kickoff;
          if (!f.isScheduled || kick == null) continue;
          if (!(favs.containsKey(f.homeId) || favs.containsKey(f.awayId))) {
            continue;
          }
          final at = kick.subtract(Duration(minutes: s.kickoffMinutes));
          if (!at.isAfter(now.add(const Duration(minutes: 1)))) continue;
          if (isQuiet(s, at)) continue; // csendes órákban nem jelzünk
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

      if (s.morningEnabled) {
        await _scheduleMorning(api, s, favs, day, d, list);
      }
    }
    await NotifStore.save(ids);
    state = DateTime.now();
  }

  /// A nap reggeli összefoglalója: a kedvencek meccsei és a legerősebb esélyek.
  Future<void> _scheduleMorning(
    SportApi api,
    AppSettings s,
    Map<int, String> favs,
    DateTime day,
    int index,
    List<Fixture> list,
  ) async {
    final at = DateTime(day.year, day.month, day.day, s.morningHour);
    if (!at.isAfter(DateTime.now().add(const Duration(minutes: 1)))) return;
    if (isQuiet(s, at)) return;

    final open = [
      for (final f in list)
        if (f.isScheduled) f,
    ]..sort(byKickoff);
    if (open.isEmpty) return;

    final mine = [
      for (final f in open)
        if (favs.containsKey(f.homeId) || favs.containsKey(f.awayId)) f,
    ];

    final buf = StringBuffer();
    if (mine.isNotEmpty) {
      buf.writeln('Kedvenceid:');
      for (final f in mine.take(6)) {
        final k = f.kickoff;
        final time = k == null ? '' : '${DateFormat('HH:mm').format(k)} ';
        buf.writeln('• $time${f.homeLabel} – ${f.awayLabel}');
      }
    } else if (favs.isNotEmpty) {
      buf.writeln('A kedvenceidnek ma nincs meccse.');
    }

    final picks = await _topPicks(api, open);
    if (picks.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('Legerősebb esélyek (becslés):');
      for (final p in picks) {
        buf.writeln('• ${(p.p * 100).round()}% ${p.label} – ${p.match}');
      }
    }
    if (buf.isNotEmpty) buf.writeln();
    buf.write('A mai kínálatban ${open.length} meccs van.');

    await Alerts.scheduleMorning(
      id: _morningIdBase + index,
      title: '☀️ Mai meccsek',
      body: buf.toString().trimRight(),
      at: at,
    );
  }

  /// A nap 3 legerősebb esélye a top ligák és a kedvencek bajnokságaiból.
  Future<List<_MorningPick>> _topPicks(SportApi api, List<Fixture> open) async {
    final favs = ref.read(favoritesProvider);
    final calib = ref.read(calibrationProvider);
    final elo = ref.read(eloProvider);

    final leagues = <int>{};
    for (final f in open) {
      if (f.leagueId == 0) continue;
      final fav = favs.containsKey(f.homeId) || favs.containsKey(f.awayId);
      if (fav || topLeagueOf(f) != null) leagues.add(f.leagueId);
    }
    final tables = <int, LeagueTable>{};
    for (final id in leagues.take(10)) {
      try {
        tables[id] = await api.standings(id);
      } catch (_) {}
    }

    final cands = <_MorningPick>[];
    for (final f in open) {
      final t = tables[f.leagueId];
      if (t == null) continue;
      final raw = estimateMatch(t, f.homeId, f.awayId, elo: elo);
      if (raw == null) continue;
      final e = calibrateEstimate(raw, calib);
      final match = '${f.homeLabel}–${f.awayLabel}';

      final r = [
        (Pick.home, e.home),
        (Pick.draw, e.draw),
        (Pick.away, e.away),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      if (r.first.$2 >= 0.55) {
        final label = switch (r.first.$1) {
          Pick.home => '${f.homeLabel} nyer',
          Pick.away => '${f.awayLabel} nyer',
          _ => 'Döntetlen',
        };
        cands.add(_MorningPick(label, match, r.first.$2));
      }
      final g = e.over25 >= e.under25
          ? (Pick.over25, e.over25)
          : (Pick.under25, e.under25);
      if (g.$2 >= 0.62) cands.add(_MorningPick(g.$1.long, match, g.$2));
      final b = e.bttsYes >= e.bttsNo
          ? (Pick.bttsYes, e.bttsYes)
          : (Pick.bttsNo, e.bttsNo);
      if (b.$2 >= 0.62) cands.add(_MorningPick(b.$1.long, match, b.$2));
    }
    cands.sort((a, b) => b.p.compareTo(a.p));
    return cands.take(3).toList();
  }
}

final notifSyncProvider =
    NotifierProvider<NotifSyncNotifier, DateTime?>(NotifSyncNotifier.new);

// ==================== KALIBRÁCIÓ ====================
class CalibrationNotifier extends Notifier<Calibration> {
  @override
  Calibration build() {
    _load();
    return Calibration.empty();
  }

  Future<void> _load() async {
    final c = await CalibrationStore.load();
    if (c != null) state = c;
  }

  void set(Calibration c) {
    state = c;
    CalibrationStore.save(c);
  }
}

final calibrationProvider =
    NotifierProvider<CalibrationNotifier, Calibration>(CalibrationNotifier.new);

// ==================== EMLÉKEZTETŐK (EGY-EGY MECCSRE) ====================
const int _reminderIdBase = 1500000000;

class RemindersNotifier extends Notifier<Map<int, Reminder>> {
  @override
  Map<int, Reminder> build() {
    _load();
    return const <int, Reminder>{};
  }

  Future<void> _load() async {
    final m = await ReminderStore.load();
    final now = DateTime.now().millisecondsSinceEpoch;
    final live = <int, Reminder>{
      for (final e in m.entries)
        if (e.value.atMs > now) e.key: e.value,
    };
    if (live.length != m.length) ReminderStore.save(live);
    if (live.isNotEmpty) state = live;
  }

  /// Bekapcsolja vagy lemondja a meccs emlékeztetőjét.
  Future<ReminderResult> toggle(Fixture f) async {
    if (state.containsKey(f.id)) {
      await Alerts.cancel(_reminderIdBase + f.id);
      final next = <int, Reminder>{...state}..remove(f.id);
      state = next;
      ReminderStore.save(next);
      return ReminderResult.removed;
    }
    final kick = f.kickoff;
    if (kick == null) return ReminderResult.noTime;
    final minutes = ref.read(settingsProvider).kickoffMinutes;
    final at = kick.subtract(Duration(minutes: minutes));
    if (!at.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return ReminderResult.tooLate;
    }
    await Alerts.requestPermission();
    final title = '⏰ ${f.homeLabel} – ${f.awayLabel}';
    final body =
        '${leagueHu(f.leagueName)} • kezdés ${DateFormat('HH:mm').format(kick)}';
    await Alerts.scheduleKickoff(
      id: _reminderIdBase + f.id,
      title: title,
      body: body,
      at: at,
    );
    final next = <int, Reminder>{
      ...state,
      f.id: Reminder(
        fixtureId: f.id,
        title: title,
        body: body,
        atMs: at.millisecondsSinceEpoch,
      ),
    };
    state = next;
    ReminderStore.save(next);
    return ReminderResult.added;
  }
}

final remindersProvider =
    NotifierProvider<RemindersNotifier, Map<int, Reminder>>(
        RemindersNotifier.new);

// ==================== BAJNOKSÁG-SZŰRŐ (KIEMELÉS / ELREJTÉS) ====================
class LeaguePrefsNotifier extends Notifier<LeaguePrefs> {
  @override
  LeaguePrefs build() {
    _load();
    return const LeaguePrefs();
  }

  Future<void> _load() async {
    state = await LeaguePrefsStore.load();
  }

  void _set(Set<int> pinned, Set<int> hidden) {
    state = LeaguePrefs(pinned: pinned, hidden: hidden);
    LeaguePrefsStore.save(state);
  }

  void togglePin(int id) {
    final pinned = <int>{...state.pinned};
    final hidden = <int>{...state.hidden};
    if (!pinned.remove(id)) {
      pinned.add(id);
      hidden.remove(id);
    }
    _set(pinned, hidden);
  }

  void toggleHide(int id) {
    final pinned = <int>{...state.pinned};
    final hidden = <int>{...state.hidden};
    if (!hidden.remove(id)) {
      hidden.add(id);
      pinned.remove(id);
    }
    _set(pinned, hidden);
  }

  void clearHidden() => _set(state.pinned, <int>{});
}

final leaguePrefsProvider =
    NotifierProvider<LeaguePrefsNotifier, LeaguePrefs>(LeaguePrefsNotifier.new);

final allLeaguesProvider =
    FutureProvider.autoDispose<List<LeagueInfo>>((ref) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.leagues();
});

// ==================== KEDVENCEK HETI NAPTÁRA ====================
/// A kedvenc csapatok meccsei a következő 7 napra (napi lekérések, 60 percig
/// gyorsítótárazva): dátum (yyyy-MM-dd) -> meccsek.
final favCalendarProvider =
    FutureProvider.autoDispose<Map<String, List<Fixture>>>((ref) async {
  final api = ref.watch(apiProvider);
  final favs = ref.watch(favoritesProvider);
  if (api == null || favs.isEmpty) return <String, List<Fixture>>{};

  final now = DateTime.now();
  final out = <String, List<Fixture>>{};
  for (var d = 0; d < 7; d++) {
    final day = DateTime(now.year, now.month, now.day + d);
    final key = DateFormat('yyyy-MM-dd').format(day);
    try {
      final list = await api.fixturesByDate(day, ttl: const Duration(minutes: 60));
      final mine = [
        for (final f in list)
          if (favs.containsKey(f.homeId) || favs.containsKey(f.awayId)) f,
      ]..sort(byKickoff);
      if (mine.isNotEmpty) out[key] = mine;
    } on ApiException catch (e) {
      if (e.status == 429 || e.status == 401) rethrow;
    }
  }
  return out;
});

// ==================== TABELLA-ELŐREJELZÉS ====================
final projectionProvider =
    FutureProvider.autoDispose.family<Projection?, int>((ref, leagueId) async {
  final t = await ref.watch(standingsProvider(leagueId).future);
  if (t.rows.isEmpty) return null;
  return simulateSeason(t);
});

// ==================== BAJNOKSÁGONKÉNTI MEGBÍZHATÓSÁG ====================
class ReliabilityNotifier extends Notifier<Map<int, LeagueReliability>> {
  @override
  Map<int, LeagueReliability> build() {
    _load();
    return const <int, LeagueReliability>{};
  }

  Future<void> _load() async {
    final m = await ReliabilityStore.load();
    if (m.isNotEmpty) state = m;
  }

  void setIfChanged(Map<int, LeagueReliability> m) {
    final cur = state;
    var same = cur.length == m.length;
    if (same) {
      for (final e in m.entries) {
        final c = cur[e.key];
        if (c == null || !c.sameAs(e.value)) {
          same = false;
          break;
        }
      }
    }
    if (same) return;
    state = m;
    ReliabilityStore.save(m);
  }
}

final reliabilityProvider =
    NotifierProvider<ReliabilityNotifier, Map<int, LeagueReliability>>(
        ReliabilityNotifier.new);

// ==================== ELO CSAPATERŐ ====================
/// A lejátszott meccsekből (az utolsó ~45 nap, utána naponta egy lekérés)
/// épített Elo-szerű csapaterő. A múltbeli napok listája a lemezen marad.
class EloNotifier extends Notifier<EloState> {
  bool _busy = false;
  Future<void>? _loaded;

  @override
  EloState build() {
    _loaded = _load();
    return EloState.empty;
  }

  Future<void> _load() async {
    final s = await EloStore.load();
    if (s != null) state = s;
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> sync() async {
    if (_busy) return;
    final api = ref.read(apiProvider);
    if (api == null) return;
    _busy = true;
    try {
      await _loaded;
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      DateTime start = yesterday.subtract(const Duration(days: 44));
      final last = DateTime.tryParse(state.lastDate);
      if (last != null) {
        start = DateTime(last.year, last.month, last.day + 1);
      }
      if (start.isAfter(yesterday)) return;

      var s = state;
      var cur = start;
      var processed = 0;
      while (!cur.isAfter(yesterday) && processed < 60) {
        try {
          final list =
              await api.fixturesByDate(cur, ttl: const Duration(days: 14));
          s = applyEloResults(s, list, _key(cur));
          ref.read(teamIndexProvider.notifier).add(list);
          processed++;
        } on ApiException catch (e) {
          if (e.status == 429 || e.status == 401) break;
          // más hiba: ezt a napot kihagyjuk
          s = EloState(
              ratings: s.ratings, games: s.games, lastDate: _key(cur));
        } catch (_) {
          break;
        }
        cur = DateTime(cur.year, cur.month, cur.day + 1);
      }
      if (processed > 0) {
        state = s;
        await EloStore.save(s);
      }
    } finally {
      _busy = false;
    }
  }
}

final eloProvider = NotifierProvider<EloNotifier, EloState>(EloNotifier.new);

// ==================== KÖVETETT MECCSEK ====================
class FollowedNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _load();
    return const <int>{};
  }

  Future<void> _load() async {
    final s = await FollowedStore.load();
    if (s.isNotEmpty) state = s;
  }

  void toggle(int fixtureId) {
    final next = <int>{...state};
    if (!next.remove(fixtureId)) {
      next.add(fixtureId);
      while (next.length > 30) {
        next.remove(next.first);
      }
    }
    state = next;
    FollowedStore.save(next);
  }
}

final followedProvider =
    NotifierProvider<FollowedNotifier, Set<int>>(FollowedNotifier.new);

// ==================== FRISSÍTÉS-ELLENŐRZÉS ====================
final updateProvider = FutureProvider<UpdateInfo?>((ref) => checkForUpdate());

/// Az a build-szám, amelynek a jelzését a felhasználó elnyomta.
final updateDismissedProvider = StateProvider<int>((ref) => 0);

// ==================== KEDVENC JÁTÉKOSOK ====================
class FavPlayersNotifier extends Notifier<Map<String, FavPlayer>> {
  @override
  Map<String, FavPlayer> build() {
    _load();
    return const <String, FavPlayer>{};
  }

  Future<void> _load() async {
    final m = await FavPlayersStore.load();
    if (m.isNotEmpty) state = m;
  }

  void toggle(FavPlayer p) {
    final next = <String, FavPlayer>{...state};
    if (next.remove(p.key) == null) next[p.key] = p;
    state = next;
    FavPlayersStore.save(next);
  }

  void remove(String key) {
    final next = <String, FavPlayer>{...state}..remove(key);
    state = next;
    FavPlayersStore.save(next);
  }
}

final favPlayersProvider =
    NotifierProvider<FavPlayersNotifier, Map<String, FavPlayer>>(
        FavPlayersNotifier.new);

// ==================== CSAPATKERESŐ (HELYI INDEX) ====================
class TeamIndexNotifier extends Notifier<Map<int, TeamEntry>> {
  Timer? _saveTimer;

  @override
  Map<int, TeamEntry> build() {
    ref.onDispose(() => _saveTimer?.cancel());
    _load();
    return const <int, TeamEntry>{};
  }

  Future<void> _load() async {
    final m = await TeamIndexStore.load();
    if (m.isNotEmpty) state = <int, TeamEntry>{...m, ...state};
  }

  /// A meccslistában látott csapatok hozzáadása (a bajnokság a legelső látott).
  void add(List<Fixture> list) {
    Map<int, TeamEntry>? next;
    void put(int id, String name, String league) {
      if (id == 0 || name.isEmpty) return;
      final cur = (next ?? state)[id];
      if (cur == null || cur.name != name || (cur.league.isEmpty && league.isNotEmpty)) {
        next ??= <int, TeamEntry>{...state};
        next![id] = TeamEntry(id, name, cur != null && cur.league.isNotEmpty ? cur.league : league);
      }
    }

    for (final f in list) {
      put(f.homeId, f.homeTeam, f.leagueName);
      put(f.awayId, f.awayTeam, f.leagueName);
    }
    final n = next;
    if (n == null) return;
    state = n;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), () {
      TeamIndexStore.save(state);
    });
  }
}

final teamIndexProvider =
    NotifierProvider<TeamIndexNotifier, Map<int, TeamEntry>>(
        TeamIndexNotifier.new);

// ==================== KÉZI CSAPAT-KORREKCIÓ ====================
class TeamAdjustNotifier extends Notifier<Map<int, TeamAdjust>> {
  @override
  Map<int, TeamAdjust> build() {
    _load();
    return const <int, TeamAdjust>{};
  }

  Future<void> _load() async {
    final m = await TeamAdjustStore.load();
    if (m.isNotEmpty) state = m;
  }

  void set(int teamId, TeamAdjust a) {
    final next = <int, TeamAdjust>{...state};
    if (a.isNeutral) {
      next.remove(teamId);
    } else {
      next[teamId] = a;
    }
    state = next;
    TeamAdjustStore.save(next);
  }

  void clear(int teamId) {
    final next = <int, TeamAdjust>{...state}..remove(teamId);
    state = next;
    TeamAdjustStore.save(next);
  }
}

final teamAdjustProvider =
    NotifierProvider<TeamAdjustNotifier, Map<int, TeamAdjust>>(
        TeamAdjustNotifier.new);
