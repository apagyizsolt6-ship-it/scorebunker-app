import 'dart:math' as math;

import '../models/fixture.dart';
import '../models/slip.dart';
import '../models/standing.dart';
import 'elo.dart';

/// Poisson-eloszláson alapuló esély-becslés a tabella adataiból.
/// Nem garancia és nem tipp: csak a bajnokság eddigi eredményeiből számol.
///
/// Összetevők:
///  - szezon-átlag támadó / védekező erő (a bajnoki átlag felé húzva),
///  - a csapat hazai / idegenbeli utolsó meccsei (35% súllyal),
///  - Elo-szerű csapaterő több hét eredményeiből (kis súllyal, ha van),
///  - a bajnokság saját hazai előnye,
///  - Dixon–Coles korrekció az alacsony gólszámú eredményekre,
///  - opcionálisan az egymás elleni meccsek (legfeljebb 20% súllyal).
class MatchEstimate {
  final double lambdaHome;
  final double lambdaAway;
  final double home;
  final double draw;
  final double away;
  final double over25;
  final double bttsYes;
  final bool usedH2h;

  const MatchEstimate({
    required this.lambdaHome,
    required this.lambdaAway,
    required this.home,
    required this.draw,
    required this.away,
    required this.over25,
    required this.bttsYes,
    this.usedH2h = false,
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

/// Mennyi "képzelt" meccsel húzzuk a csapat adatát a bajnoki átlag felé.
const double _shrink = 3;

/// Dixon–Coles paraméter (negatív: több 0-0 és 1-1, mint a sima Poisson).
const double _rho = -0.06;

/// Az utolsó meccsek hazai / idegenbeli bontásának súlya (35%).
const double _venueWeight = 0.35;

double _poisson(int k, double lambda) {
  var p = math.exp(-lambda);
  for (var i = 1; i <= k; i++) {
    p *= lambda / i;
  }
  return p;
}

/// A bajnokság hazai előnye a tabella `form` meccseiből (gól-arány gyöke),
/// 1,10-es előzetes érték felé húzva.
double leagueHomeFactor(LeagueTable t) {
  var homeGoals = 0;
  var awayGoals = 0;
  var n = 0;
  final seen = <String>{};
  for (final r in t.rows) {
    for (final m in r.form) {
      if (!m.hasScore) continue;
      if (!seen.add('${m.date}|${m.homeTeam}|${m.awayTeam}')) continue;
      homeGoals += m.homeScore!;
      awayGoals += m.awayScore!;
      n++;
    }
  }
  const prior = 1.10;
  const k = 30.0;
  if (n < 10 || homeGoals == 0 || awayGoals == 0) return prior;
  final raw = math.sqrt(homeGoals / awayGoals);
  final f = (n * raw + k * prior) / (n + k);
  return f.clamp(1.0, 1.35).toDouble();
}

/// Az adott helyszínen (hazai / idegen) lejátszott utolsó meccsek alapján
/// számolt arány a várt (baseline) gólszámhoz képest, szintén átlag felé húzva.
double _venueRatio(List<FormMatch> ms, bool scored, double baseline) {
  var goals = 0;
  for (final m in ms) {
    goals += (scored ? m.goalsFor : m.goalsAgainst) ?? 0;
  }
  return (goals + _shrink * baseline) / ((ms.length + _shrink) * baseline);
}

MatchEstimate? estimateMatch(
  LeagueTable table,
  int homeId,
  int awayId, {
  List<Fixture>? h2h,
  EloState? elo,
}) {
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

  final fh = leagueHomeFactor(table);
  final fa = 1 / fh;

  double rate(int goals, int played) =>
      ((goals + _shrink * avg) / (played + _shrink)) / avg;

  final homeAtHome =
      h.form.where((m) => m.hasScore && m.isHome).toList();
  final awayAtAway =
      a.form.where((m) => m.hasScore && !m.isHome).toList();

  const w = _venueWeight;
  final attH = (1 - w) * rate(h.goalsFor, h.played) +
      w * _venueRatio(homeAtHome, true, avg * fh);
  final defH = (1 - w) * rate(h.goalsAgainst, h.played) +
      w * _venueRatio(homeAtHome, false, avg * fa);
  final attA = (1 - w) * rate(a.goalsFor, a.played) +
      w * _venueRatio(awayAtAway, true, avg * fa);
  final defA = (1 - w) * rate(a.goalsAgainst, a.played) +
      w * _venueRatio(awayAtAway, false, avg * fh);

  var lh = avg * fh * attH * defA;
  var la = avg * fa * attA * defH;

  // Elo-szerű csapaterő: kis korrekció a hosszabb távú erőviszonyok szerint
  // (100 Elo-pont kb. 4% eltolás a várható gólokban mindkét irányban).
  if (elo != null) {
    final d = elo.diff(homeId, awayId);
    if (d != null) {
      var t = 0.0004 * d;
      if (t > 0.25) t = 0.25;
      if (t < -0.25) t = -0.25;
      lh *= math.exp(t);
      la *= math.exp(-t);
    }
  }

  // Egymás elleni meccsek (ha van elég).
  var usedH2h = false;
  if (h2h != null) {
    final done = h2h.where((m) => m.isFinished && m.hasScore).toList()
      ..sort((x, y) => y.date.compareTo(x.date));
    final last = done.take(6).toList();
    if (last.length >= 3) {
      var hg = 0;
      var ag = 0;
      for (final m in last) {
        if (m.homeId == homeId) {
          hg += m.homeScore!;
          ag += m.awayScore!;
        } else {
          hg += m.awayScore!;
          ag += m.homeScore!;
        }
      }
      final wh = 0.2 * last.length / 6;
      lh = lh * (1 - wh) + (hg / last.length) * wh;
      la = la * (1 - wh) + (ag / last.length) * wh;
      usedH2h = true;
    }
  }

  lh = lh.clamp(0.2, 4.0).toDouble();
  la = la.clamp(0.2, 4.0).toDouble();

  double tau(int i, int j) {
    if (i == 0 && j == 0) return 1 - lh * la * _rho;
    if (i == 0 && j == 1) return 1 + lh * _rho;
    if (i == 1 && j == 0) return 1 + la * _rho;
    if (i == 1 && j == 1) return 1 - _rho;
    return 1;
  }

  const maxGoals = 10;
  var pHome = 0.0;
  var pDraw = 0.0;
  var pAway = 0.0;
  var pOver = 0.0;
  var pBtts = 0.0;
  for (var i = 0; i <= maxGoals; i++) {
    final pi0 = _poisson(i, lh);
    for (var j = 0; j <= maxGoals; j++) {
      final p = pi0 * _poisson(j, la) * tau(i, j);
      if (i > j) {
        pHome += p;
      } else if (i == j) {
        pDraw += p;
      } else {
        pAway += p;
      }
      if (i + j >= 3) pOver += p;
      if (i > 0 && j > 0) pBtts += p;
    }
  }
  final sum = pHome + pDraw + pAway;
  if (sum <= 0) return null;

  return MatchEstimate(
    lambdaHome: lh,
    lambdaAway: la,
    home: pHome / sum,
    draw: pDraw / sum,
    away: pAway / sum,
    over25: (pOver / sum).clamp(0.0, 1.0).toDouble(),
    bttsYes: (pBtts / sum).clamp(0.0, 1.0).toDouble(),
    usedH2h: usedH2h,
  );
}
