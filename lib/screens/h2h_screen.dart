import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Egymás elleni előzmények: összesítő, hazai/vendég bontás, gólok és a
/// meccsek teljes listája a hazai csapat szemszögéből.
class H2HScreen extends ConsumerWidget {
  final Fixture fixture;
  const H2HScreen({super.key, required this.fixture});

  String _avg(num total, int n) =>
      n == 0 ? '–' : (total / n).toStringAsFixed(2).replaceAll('.', ',');

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
            Text(v,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  /// (győzelem, döntetlen, vereség, lőtt, kapott) a `team` szemszögéből.
  (int, int, int, int, int) _record(List<Fixture> ms, int team) {
    var w = 0, d = 0, l = 0, gf = 0, ga = 0;
    for (final m in ms) {
      final home = m.homeId == team;
      final mine = home ? m.homeScore! : m.awayScore!;
      final theirs = home ? m.awayScore! : m.homeScore!;
      gf += mine;
      ga += theirs;
      if (mine > theirs) {
        w++;
      } else if (mine == theirs) {
        d++;
      } else {
        l++;
      }
    }
    return (w, d, l, gf, ga);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = fixture;
    final h2h = ref.watch(h2hProvider((f.homeId, f.awayId)));

    return Scaffold(
      appBar: AppBar(title: const Text('Egymás ellen'), centerTitle: true),
      body: h2h.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(h2hProvider((f.homeId, f.awayId))),
        ),
        data: (list) {
          final done = list.where((m) => m.isFinished && m.hasScore).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          if (done.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nincs korábbi egymás elleni meccs.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final n = done.length;
          final all = _record(done, f.homeId);
          var totalGoals = 0, over = 0, btts = 0, cleanH = 0, cleanA = 0;
          for (final m in done) {
            final t = m.homeScore! + m.awayScore!;
            totalGoals += t;
            if (t >= 3) over++;
            if (m.homeScore! > 0 && m.awayScore! > 0) btts++;
            // tiszta lap: a másik csapat nem szerzett gólt
            final ourGoals = m.homeId == f.homeId ? m.homeScore! : m.awayScore!;
            final theirGoals = m.homeId == f.homeId ? m.awayScore! : m.homeScore!;
            if (theirGoals == 0) cleanH++;
            if (ourGoals == 0) cleanA++;
          }

          // A hazai csapat hazai pályán / a vendég hazai pályán játszott meccsei.
          final atHomeH = done.where((m) => m.homeId == f.homeId).toList();
          final atHomeA = done.where((m) => m.homeId == f.awayId).toList();
          final rH = _record(atHomeH, f.homeId);
          final rA = _record(atHomeA, f.awayId);

          // Sorozat: a hazai csapat veretlen az utolsó N egymás elleni meccsen.
          var unbeaten = 0;
          for (final m in done) {
            final home = m.homeId == f.homeId;
            final mine = home ? m.homeScore! : m.awayScore!;
            final theirs = home ? m.awayScore! : m.homeScore!;
            if (mine >= theirs) {
              unbeaten++;
            } else {
              break;
            }
          }

          Widget chip(Fixture m) {
            final home = m.homeId == f.homeId;
            final mine = home ? m.homeScore! : m.awayScore!;
            final theirs = home ? m.awayScore! : m.homeScore!;
            final (String t, Color c) = mine > theirs
                ? ('Gy', Colors.green)
                : (mine == theirs ? ('D', Colors.grey) : ('V', Colors.red));
            return CircleAvatar(
              radius: 13,
              backgroundColor: c,
              child: Text(t,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${f.homeTeam} – ${f.awayTeam}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              Text('$n közös meccs az adatbázisban',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              _title('Összesítő'),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      _kv('${f.homeLabel} győzelem', '${all.$1}', bold: true),
                      _kv('Döntetlen', '${all.$2}'),
                      _kv('${f.awayLabel} győzelem', '${all.$3}', bold: true),
                      const Divider(height: 14),
                      _kv('Gólok (${f.homeLabel} – ${f.awayLabel})',
                          '${all.$4} – ${all.$5}'),
                      _kv('Gól / meccs', _avg(totalGoals, n)),
                      _kv('3 vagy több gól', '$over / $n (${(over * 100 / n).round()}%)'),
                      _kv('Mindkét csapat szerzett gólt',
                          '$btts / $n (${(btts * 100 / n).round()}%)'),
                      _kv('${f.homeLabel} nem kapott gólt', '$cleanH / $n'),
                      _kv('${f.awayLabel} nem kapott gólt', '$cleanA / $n'),
                    ],
                  ),
                ),
              ),
              _title('Hazai pálya szerint'),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      _kv('${f.homeLabel} hazai pályán (${atHomeH.length} meccs)',
                          atHomeH.isEmpty ? '–' : '${rH.$1}-${rH.$2}-${rH.$3}'),
                      _kv('${f.awayLabel} hazai pályán (${atHomeA.length} meccs)',
                          atHomeA.isEmpty ? '–' : '${rA.$1}-${rA.$2}-${rA.$3}'),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Gy-D-V az adott csapat szemszögéből.',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
              if (unbeaten >= 2) ...[
                const SizedBox(height: 10),
                Text(
                  '${f.homeLabel} az utolsó $unbeaten egymás elleni meccsén veretlen.',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              _title('Minden meccs (${f.homeLabel} szemszögéből)'),
              for (final m in done)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: chip(m),
                    title: Text(
                      '${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${m.date}${m.leagueName.isEmpty ? '' : ' • ${leagueHu(m.leagueName)}'}',
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Az adatbázis nem feltétlenül tartalmaz minden régi meccset.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
