import 'dart:math' as math;

import '../models/standing.dart';
import 'estimator.dart';

class ProjectionRow {
  final TeamRow team;
  final double expectedPoints;
  final double pTitle;
  final double pTop4;
  final double pBottom;

  const ProjectionRow({
    required this.team,
    required this.expectedPoints,
    required this.pTitle,
    required this.pTop4,
    required this.pBottom,
  });
}

class Projection {
  final List<ProjectionRow> rows;
  final int sims;
  final int bottomZone;

  /// Átlagosan hány meccs van még hátra csapatonként.
  final double remaining;

  const Projection({
    required this.rows,
    required this.sims,
    required this.bottomZone,
    required this.remaining,
  });
}

int _poissonDraw(math.Random rng, double lambda) {
  final limit = math.exp(-lambda);
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= rng.nextDouble();
  } while (p > limit);
  return k - 1;
}

/// Monte Carlo szezon-szimuláció a tabellából.
///
/// Feltételezések (ezért csak durva becslés): kétkörös bajnokság
/// (2 × (csapatok száma − 1) meccs csapatonként), a hátralévő meccsek
/// ellenfelei és a pályaválasztás véletlenszerű, a csapaterő a
/// szezon eddigi gólarányaiból jön. Null, ha nem számolható.
Future<Projection?> simulateSeason(LeagueTable t, {int sims = 2000}) async {
  if (t.byGroup.length > 1) return null;
  final rows = t.rows;
  final n = rows.length;
  if (n < 8 || n > 30) return null;

  final rounds = 2 * (n - 1);
  final remaining = [for (final r in rows) math.max(0, rounds - r.played)];
  final totalRemaining = remaining.fold<int>(0, (a, b) => a + b);
  if (totalRemaining < 2) return null;

  var goals = 0;
  var played = 0;
  for (final r in rows) {
    goals += r.goalsFor;
    played += r.played;
  }
  if (played < 20) return null;
  final avg = goals / played;
  if (avg <= 0) return null;

  final fh = leagueHomeFactor(t);
  final fa = 1 / fh;
  const shrink = 3.0;
  double rate(int g, int p) => ((g + shrink * avg) / (p + shrink)) / avg;
  final att = [for (final r in rows) rate(r.goalsFor, r.played)];
  final def = [for (final r in rows) rate(r.goalsAgainst, r.played)];

  double lam(double a, double d, double f) =>
      (avg * f * a * d).clamp(0.2, 4.0).toDouble();

  // lh[i][j]: az i csapat hazai gól-várható értéke a j ellen (j vendég).
  final lh = [
    for (var i = 0; i < n; i++)
      [for (var j = 0; j < n; j++) lam(att[i], def[j], fh)],
  ];
  final la = [
    for (var i = 0; i < n; i++)
      [for (var j = 0; j < n; j++) lam(att[j], def[i], fa)],
  ];

  final basePts = [for (final r in rows) r.points];
  final baseGd = [for (final r in rows) r.goalDiff];
  final bottom = n >= 18 ? 3 : 2;

  final rng = math.Random(20240611);
  final sumPts = List<double>.filled(n, 0);
  final title = List<int>.filled(n, 0);
  final top4 = List<int>.filled(n, 0);
  final drop = List<int>.filled(n, 0);

  for (var s = 0; s < sims; s++) {
    final pts = List<int>.from(basePts);
    final gd = List<int>.from(baseGd);
    final rem = List<int>.from(remaining);
    final active = <int>[
      for (var i = 0; i < n; i++)
        if (rem[i] > 0) i,
    ];

    while (active.length >= 2) {
      final ai = rng.nextInt(active.length);
      var aj = rng.nextInt(active.length - 1);
      if (aj >= ai) aj++;
      var home = active[ai];
      var away = active[aj];
      if (rng.nextBool()) {
        final tmp = home;
        home = away;
        away = tmp;
      }
      final gh = _poissonDraw(rng, lh[home][away]);
      final ga = _poissonDraw(rng, la[home][away]);
      gd[home] += gh - ga;
      gd[away] += ga - gh;
      if (gh > ga) {
        pts[home] += 3;
      } else if (gh == ga) {
        pts[home] += 1;
        pts[away] += 1;
      } else {
        pts[away] += 3;
      }
      rem[home]--;
      rem[away]--;
      active.removeWhere((x) => rem[x] <= 0);
    }

    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final c = pts[b].compareTo(pts[a]);
        if (c != 0) return c;
        return gd[b].compareTo(gd[a]);
      });
    title[order.first]++;
    for (var k = 0; k < math.min(4, n); k++) {
      top4[order[k]]++;
    }
    for (var k = n - bottom; k < n; k++) {
      drop[order[k]]++;
    }
    for (var i = 0; i < n; i++) {
      sumPts[i] += pts[i];
    }

    if (s % 200 == 199) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  final out = [
    for (var i = 0; i < n; i++)
      ProjectionRow(
        team: rows[i],
        expectedPoints: sumPts[i] / sims,
        pTitle: title[i] / sims,
        pTop4: top4[i] / sims,
        pBottom: drop[i] / sims,
      ),
  ]..sort((a, b) => b.expectedPoints.compareTo(a.expectedPoints));

  return Projection(
    rows: out,
    sims: sims,
    bottomZone: bottom,
    remaining: totalRemaining / n,
  );
}
