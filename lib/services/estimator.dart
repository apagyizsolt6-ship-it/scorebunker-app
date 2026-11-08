import 'dart:math' as math;

import '../models/slip.dart';
import '../models/standing.dart';

/// Egyszerű, Poisson-eloszláson alapuló esély-becslés a tabella adataiból.
/// Nem garancia és nem tipp: csak a bajnokság eddigi gólátlagaiból számol.
class MatchEstimate {
  final double lambdaHome;
  final double lambdaAway;
  final double home;
  final double draw;
  final double away;
  final double over25;
  final double bttsYes;

  const MatchEstimate({
    required this.lambdaHome,
    required this.lambdaAway,
    required this.home,
    required this.draw,
    required this.away,
    required this.over25,
    required this.bttsYes,
  });

  double get under25 => 1 - over25;
  double get bttsNo => 1 - bttsYes;

  double prob(Pick p) => switch (p) {
        Pick.home => home,
        Pick.draw => draw,
        Pick.away => away,
        Pick.over25 => over25,
        Pick.under25 => under25,
        Pick.bttsYes => bttsYes,
        Pick.bttsNo => bttsNo,
      };
}

/// Fair (jutalék nélküli) odds egy valószínűséghez.
double fairOdds(double p) => p <= 0 ? 0 : 1 / p;

/// Várható érték 1 egységnyi tétre: p * odds - 1.
double expectedValue(double p, double odds) => p * odds - 1;

const double _homeFactor = 1.10;
const double _awayFactor = 0.90;

/// Mennyi "képzelt" meccsel húzzuk a csapat adatát a bajnoki átlag felé.
const double _shrink = 3;

double _poisson(int k, double lambda) {
  var p = math.exp(-lambda);
  for (var i = 1; i <= k; i++) {
    p *= lambda / i;
  }
  return p;
}

MatchEstimate? estimateMatch(LeagueTable table, int homeId, int awayId) {
  final h = table.rowOf(homeId);
  final a = table.rowOf(awayId);
  if (h == null || a == null) return null;
  if (h.played < 3 || a.played < 3) return null;

  var totalGoals = 0;
  var totalPlayed = 0;
  for (final r in table.rows) {
    totalGoals += r.goalsFor;
    totalPlayed += r.played;
  }
  if (totalPlayed < 20) return null;
  final avg = totalGoals / totalPlayed; // gól / csapat / meccs
  if (avg <= 0) return null;

  double rate(int goals, int played) =>
      ((goals + _shrink * avg) / (played + _shrink)) / avg;

  final attackH = rate(h.goalsFor, h.played);
  final defenceH = rate(h.goalsAgainst, h.played);
  final attackA = rate(a.goalsFor, a.played);
  final defenceA = rate(a.goalsAgainst, a.played);

  final lh = avg * attackH * defenceA * _homeFactor;
  final la = avg * attackA * defenceH * _awayFactor;

  const maxGoals = 10;
  var pHome = 0.0, pDraw = 0.0, pAway = 0.0, pOver = 0.0;
  for (var i = 0; i <= maxGoals; i++) {
    final pi = _poisson(i, lh);
    for (var j = 0; j <= maxGoals; j++) {
      final p = pi * _poisson(j, la);
      if (i > j) {
        pHome += p;
      } else if (i == j) {
        pDraw += p;
      } else {
        pAway += p;
      }
      if (i + j >= 3) pOver += p;
    }
  }
  final sum = pHome + pDraw + pAway;
  if (sum <= 0) return null;
  final btts = (1 - math.exp(-lh)) * (1 - math.exp(-la));

  return MatchEstimate(
    lambdaHome: lh,
    lambdaAway: la,
    home: pHome / sum,
    draw: pDraw / sum,
    away: pAway / sum,
    over25: (pOver / sum).clamp(0.0, 1.0).toDouble(),
    bttsYes: btts.clamp(0.0, 1.0).toDouble(),
  );
}
