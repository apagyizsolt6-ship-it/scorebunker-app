import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

// ==================== MECCSEK OLDAL ====================
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          MatchCard(
            home: 'Nottingham Forest',
            away: 'Manchester City',
            league: 'Premier League',
            time: '18:30',
            homeCorners: 5.0,
            awayCorners: 8.2,
            trend: 'City szögletei 5.5 felett',
            trendStrength: 9,
          ),
          SizedBox(height: 12),
          MatchCard(
            home: 'Arsenal',
            away: 'Chelsea',
            league: 'Premier League',
            time: '16:00',
            homeCorners: 6.1,
            awayCorners: 5.4,
            trend: 'Mindkét csapat 4.5+ szöglet',
            trendStrength: 7,
          ),
          SizedBox(height: 12),
          MatchCard(
            home: 'Liverpool',
            away: 'Tottenham',
            league: 'Premier League',
            time: '14:00',
            homeCorners: 7.3,
            awayCorners: 4.8,
            trend: 'Liverpool saját szöglet 6.5+',
            trendStrength: 8,
          ),
        ],
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final String home;
  final String away;
  final String league;
  final String time;
  final double homeCorners;
  final double awayCorners;
  final String trend;
  final int trendStrength;

  const MatchCard({
    super.key,
    required this.home,
    required this.away,
    required this.league,
    required this.time,
    required this.homeCorners,
    required this.awayCorners,
    required this.trend,
    required this.trendStrength,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Később: MatchDetailScreen
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
                    league,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(time, style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      home,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  const Text('vs', style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Text(
                      away,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Szöglet átlagok
              Row(
                children: [
                  _CornerChip(label: 'Hazai szöglet', value: homeCorners),
                  const SizedBox(width: 8),
                  _CornerChip(label: 'Vendég szöglet', value: awayCorners),
                ],
              ),
              const SizedBox(height: 12),
              // Trend jelzés
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trend,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '$trendStrength/10',
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

// ==================== TREND EK ====================
class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trendek'), centerTitle: true),
      body: const Center(
        child: Text('Trendek oldal – hamarosan'),
      ),
    );
  }
}

// ==================== SZELVÉNY VARÁZSLÓ ====================
class SlipWizardPage extends StatelessWidget {
  const SlipWizardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szelvényvarázsló'), centerTitle: true),
      body: const Center(
        child: Text('Szelvényvarázsló – hamarosan'),
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
      body: const Center(
        child: Text('PRO előfizetés és beállítások'),
      ),
    );
  }
}
