import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/fixture.dart';
import 'services/api_key_store.dart';
import 'services/sport_api.dart';

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

final apiProvider = Provider<SportApi?>((ref) {
  final k = ref.watch(apiKeyProvider).valueOrNull;
  if (k == null || k.isEmpty) return null;
  return SportApi(k);
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final fixturesProvider = FutureProvider<List<Fixture>>((ref) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.fixturesByDate(ref.watch(selectedDateProvider));
});

final eventsProvider =
    FutureProvider.family<List<FixtureEvent>, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.events(id);
});

final h2hProvider =
    FutureProvider.family<List<Fixture>, (int, int)>((ref, ids) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  return api.h2h(ids.$1, ids.$2);
});

final leagueFormProvider =
    FutureProvider.family<Map<int, List<String>>, int>((ref, leagueId) async {
  final api = ref.watch(apiProvider);
  if (api == null || leagueId == 0) return {};
  return api.leagueForm(leagueId);
});
