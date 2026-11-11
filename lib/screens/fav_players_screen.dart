import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/prefs_store.dart';
import 'player_screen.dart';

/// Kedvenc játékosok szezon-statisztikával (gól, gólpassz, meccs, perc).
class FavPlayersScreen extends ConsumerWidget {
  const FavPlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favPlayersProvider);
    final list = favs.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kedvenc játékosok'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Statisztikák frissítése',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              for (final p in list) {
                ref.invalidate(
                    playerStatsProvider((p.name, p.teamId, p.shirt ?? 0)));
              }
            },
          ),
        ],
      ),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Még nincs kedvenc játékosod.\n\n'
                  'Egy csapat oldalán a Keret fülön koppints a játékos nevére, '
                  'és jelöld meg a csillaggal.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final p in list) _FavPlayerCard(player: p)],
            ),
    );
  }
}

class _FavPlayerCard extends ConsumerWidget {
  final FavPlayer player;
  const _FavPlayerCard({required this.player});

  Widget _stat(String label, num v) => Expanded(
        child: Column(
          children: [
            Text(
              v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = player;
    final stats = ref.watch(playerStatsProvider((p.name, p.teamId, p.shirt ?? 0)));
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              name: p.name,
              teamId: p.teamId,
              teamName: p.teamName,
              shirt: p.shirt,
              position: p.position,
              nationality: '',
              age: null,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        Text(
                          [
                            if (p.teamName.isNotEmpty) p.teamName,
                            if (p.shirt != null) '#${p.shirt}',
                          ].join(' • '),
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eltávolítás',
                    icon: const Icon(Icons.star, color: Colors.amber),
                    onPressed: () =>
                        ref.read(favPlayersProvider.notifier).remove(p.key),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              stats.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
                error: (e, _) => const Text(
                  'A statisztika most nem érhető el.',
                  style: TextStyle(fontSize: 12),
                ),
                data: (s) {
                  if (s == null || s.totals.isEmpty) {
                    return const Text('Nincs elérhető statisztika.',
                        style: TextStyle(fontSize: 12));
                  }
                  final last = ([...s.matches]
                        ..sort((a, b) => b.date.compareTo(a.date)))
                      .take(1)
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _stat('Meccs', s.total('appearances')),
                          _stat('Gól', s.total('goals')),
                          _stat('Gólpassz', s.total('assists')),
                          _stat('Perc', s.total('mins_played')),
                        ],
                      ),
                      if (last.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 8),
                          child: Text(
                            'Utolsó meccs: ${last.first.home} ${last.first.homeScore ?? '-'} - '
                            '${last.first.awayScore ?? '-'} ${last.first.away}'
                            '${last.first.goals > 0 ? '  ⚽ ${last.first.goals}' : ''}'
                            '${last.first.assists > 0 ? '  🅰 ${last.first.assists}' : ''}',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
