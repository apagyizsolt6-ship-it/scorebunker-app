import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'models/fixture.dart';
import 'providers.dart';
import 'screens/api_key_screen.dart';
import 'screens/match_detail_screen.dart';
import 'services/sport_api.dart';

void main() {
  runApp(const ProviderScope(child: ScorebunkerApp()));
}

class ScorebunkerApp extends StatelessWidget {
  const ScorebunkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scorebunker',
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
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MatchesPage(),
    TrendsPage(),
    SlipWizardPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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

void openApiKeyScreen(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ApiKeyScreen()),
  );
}

// ==================== KÖZÖS SEGÉDEK ====================
class _NoKeyView extends StatelessWidget {
  const _NoKeyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Az adatok megjelenítéséhez add meg a SportAPI kulcsodat.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => openApiKeyScreen(context),
              child: const Text('API-kulcs megadása'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isAuth = error is ApiException && (error as ApiException).status == 401;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(errorText(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (isAuth)
              FilledButton(
                onPressed: () => openApiKeyScreen(context),
                child: const Text('API-kulcs módosítása'),
              )
            else
              FilledButton(onPressed: onRetry, child: const Text('Újra')),
          ],
        ),
      ),
    );
  }
}

// ==================== MECCSEK ====================
class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyState = ref.watch(apiKeyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scorebunker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(fixturesProvider),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: _DateBar(),
        ),
      ),
      body: keyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (k) {
          if (k == null || k.isEmpty) return const _NoKeyView();
          final fixtures = ref.watch(fixturesProvider);
          return fixtures.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              error: e,
              onRetry: () => ref.invalidate(fixturesProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('Nincs meccs ezen a napon.'));
              }
              final sorted = [...list]..sort((a, b) {
                  final c = a.leagueName.compareTo(b.leagueName);
                  if (c != 0) return c;
                  return (a.kickoff ?? DateTime(0))
                      .compareTo(b.kickoff ?? DateTime(0));
                });
              final items = <Object>[];
              String? last;
              for (final m in sorted) {
                if (m.leagueName != last) {
                  items.add(m.leagueName);
                  last = m.leagueName;
                }
                items.add(m);
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(fixturesProvider);
                  await ref.read(fixturesProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MatchCard(fixture: item as Fixture),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(selectedDateProvider);
    void setDate(DateTime x) =>
        ref.read(selectedDateProvider.notifier).state = x;
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final label = DateFormat('yyyy.MM.dd').format(d) + (isToday ? ' (ma)' : '');

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setDate(DateTime(d.year, d.month, d.day - 1)),
          ),
          TextButton(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: d,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (p != null) setDate(p);
            },
            child: Text(label),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setDate(DateTime(d.year, d.month, d.day + 1)),
          ),
        ],
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final Fixture fixture;
  const MatchCard({super.key, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: f)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  f.timeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: f.isLive ? Colors.red : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.homeTeam,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(f.awayTeam,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (f.hasScore)
                Column(
                  children: [
                    Text('${f.homeScore}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${f.awayScore}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== TRENDEK (egyelőre statikus) ====================
class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final trends = [
      {'title': 'Manchester City szögletei 5.5 felett', 'strength': 9, 'matches': '11/20', 'desc': 'Idegenbeli bajnoki meccseken'},
      {'title': 'Liverpool saját szöglet 6.5+', 'strength': 8, 'matches': '8/12', 'desc': 'Hazai meccseken'},
      {'title': 'Arsenal + Chelsea együtt 9.5+ szöglet', 'strength': 7, 'matches': '7/10', 'desc': 'Egymás elleni meccseken'},
      {'title': 'Tottenham engedett szöglet 5.5+', 'strength': 6, 'matches': '9/15', 'desc': 'Idegenben'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Trendek'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trends.length,
        itemBuilder: (context, index) {
          final t = trends[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(t['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${t['desc']} • ${t['matches']} meccs'),
              ),
              trailing: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '${t['strength']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==================== SZELVÉNY VARÁZSLÓ ====================
class SlipWizardPage extends ConsumerStatefulWidget {
  const SlipWizardPage({super.key});

  @override
  ConsumerState<SlipWizardPage> createState() => _SlipWizardPageState();
}

class _SlipWizardPageState extends ConsumerState<SlipWizardPage> {
  final Set<int> selected = {};

  @override
  Widget build(BuildContext context) {
    final fixtures = ref.watch(fixturesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Szelvényvarázsló'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Válaszd ki a mérkőzéseket, és a varázsló összeállítja a szelvényt',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: fixtures.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                error: e,
                onRetry: () => ref.invalidate(fixturesProvider),
              ),
              data: (list) {
                final open = list.where((m) => m.isScheduled).toList()
                  ..sort((a, b) => (a.kickoff ?? DateTime(0))
                      .compareTo(b.kickoff ?? DateTime(0)));
                if (open.isEmpty) {
                  return const Center(
                      child: Text('Nincs kiválasztható meccs ezen a napon.'));
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: open.map((m) {
                    final isSelected = selected.contains(m.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3)
                          : null,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selected.add(m.id);
                            } else {
                              selected.remove(m.id);
                            }
                          });
                        },
                        title: Text('${m.homeTeam} - ${m.awayTeam}'),
                        subtitle: Text('${m.leagueName} • ${m.timeLabel}'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Szelvény összeállítva'),
                              content: Text(
                                  '${selected.length} esemény kiválasztva.\n\n(Később ide jön az odds és a kombináció)'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                  child: Text('Szelvény készítése (${selected.length})'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== PROFIL ====================
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _mask(String? k) {
    if (k == null || k.isEmpty) return 'Nincs megadva';
    if (k.length <= 12) return '••••••••';
    return '${k.substring(0, 8)}…${k.substring(k.length - 4)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(apiKeyProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.workspace_premium),
            title: Text('Scorebunker PRO'),
            subtitle: Text('Hamarosan elérhető'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('API-kulcs'),
            subtitle: Text(_mask(key)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openApiKeyScreen(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Névjegy'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
