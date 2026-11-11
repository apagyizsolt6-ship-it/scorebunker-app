import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_stats.dart';
import '../providers.dart';
import '../services/prefs_store.dart';
import '../widgets/common.dart';

/// Játékosoldal: szezon-összesítő és az utolsó meccsek a SportAPI adataiból.
class PlayerScreen extends ConsumerWidget {
  final String name;
  final int teamId;
  final String teamName;
  final int? shirt;
  final String position;
  final String nationality;
  final int? age;

  const PlayerScreen({
    super.key,
    required this.name,
    required this.teamId,
    this.teamName = '',
    required this.shirt,
    required this.position,
    required this.nationality,
    required this.age,
  });

  String _pos(String p) {
    final s = p.toLowerCase();
    if (s.contains('goal')) return 'Kapus';
    if (s.contains('def')) return 'Védő';
    if (s.contains('mid')) return 'Középpályás';
    if (s.contains('for') || s.contains('att') || s.contains('strik')) {
      return 'Támadó';
    }
    return p;
  }

  String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (name, teamId, shirt ?? 0);
    final stats = ref.watch(playerStatsProvider(key));
    final me = FavPlayer(
      name: name,
      teamId: teamId,
      teamName: teamName,
      shirt: shirt,
      position: position,
    );
    final isFav = ref.watch(favPlayersProvider).containsKey(me.key);
    final scheme = Theme.of(context).colorScheme;

    final info = [
      if (position.isNotEmpty) _pos(position),
      if (shirt != null) '#$shirt',
      if (nationality.isNotEmpty) nationality,
      if (age != null) '$age év',
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isFav ? 'Eltávolítás a kedvencekből' : 'Kedvenc játékos',
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            onPressed: () => ref.read(favPlayersProvider.notifier).toggle(me),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(playerStatsProvider(key)),
        ),
        data: (s) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playerStatsProvider(key));
              await ref.read(playerStatsProvider(key).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        if (info.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(info,
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (s == null || (s.totals.isEmpty && s.matches.isEmpty))
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'Ehhez a játékoshoz nincs elérhető statisztika.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  const SizedBox(height: 16),
                  const Text('Összesítő',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in const [
                        ('appearances', 'Meccs'),
                        ('goals', 'Gól'),
                        ('assists', 'Gólpassz'),
                        ('mins_played', 'Perc'),
                        ('shots_total', 'Lövés'),
                        ('total_passes', 'Passz'),
                        ('tackles', 'Szerelés'),
                        ('saves', 'Védés'),
                      ])
                        if (s.totals.containsKey(e.$1))
                          _Tile(label: e.$2, value: _n(s.total(e.$1))),
                    ],
                  ),
                  if (s.matches.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Utolsó meccsek',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (final m in ([...s.matches]
                          ..sort((a, b) => b.date.compareTo(a.date)))
                        .take(12))
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            '${m.home} ${m.homeScore ?? '-'} - ${m.awayScore ?? '-'} ${m.away}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              m.date,
                              if (m.mins > 0) "${m.mins}'",
                              if (m.goals > 0) '⚽ ${m.goals}',
                              if (m.assists > 0) '🅰 ${m.assists}',
                              if (m.starter) 'kezdő',
                            ].join(' • '),
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
