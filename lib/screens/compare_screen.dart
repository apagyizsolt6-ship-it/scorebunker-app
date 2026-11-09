import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture.dart';
import '../models/standing.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/form_spark.dart';

/// Két csapat egymás mellett: tabella, gólátlagok, forma, egymás elleni
/// meccsek és becsült esélyek.
class CompareScreen extends ConsumerWidget {
  final Fixture fixture;
  const CompareScreen({super.key, required this.fixture});

  /// Forma-pont / meccs: Gy = 3, D = 1.
  double _formPpg(List<FormMatch> l) {
    if (l.isEmpty) return 0;
    var pts = 0;
    for (final m in l) {
      pts += m.result == 'W' ? 3 : (m.result == 'D' ? 1 : 0);
    }
    return pts / l.length;
  }

  /// -1: a bal oldal jobb, 1: a jobb oldal jobb, 0: egyenlő / nincs értelme.
  int _better(num a, num b, {bool lowerIsBetter = false}) {
    if (a == b) return 0;
    final leftBetter = lowerIsBetter ? a < b : a > b;
    return leftBetter ? -1 : 1;
  }

  Widget _row(
    BuildContext context,
    String label,
    String left,
    String right, {
    int better = 0,
  }) {
    final scheme = Theme.of(context).colorScheme;
    TextStyle st(bool good) => TextStyle(
          fontSize: 14,
          fontWeight: good ? FontWeight.w800 : FontWeight.w500,
          color: good ? Colors.green : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(left, textAlign: TextAlign.center, style: st(better == -1)),
          ),
          SizedBox(
            width: 124,
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(right, textAlign: TextAlign.center, style: st(better == 1)),
          ),
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = fixture;
    final table = ref.watch(standingsProvider(f.leagueId));
    final h2h = ref.watch(h2hProvider((f.homeId, f.awayId)));
    final est = ref
        .watch(estimateProvider((f.leagueId, f.homeId, f.awayId)))
        .valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Összehasonlítás'), centerTitle: true),
      body: table.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(standingsProvider(f.leagueId)),
        ),
        data: (t) {
          final h = t.rowOf(f.homeId);
          final a = t.rowOf(f.awayId);
          if (h == null || a == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ehhez a meccshez nincs elég tabella-adat az összehasonlításhoz.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final hHome = h.form.where((m) => m.hasScore && m.isHome).toList();
          final aAway = a.form.where((m) => m.hasScore && !m.isHome).toList();
          double gpg(int g, int p) => p == 0 ? 0 : g / p;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TeamLogo(teamId: f.homeId, size: 40, padRight: false),
                        Text(f.homeTeam,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                  const Text('vs',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Column(
                      children: [
                        TeamLogo(teamId: f.awayId, size: 40, padRight: false),
                        Text(f.awayTeam,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
              _title('Tabella'),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      _row(context, 'Helyezés', '${h.position}.', '${a.position}.',
                          better: _better(h.position, a.position,
                              lowerIsBetter: true)),
                      _row(context, 'Pont', '${h.points}', '${a.points}',
                          better: _better(h.points, a.points)),
                      _row(context, 'Meccs', '${h.played}', '${a.played}'),
                      _row(context, 'Gy – D – V', '${h.won}-${h.draw}-${h.lost}',
                          '${a.won}-${a.draw}-${a.lost}'),
                      _row(
                        context,
                        'Lőtt gól / meccs',
                        gpg(h.goalsFor, h.played).toStringAsFixed(2),
                        gpg(a.goalsFor, a.played).toStringAsFixed(2),
                        better: _better(gpg(h.goalsFor, h.played),
                            gpg(a.goalsFor, a.played)),
                      ),
                      _row(
                        context,
                        'Kapott gól / meccs',
                        gpg(h.goalsAgainst, h.played).toStringAsFixed(2),
                        gpg(a.goalsAgainst, a.played).toStringAsFixed(2),
                        better: _better(gpg(h.goalsAgainst, h.played),
                            gpg(a.goalsAgainst, a.played),
                            lowerIsBetter: true),
                      ),
                      _row(
                        context,
                        'Gólkülönbség',
                        '${h.goalDiff >= 0 ? '+' : ''}${h.goalDiff}',
                        '${a.goalDiff >= 0 ? '+' : ''}${a.goalDiff}',
                        better: _better(h.goalDiff, a.goalDiff),
                      ),
                    ],
                  ),
                ),
              ),
              _title('Forma (utolsó meccsek)'),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      _row(
                        context,
                        'Pont / meccs',
                        _formPpg(h.form).toStringAsFixed(2),
                        _formPpg(a.form).toStringAsFixed(2),
                        better: _better(_formPpg(h.form), _formPpg(a.form)),
                      ),
                      _row(
                        context,
                        'Hazai / idegen pont',
                        hHome.isEmpty ? '–' : _formPpg(hHome).toStringAsFixed(2),
                        aAway.isEmpty ? '–' : _formPpg(aAway).toStringAsFixed(2),
                        better: (hHome.isEmpty || aAway.isEmpty)
                            ? 0
                            : _better(_formPpg(hHome), _formPpg(aAway)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: FormSpark(form: h.form)),
                          const SizedBox(width: 16),
                          Expanded(child: FormSpark(form: a.form)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Oszlopok: gólkülönbség meccsenként (régebbi → újabb)',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _title('Egymás ellen'),
              h2h.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const Text('Az egymás elleni adat nem érhető el.'),
                data: (list) {
                  final done = list.where((m) => m.isFinished && m.hasScore).toList()
                    ..sort((x, y) => y.date.compareTo(x.date));
                  final last = done.take(6).toList();
                  if (last.isEmpty) {
                    return const Text('Nincs korábbi egymás elleni meccs.');
                  }
                  var hw = 0, dr = 0, aw = 0, hg = 0, ag = 0;
                  for (final m in last) {
                    final homeIsOurHome = m.homeId == f.homeId;
                    final gOur = homeIsOurHome ? m.homeScore! : m.awayScore!;
                    final gTheir = homeIsOurHome ? m.awayScore! : m.homeScore!;
                    hg += gOur;
                    ag += gTheir;
                    if (gOur > gTheir) {
                      hw++;
                    } else if (gOur == gTheir) {
                      dr++;
                    } else {
                      aw++;
                    }
                  }
                  return Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        children: [
                          _row(context, 'Győzelem (utolsó ${last.length})',
                              '$hw', '$aw',
                              better: _better(hw, aw)),
                          _row(context, 'Döntetlen', '$dr', '$dr'),
                          _row(
                            context,
                            'Gólok összesen',
                            '$hg',
                            '$ag',
                            better: _better(hg, ag),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (est != null) ...[
                _title('Becsült esélyek'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        _row(context, 'Győzelem', '${(est.home * 100).round()}%',
                            '${(est.away * 100).round()}%',
                            better: _better(est.home, est.away)),
                        _row(context, 'Döntetlen',
                            '${(est.draw * 100).round()}%',
                            '${(est.draw * 100).round()}%'),
                        _row(
                          context,
                          'Várható gólok',
                          est.lambdaHome.toStringAsFixed(2),
                          est.lambdaAway.toStringAsFixed(2),
                          better: _better(est.lambdaHome, est.lambdaAway),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  'A zöld szám a jobb érték. Becslés, nem garancia és nem ajánlás.',
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
