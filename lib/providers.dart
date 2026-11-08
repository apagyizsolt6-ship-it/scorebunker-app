import 'dart:math' as math;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/league_catalog.dart';
import 'models/fixture.dart';
import 'models/live_score.dart';
import 'models/match_extras.dart';
import 'models/slip.dart';
import 'models/standing.dart';
import 'models/trend.dart';
import 'services/api_key_store.dart';
import 'services/live_socket.dart';
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
final standingsCacheProvider =
    Provider<Map<int, LeagueTable>>((ref) => <int, LeagueTable>{});

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
  }
  trends.sort((a, b) {
    final s = b.strength.compareTo(a.strength);
    if (s != 0) return s;
    final h = b.hits.compareTo(a.hits);
    if (h != 0) return h;
    return byKickoff(a.fixture, b.fixture);
  });
  return TrendsResult(
    trends: trends,
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
