import '../services/estimator.dart';
import 'backtest.dart';
import 'fixture.dart';

/// Megbízhatósági (kalibrációs) tábla: a becsült esélyből mekkora a valós
/// gyakoriság. Három csoport: 0 = kimenetel (1X2), 1 = gólok, 2 = BTTS.
class Calibration {
  static const int groups = 3;
  static const int bins = 10;

  /// Ennyi minta kell egy csoportban, mielőtt a korrekció életbe lép.
  static const int minSamples = 600;

  /// Mennyire húzza a korrekció az eredeti becslés felé (képzelt minták).
  static const double _prior = 40;

  final List<List<int>> n;
  final List<List<int>> hits;

  const Calibration(this.n, this.hits);

  factory Calibration.empty() => Calibration(
        [for (var g = 0; g < groups; g++) List<int>.filled(bins, 0)],
        [for (var g = 0; g < groups; g++) List<int>.filled(bins, 0)],
      );

  int total(int g) => n[g].fold(0, (a, b) => a + b);
  bool active(int g) => total(g) >= minSamples;
  bool get isActive => active(0) || active(1) || active(2);

  /// A kiértékelt meccsek száma (az 1X2 csoport meccsenként 3 mintát ad).
  int get matches => total(0) ~/ 3;

  int _bin(double p) {
    final b = (p * bins).floor();
    if (b < 0) return 0;
    if (b >= bins) return bins - 1;
    return b;
  }

  /// A korrigált esély; ha kevés az adat, az eredeti.
  double adjust(int g, double p) {
    if (!active(g)) return p;
    final b = _bin(p);
    final cnt = n[g][b];
    if (cnt == 0) return p;
    final freq = hits[g][b] / cnt;
    final cal = (cnt * freq + _prior * p) / (cnt + _prior);
    if (cal < 0.01) return 0.01;
    if (cal > 0.99) return 0.99;
    return cal;
  }

  bool sameAs(Calibration o) {
    for (var g = 0; g < groups; g++) {
      for (var b = 0; b < bins; b++) {
        if (n[g][b] != o.n[g][b] || hits[g][b] != o.hits[g][b]) return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {'n': n, 'h': hits};

  static Calibration? fromJson(dynamic j) {
    if (j is! Map) return null;
    List<List<int>>? read(dynamic l) {
      if (l is! List || l.length != groups) return null;
      final out = <List<int>>[];
      for (final row in l) {
        if (row is! List || row.length != bins) return null;
        out.add([for (final x in row) x is num ? x.toInt() : 0]);
      }
      return out;
    }

    final n = read(j['n']);
    final h = read(j['h']);
    if (n == null || h == null) return null;
    return Calibration(n, h);
  }
}

/// A naplóból és a lejátszott meccsekből építi a kalibrációs táblát.
Calibration buildCalibration(BacktestLog log, Map<int, Fixture> fx) {
  final c = Calibration.empty();
  void add(int g, double p, bool hit) {
    var b = (p * Calibration.bins).floor();
    if (b < 0) b = 0;
    if (b >= Calibration.bins) b = Calibration.bins - 1;
    c.n[g][b]++;
    if (hit) c.hits[g][b]++;
  }

  for (final e in log.estimates) {
    final f = fx[e.fixtureId];
    if (f == null || !f.isFinished || !f.hasScore) continue;
    final h = f.homeScore!;
    final a = f.awayScore!;
    add(0, e.home, h > a);
    add(0, e.draw, h == a);
    add(0, e.away, h < a);
    add(1, e.over25, h + a >= 3);
    add(1, 1 - e.over25, h + a <= 2);
    add(2, e.btts, h > 0 && a > 0);
    add(2, 1 - e.btts, h == 0 || a == 0);
  }
  return c;
}

/// A becslés korrigált másolata (ha a kalibráció még nem aktív, ugyanaz).
MatchEstimate calibrateEstimate(MatchEstimate e, Calibration c) {
  if (!c.isActive) return e;
  var h = c.adjust(0, e.home);
  var d = c.adjust(0, e.draw);
  var a = c.adjust(0, e.away);
  final s = h + d + a;
  if (s > 0) {
    h /= s;
    d /= s;
    a /= s;
  }
  final over = (c.adjust(1, e.over25) + (1 - c.adjust(1, 1 - e.over25))) / 2;
  final btts = (c.adjust(2, e.bttsYes) + (1 - c.adjust(2, 1 - e.bttsYes))) / 2;
  return MatchEstimate(
    lambdaHome: e.lambdaHome,
    lambdaAway: e.lambdaAway,
    home: h,
    draw: d,
    away: a,
    over25: over,
    bttsYes: btts,
    usedH2h: e.usedH2h,
  );
}
