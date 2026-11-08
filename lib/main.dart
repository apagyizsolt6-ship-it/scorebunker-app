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
import 'screens/trends_page.dart';
import 'services/alerts.dart';

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
      home: const HomeScreen(),
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
    if (list == null || !list.any((m) => m.isLive)) return;
    ref.invalidate(fixturesProvider);
  }

  void _syncNotifications() {
    ref.read(notifSyncProvider.notifier).sync();
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
    }
  }

  /// Gól-jelzés a kedvenc csapatok meccsein (megnyitott appnál).
  void _onScores(Map<int, LiveScore>? prev, Map<int, LiveScore> next) {
    if (!ref.read(settingsProvider).notifyGoals) return;
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
      if (f == null) continue;
      if (!(favs.containsKey(f.homeId) || favs.containsKey(f.awayId))) continue;

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

  @override
  Widget build(BuildContext context) {
    // Az élő kapcsolat itt indul el és marad életben.
    ref.watch(liveProvider.select((s) => s.conn));

    // Kezdés-értesítések újraütemezése, ha bármi változik.
    ref.listen(apiProvider, (_, __) => _syncNotifications());
    ref.listen(favoritesProvider, (_, __) => _syncNotifications());
    ref.listen(
      settingsProvider.select((s) => (s.notifyKickoff, s.kickoffMinutes)),
      (_, __) => _syncNotifications(),
    );
    ref.listen<Map<int, LiveScore>>(
      liveProvider.select((s) => s.scores),
      _onScores,
    );

    const pages = <Widget>[
      MatchesPage(),
      TrendsPage(),
      SlipWizardPage(),
      ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < pages.length; i++)
            _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
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
