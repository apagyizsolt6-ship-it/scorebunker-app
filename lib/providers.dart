import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/fixture.dart';
import 'models/live_score.dart';
import 'models/match_extras.dart';
import 'models/standing.dart';
import 'services/api_key_store.dart';
import 'services/live_socket.dart';
import 'services/prefs_store.dart';
import 'services/sport_api.dart';

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
