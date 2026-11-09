import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/league_catalog.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/reminder_button.dart';
import 'match_detail_screen.dart';

/// A kedvenc csapatok meccsei a következő 7 napra.
class FavCalendarScreen extends ConsumerWidget {
  const FavCalendarScreen({super.key});

  static const _weekdays = [
    'hétfő',
    'kedd',
    'szerda',
    'csütörtök',
    'péntek',
    'szombat',
    'vasárnap',
  ];

  String _dayLabel(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    final date = DateFormat('MM.dd.').format(d);
    if (diff == 0) return 'Ma • $date';
    if (diff == 1) return 'Holnap • $date';
    return '${_weekdays[d.weekday - 1]} • $date';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final cal = ref.watch(favCalendarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kedvencek naptára'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Frissítés',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(favCalendarProvider),
          ),
        ],
      ),
      body: favs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Még nincs kedvenc csapatod.\n'
                  'A Meccsek fülön nyomd hosszan egy meccskártyát, és jelöld meg a csapatot.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : cal.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(favCalendarProvider),
              ),
              data: (days) {
                if (days.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'A következő 7 napban nincs meccse a kedvenc csapataidnak.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final keys = days.keys.toList()..sort();
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(favCalendarProvider);
                    await ref.read(favCalendarProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (final k in keys) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 6),
                          child: Text(
                            _dayLabel(k),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                        for (final f in days[k]!)
                          Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MatchDetailScreen(fixture: f),
                                ),
                              ),
                              leading: SizedBox(
                                width: 48,
                                child: Text(
                                  f.timeLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              title: Text('${f.homeTeam} – ${f.awayTeam}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(leagueHu(f.leagueName)),
                              trailing: f.hasScore
                                  ? Text('${f.homeScore} - ${f.awayScore}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))
                                  : ReminderButton(fixture: f),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
