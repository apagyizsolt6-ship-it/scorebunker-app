import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/fixture.dart';
import 'models/live_score.dart';
import 'providers.dart';
import 'screens/matches_page.dart';
import 'screens/profile_page.dart';
import 'screens/slip_page.dart';
import 'screens/splash_screen.dart';
import 'screens/trends_page.dart';
import 'services/alerts.dart';
import 'services/prefs_store.dart';
import 'widgets/update_banner.dart';

void main() {
  runApp(const ProviderScope(child: ScorebunkerApp()));
}

class ScorebunkerApp extends ConsumerWidget {
  const ScorebunkerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'APISCORES',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1A73E8),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1A73E8),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: mode,
      home: const SplashGate(child: HomeScreen()),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  final Set<int> _visited = {0};
  Timer? _timer;
  AppLifecycleState? _lifecycle;
  bool _settled = false;
  int _tickCount = 0;

  /// Meccsazonosító -> utoljára látott állapot (NS / LIVE / HT / FT).
  final Map<int, String> _lastState = {};

  /// Meccsazonosító -> eddig látott piros lapok száma.
  final Map<int, int> _redSeen = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Élő meccsek percadatának frissítése (a gólokat a WebSocket hozza).
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _isToday() {
    final d = ref.read(selectedDateProvider);
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  void _tick() {
    if (_lifecycle != null && _lifecycle != AppLifecycleState.resumed) return;
    if (!_isToday()) return;
    final list = ref.read(liveFixturesProvider).valueOrNull;
    if (list == null) return;
    final live = [for (final m in list) if (m.isLive) m];
    if (live.isEmpty) return;
    ref.invalidate(fixturesProvider);
    _tickCount++;
    if (_tickCount % 3 == 0) _checkRedCards(live);
  }

  void _syncNotifications() {
    ref.read(notifSyncProvider.notifier).sync();
  }

  void _syncElo() {
    ref.read(eloProvider.notifier).sync();
  }

  /// Indításkor egyszer kiértékeli a naplózott trendeket és becsléseket
  /// (a lejátszott meccsek alapján), így a kalibráció magától frissül.
  void _settleBacktest() {
    if (_settled || ref.read(apiProvider) == null) return;
    _settled = true;
    final sub = ref.listenManual(backtestReportProvider, (_, __) {});
    ref.read(backtestReportProvider.future).then(
      (_) => sub.close(),
      onError: (Object _) => sub.close(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      ref.read(liveProvider.notifier).ensureConnected();
      if (ref.read(apiProvider) != null) {
        ref.invalidate(fixturesProvider);
      }
      _syncNotifications();
      _syncElo();
    }
  }

  bool _isFav(Fixture f) {
    final favs = ref.read(favoritesProvider);
    return favs.containsKey(f.homeId) || favs.containsKey(f.awayId);
  }

  /// Gól-jelzés a kedvenc csapatok meccsein (megnyitott appnál).
  void _onScores(Map<int, LiveScore>? prev, Map<int, LiveScore> next) {
    final settings = ref.read(settingsProvider);
    if (!settings.notifyGoals || isQuiet(settings)) return;
    final favs = ref.read(favoritesProvider);
    if (favs.isEmpty) return;
    final base = ref.read(fixturesProvider).valueOrNull ?? const <Fixture>[];

    for (final e in next.entries) {
      final before = prev?[e.key];
      if (identical(before, e.value)) continue;

      Fixture? f;
      for (final x in base) {
        if (x.id == e.key) {
          f = x;
          break;
        }
      }
      if (f == null || !_isFav(f)) continue;

      final prevTotal = before == null
          ? (f.homeScore ?? 0) + (f.awayScore ?? 0)
          : (before.homeScore ?? 0) + (before.awayScore ?? 0);
      final nowTotal = (e.value.homeScore ?? 0) + (e.value.awayScore ?? 0);
      if (nowTotal <= prevTotal) continue;

      final min = e.value.minute;
      HapticFeedback.heavyImpact();
      Alerts.showGoal(
        id: 1000000000 + e.key,
        title: '⚽ GÓL!',
        body: '${f.homeLabel} ${e.value.homeScore ?? 0} – '
            '${e.value.awayScore ?? 0} ${f.awayLabel}'
            '${min == null || min.isEmpty ? '' : '  ($min)'}',
      );
    }
  }

  /// Félidő és végeredmény jelzése a kedvenc csapatok meccsein.
  void _onFixtures(AsyncValue<List<Fixture>> next) {
    final list = next.valueOrNull;
    if (list == null || !_isToday()) return;
    final s = ref.read(settingsProvider);
    final favs = ref.read(favoritesProvider);

    for (final f in list) {
      final cur = f.isFinished ? 'FT' : (f.isLive ? (f.minute == 'HT' ? 'HT' : 'LIVE') : 'NS');
      final old = _lastState[f.id];
      _lastState[f.id] = cur;
      if (old == null || old == cur) continue; // első látás: nincs jelzés
      if (!s.notifyStatus || favs.isEmpty || isQuiet(s) || !_isFav(f)) continue;

      final score =
          '${f.homeLabel} ${f.homeScore ?? 0} – ${f.awayScore ?? 0} ${f.awayLabel}';
      if (cur == 'HT' && old == 'LIVE') {
        Alerts.showGoal(id: 1100000000 + f.id, title: '⏸ Félidő', body: score);
      } else if (cur == 'FT' && (old == 'LIVE' || old == 'HT')) {
        Alerts.showGoal(id: 1100000000 + f.id, title: '🏁 Vége', body: score);
      }
    }
  }

  /// Piros lap jelzése: a kedvenc csapatok élő meccseinek eseményeit
  /// 3 percenként ellenőrzi (csak amíg az app meg van nyitva).
  Future<void> _checkRedCards(List<Fixture> live) async {
    final s = ref.read(settingsProvider);
    if (!s.notifyRed) return;
    final api = ref.read(apiProvider);
    if (api == null || ref.read(favoritesProvider).isEmpty) return;

    for (final f in live) {
      if (!_isFav(f)) continue;
      try {
        final d = await api.fixtureDetail(f.id);
        if (d == null) continue;
        final reds = [
          for (final e in d.events)
            if (e.type.contains('red')) e,
        ]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
        final before = _redSeen[f.id];
        _redSeen[f.id] = reds.length;
        if (before == null || reds.length <= before) continue;
        if (isQuiet(ref.read(settingsProvider))) continue;
        final e = reds.last;
        final team = e.side == 'home' ? f.homeLabel : f.awayLabel;
        Alerts.showGoal(
          id: 1200000000 + f.id,
          title: '🟥 Piros lap',
          body: '$team: ${e.player} (${e.minute})',
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    // Az élő kapcsolat itt indul el és marad életben.
    ref.watch(liveProvider.select((s) => s.conn));

    // Kezdés-értesítések újraütemezése, ha bármi változik.
    ref.listen(apiProvider, (_, __) {
      _syncNotifications();
      _settleBacktest();
      _syncElo();
    });
    ref.listen(favoritesProvider, (_, __) => _syncNotifications());
    ref.listen(
      settingsProvider.select((s) => (
            s.notifyKickoff,
            s.kickoffMinutes,
            s.quietEnabled,
            s.quietStart,
            s.quietEnd,
          )),
      (_, __) => _syncNotifications(),
    );
    ref.listen<Map<int, LiveScore>>(
      liveProvider.select((s) => s.scores),
      _onScores,
    );
    ref.listen(selectedDateProvider, (_, __) => _lastState.clear());
    ref.listen<AsyncValue<List<Fixture>>>(
      liveFixturesProvider,
      (_, next) => _onFixtures(next),
    );

    const pages = <Widget>[
      MatchesPage(),
      TrendsPage(),
      SlipWizardPage(),
      ProfilePage(),
    ];

    final stack = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < pages.length; i++)
          _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
      ],
    );
    final banner = updateVisible(ref);

    return Scaffold(
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: banner
                ? MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: stack,
                  )
                : stack,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() {
          _index = index;
          _visited.add(index);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Meccsek',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Trendek',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Szelvény',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
