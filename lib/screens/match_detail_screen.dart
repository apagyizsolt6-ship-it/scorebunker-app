import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../providers.dart';
import '../services/sport_api.dart';

class MatchDetailScreen extends ConsumerWidget {
  final Fixture fixture;

  const MatchDetailScreen({super.key, required this.fixture});

  Widget _async<T>(AsyncValue<T> v, Widget Function(T) builder) {
    return v.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Text(errorText(e), style: const TextStyle(color: Colors.red)),
      data: builder,
    );
  }

  String _leagueTitle(Fixture f) {
    final top = topLeagueOf(f);
    final name = top != null ? top.nameHu : leagueHu(f.leagueName);
    if (top != null || f.leagueZone.isEmpty) return name;
    return '${countryHu(f.leagueZone)} • $name';
  }

  String _statusText(Fixture f) {
    switch (f.status) {
      case 'Scheduled':
        if (f.kickoff == null) return 'Kezdés: ${f.date}';
        return DateFormat('yyyy.MM.dd HH:mm').format(f.kickoff!);
      case 'LIVE':
        return f.minute == 'HT' ? 'Félidő' : "Élő ${f.minute ?? ''}".trim();
      case 'FT':
        return 'Vége';
      case 'AET':
        return 'Vége (hosszabbítás után)';
      case 'PENS':
        return 'Vége (tizenegyesekkel)';
      case 'Postponed':
        return 'Elhalasztva';
      case 'Cancelled':
        return 'Törölve';
      case 'Suspended':
        return 'Felfüggesztve';
      default:
        return f.status;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = fixture;
    final forms = ref.watch(leagueFormProvider(f.leagueId));
    final h2h = ref.watch(h2hProvider((f.homeId, f.awayId)));

    return Scaffold(
      appBar: AppBar(
        title: Text('${f.homeTeam} vs ${f.awayTeam}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Fejléc
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _leagueTitle(f),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusText(f),
                    style: TextStyle(
                      fontSize: 13,
                      color: f.isLive ? Colors.red : null,
                      fontWeight: f.isLive ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(f.homeTeam,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Text(
                        f.hasScore ? '${f.homeScore} - ${f.awayScore}' : 'VS',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      Expanded(
                        child: Text(f.awayTeam,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  if (f.penaltyHome != null && f.penaltyAway != null) ...[
                    const SizedBox(height: 6),
                    Text('Tizenegyesek: ${f.penaltyHome} - ${f.penaltyAway}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Események
          if (!f.isScheduled) ...[
            const Text('Események',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _async(ref.watch(eventsProvider(f.id)), (events) {
              if (events.isEmpty) return const Text('Nincs esemény.');
              return Column(
                children: events.map((e) {
                  final home = e.side == 'home';
                  final text = Text('${e.icon} ${e.minute} ${e.player}',
                      style: const TextStyle(fontSize: 13));
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: home ? text : const SizedBox())),
                        Expanded(
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: home ? const SizedBox() : text)),
                      ],
                    ),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 24),
          ],

          // Forma
          const Text('Forma (utolsó meccsek)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _async(forms, (map) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _FormRow(f.homeTeam, map[f.homeId] ?? const [])),
                const SizedBox(width: 12),
                Expanded(
                    child: _FormRow(f.awayTeam, map[f.awayId] ?? const [])),
              ],
            );
          }),

          const SizedBox(height: 24),

          // H2H
          const Text('Egymás ellen (utolsó 6)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _async(h2h, (list) {
            final done = list.where((m) => m.isFinished && m.hasScore).toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final last = done.take(6).toList();
            if (last.isEmpty) {
              return const Text('Nincs korábbi egymás elleni meccs.');
            }
            int hw = 0, d = 0, aw = 0;
            for (final m in last) {
              if (m.homeScore == m.awayScore) {
                d++;
              } else {
                final winnerId =
                    m.homeScore! > m.awayScore! ? m.homeId : m.awayId;
                if (winnerId == f.homeId) {
                  hw++;
                } else {
                  aw++;
                }
              }
            }
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _H2HBox('$hw', 'Hazai győzelem'),
                    _H2HBox('$d', 'Döntetlen'),
                    _H2HBox('$aw', 'Vendég győzelem'),
                  ],
                ),
                const SizedBox(height: 12),
                ...last.map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${m.date}  ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 24),

          // Szöglet megjegyzés
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Szöglet-statisztikát a SportAPI nem szolgáltat, ezért itt nem jelenik meg.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String team;
  final List<String> form;
  const _FormRow(this.team, this.form);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(team,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        if (form.isEmpty)
          const Text('–')
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: form.map((r) {
              final color = r == 'W'
                  ? Colors.green
                  : (r == 'D' ? Colors.grey : Colors.red);
              return Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text(r,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _H2HBox extends StatelessWidget {
  final String value;
  final String label;
  const _H2HBox(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
