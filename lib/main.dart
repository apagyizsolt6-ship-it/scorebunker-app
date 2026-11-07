import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/match.dart';
import 'data/mock_data.dart';
import 'screens/match_detail_screen.dart';

void main() {
  runApp(const ScorebunkerApp());
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
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
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

// ==================== MECCSEK ====================
class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scorebunker'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockMatches.length,
        itemBuilder: (context, index) {
          final match = mockMatches[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MatchCard(match: match),
          );
        },
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final Match match;
  const MatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(match: match),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    match.league,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(match.time, style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.homeTeam,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  const Text('vs', style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Text(
                      match.awayTeam,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _CornerChip(label: 'Hazai szöglet', value: match.homeCornersAvg),
                  const SizedBox(width: 8),
                  _CornerChip(label: 'Vendég szöglet', value: match.awayCornersAvg),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        match.mainTrend,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${match.trendStrength}/10',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerChip extends StatelessWidget {
  final String label;
  final double value;
  const _CornerChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== TRENDEK ====================
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
              title: Text(t['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
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
class SlipWizardPage extends StatefulWidget {
  const SlipWizardPage({super.key});

  @override
  State<SlipWizardPage> createState() => _SlipWizardPageState();
}

class _SlipWizardPageState extends State<SlipWizardPage> {
  final Set<String> selected = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szelvényvarázsló'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Válassz ki trendeket, és a varázsló összeállítja a szelvényt',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: mockMatches.map((match) {
                final isSelected = selected.contains(match.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selected.add(match.id);
                        } else {
                          selected.remove(match.id);
                        }
                      });
                    },
                    title: Text('${match.homeTeam} - ${match.awayTeam}'),
                    subtitle: Text(match.mainTrend),
                    secondary: Text('${match.trendStrength}/10'),
                  ),
                );
              }).toList(),
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
                              content: Text('${selected.length} esemény kiválasztva.\n\n(Később ide jön az odds és a kombináció)'),
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
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
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
            leading: const Icon(Icons.settings),
            title: const Text('Beállítások'),
            onTap: () {},
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
