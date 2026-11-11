import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../models/team.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'match_detail_screen.dart';
import 'player_screen.dart';

/// Csapatoldal: áttekintés (adatok, következő meccsek, eredmények), keret, trófeák.
class TeamScreen extends ConsumerWidget {
  final int teamId;
  final String name;

  const TeamScreen({super.key, required this.teamId, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).containsKey(teamId);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: isFav ? 'Eltávolítás a kedvencekből' : 'Kedvencnek jelölöm',
              icon: Icon(
                isFav ? Icons.star : Icons.star_border,
                color: isFav ? Colors.amber : null,
              ),
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(teamId, name),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Áttekintés'),
              Tab(text: 'Keret'),
              Tab(text: 'Trófeák'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(teamId: teamId),
            _SquadTab(teamId: teamId, teamName: name),
            _TrophiesTab(teamId: teamId),
          ],
        ),
      ),
    );
  }
}

Widget _loading() => const Center(child: CircularProgressIndicator());

Widget _section(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );

// ==================== ÁTTEKINTÉS ====================
class _OverviewTab extends ConsumerWidget {
  final int teamId;
  const _OverviewTab({required this.teamId});

  Widget _info(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontSize: 13)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// A kiválasztott csapat szemszögéből: Gy / D / V.
  (String, Color)? _result(Fixture m) {
    if (!m.isFinished || !m.hasScore) return null;
    final home = m.homeId == teamId;
    final mine = home ? m.homeScore! : m.awayScore!;
    final theirs = home ? m.awayScore! : m.homeScore!;
    if (mine > theirs) return ('Gy', Colors.green);
    if (mine < theirs) return ('V', Colors.red);
    return ('D', Colors.grey);
  }

  Widget _match(BuildContext context, Fixture m) {
    final r = _result(m);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: m)),
        ),
        leading: r == null
            ? const Icon(Icons.schedule, size: 20)
            : CircleAvatar(
                radius: 14,
                backgroundColor: r.$2,
                child: Text(r.$1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
        title: Text('${m.homeTeam} – ${m.awayTeam}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${m.date} • ${leagueHu(m.leagueName)}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: m.hasScore
            ? Text('${m.homeScore} - ${m.awayScore}',
                style: const TextStyle(fontWeight: FontWeight.w800))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider(teamId));
    return team.when(
      loading: _loading,
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(teamProvider(teamId)),
      ),
      data: (t) {
        if (t == null) return const Center(child: Text('Nincs adat.'));
        final upcoming = t.matches.where((m) => m.isScheduled).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final results = t.matches.where((m) => m.isFinished).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(teamProvider(teamId));
            await ref.read(teamProvider(teamId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TeamLogo(teamId: teamId, size: 44),
                          Expanded(
                            child: Text(t.name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _info(Icons.flag_outlined, 'Ország',
                          t.country.isEmpty ? '' : countryHu(t.country)),
                      _info(Icons.location_city_outlined, 'Város', t.city),
                      _info(Icons.stadium_outlined, 'Stadion', t.stadium),
                      _info(Icons.person_outline, 'Edző', t.coach),
                      _info(Icons.cake_outlined, 'Alapítva',
                          t.founded == null ? '' : '${t.founded}'),
                      _info(Icons.emoji_events_outlined, 'Sorozatok',
                          t.leagues.map(leagueHu).join(', ')),
                    ],
                  ),
                ),
              ),
              if (upcoming.isNotEmpty) ...[
                _section(context, 'Következő meccsek'),
                for (final m in upcoming.take(5)) _match(context, m),
              ],
              if (results.isNotEmpty) ...[
                _section(context, 'Utolsó eredmények'),
                for (final m in results.take(8)) _match(context, m),
              ],
              if (upcoming.isEmpty && results.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('Nincs elérhető meccs-adat.',
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== KERET ====================
class _SquadTab extends ConsumerWidget {
  final int teamId;
  final String teamName;
  const _SquadTab({required this.teamId, required this.teamName});

  int _order(String pos) {
    final p = pos.toLowerCase();
    if (p.contains('goal')) return 0;
    if (p.contains('def')) return 1;
    if (p.contains('mid')) return 2;
    if (p.contains('for') || p.contains('att') || p.contains('strik')) return 3;
    return 4;
  }

  static const _titles = [
    'Kapusok',
    'Védők',
    'Középpályások',
    'Támadók',
    'Egyéb',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squad = ref.watch(squadProvider(teamId));
    return squad.when(
      loading: _loading,
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(squadProvider(teamId)),
      ),
      data: (players) {
        if (players.isEmpty) {
          return const Center(child: Text('Nincs elérhető keret-adat.'));
        }
        final groups = <int, List<SquadPlayer>>{};
        for (final p in players) {
          groups.putIfAbsent(_order(p.position), () => []).add(p);
        }
        final keys = groups.keys.toList()..sort();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            for (final k in keys) ...[
              _section(context, '${_titles[k]} (${groups[k]!.length})'),
              for (final p in (groups[k]!
                ..sort((a, b) => (a.number ?? 999).compareTo(b.number ?? 999))))
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        name: p.name,
                        teamId: teamId,
                        teamName: teamName,
                        shirt: p.number,
                        position: p.position,
                        nationality: p.nationality,
                        age: p.age,
                      ),
                    ),
                  ),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(p.number?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Expanded(
                        child: Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        [
                          if (p.nationality.isNotEmpty) p.nationality,
                          if (p.age != null) '${p.age} év',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ==================== TRÓFEÁK ====================
class _TrophiesTab extends ConsumerWidget {
  final int teamId;
  const _TrophiesTab({required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(trophiesProvider(teamId));
    return data.when(
      loading: _loading,
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(trophiesProvider(teamId)),
      ),
      data: (list) {
        final wins = <String, List<int>>{};
        final seconds = <String, List<int>>{};
        for (final t in list) {
          if (t.name.isEmpty) continue;
          if (t.position == 1) wins.putIfAbsent(t.name, () => []).add(t.year);
          if (t.position == 2) {
            seconds.putIfAbsent(t.name, () => []).add(t.year);
          }
        }
        final names = {...wins.keys, ...seconds.keys}.toList()
          ..sort((a, b) {
            final c = (wins[b]?.length ?? 0).compareTo(wins[a]?.length ?? 0);
            if (c != 0) return c;
            return (seconds[b]?.length ?? 0)
                .compareTo(seconds[a]?.length ?? 0);
          });
        if (names.isEmpty) {
          return const Center(child: Text('Nincs elérhető trófea-adat.'));
        }
        String years(List<int>? l) {
          if (l == null || l.isEmpty) return '';
          final s = [...l]..sort((a, b) => b.compareTo(a));
          return s.take(8).join(', ') + (s.length > 8 ? ', …' : '');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final n in names)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      if (wins[n] != null)
                        Text('🏆 ${wins[n]!.length}×  ${years(wins[n])}',
                            style: const TextStyle(fontSize: 12)),
                      if (seconds[n] != null)
                        Text('🥈 ${seconds[n]!.length}×  ${years(seconds[n])}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
