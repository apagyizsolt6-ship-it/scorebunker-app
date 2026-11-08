import 'fixture.dart';
import 'slip.dart';
import 'trend.dart';

/// A naplózott (még le nem játszott) trend egy meccsre.
class TrendLogEntry {
  final int fixtureId;
  final String date;
  final int kind; // TrendKind.index
  final String pick; // Pick.name
  final int strength;

  const TrendLogEntry({
    required this.fixtureId,
    required this.date,
    required this.kind,
    required this.pick,
    required this.strength,
  });

  Map<String, dynamic> toJson() => {
        'f': fixtureId,
        'd': date,
        'k': kind,
        'p': pick,
        's': strength,
      };

  factory TrendLogEntry.fromJson(Map<String, dynamic> j) => TrendLogEntry(
        fixtureId: (j['f'] as num?)?.toInt() ?? 0,
        date: (j['d'] ?? '').toString(),
        kind: (j['k'] as num?)?.toInt() ?? 0,
        pick: (j['p'] ?? '').toString(),
        strength: (j['s'] as num?)?.toInt() ?? 0,
      );
}

/// A naplózott esély-becslés egy meccsre.
class EstimateLogEntry {
  final int fixtureId;
  final String date;
  final double home;
  final double draw;
  final double away;
  final double over25;
  final double btts;

  const EstimateLogEntry({
    required this.fixtureId,
    required this.date,
    required this.home,
    required this.draw,
    required this.away,
    required this.over25,
    required this.btts,
  });

  Map<String, dynamic> toJson() => {
        'f': fixtureId,
        'd': date,
        'h': home,
        'x': draw,
        'a': away,
        'o': over25,
        'b': btts,
      };

  factory EstimateLogEntry.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => v is num ? v.toDouble() : 0;
    return EstimateLogEntry(
      fixtureId: (j['f'] as num?)?.toInt() ?? 0,
      date: (j['d'] ?? '').toString(),
      home: n(j['h']),
      draw: n(j['x']),
      away: n(j['a']),
      over25: n(j['o']),
      btts: n(j['b']),
    );
  }
}

class BacktestLog {
  final List<TrendLogEntry> trends;
  final List<EstimateLogEntry> estimates;
  const BacktestLog({this.trends = const [], this.estimates = const []});
}

/// Találatszámláló: hány eset, hány találat, a becsült esélyek összege.
class Tally {
  int n = 0;
  int hits = 0;
  double sumP = 0;

  void add(bool hit, [double p = 0]) {
    n++;
    if (hit) hits++;
    sumP += p;
  }

  double get rate => n == 0 ? 0 : hits / n;
  double get avgP => n == 0 ? 0 : sumP / n;
}

class BacktestReport {
  final Map<TrendKind, Tally> trends;
  final Tally top1x2;
  final Tally over;
  final Tally under;
  final Tally bttsYes;
  final Tally bttsNo;
  final int pending;
  final int loggedMatches;

  const BacktestReport({
    required this.trends,
    required this.top1x2,
    required this.over,
    required this.under,
    required this.bttsYes,
    required this.bttsNo,
    required this.pending,
    required this.loggedMatches,
  });
}

BacktestReport buildReport(BacktestLog log, Map<int, Fixture> fx) {
  final trends = <TrendKind, Tally>{};
  var pending = 0;

  for (final e in log.trends) {
    if (e.kind < 0 || e.kind >= TrendKind.values.length) continue;
    final kind = TrendKind.values[e.kind];
    final pick = Pick.values.firstWhere(
      (p) => p.name == e.pick,
      orElse: () => Pick.home,
    );
    final r = evaluatePick(pick, fx[e.fixtureId]);
    if (r == LegResult.pending) {
      pending++;
    } else if (r != LegResult.voided) {
      trends.putIfAbsent(kind, Tally.new).add(r == LegResult.won);
    }
  }

  final top = Tally();
  final over = Tally();
  final under = Tally();
  final bYes = Tally();
  final bNo = Tally();
  for (final e in log.estimates) {
    final f = fx[e.fixtureId];
    if (f == null || !f.isFinished || !f.hasScore) {
      pending++;
      continue;
    }
    final h = f.homeScore!;
    final a = f.awayScore!;

    // 1X2: a legvalószínűbb kimenetel
    var best = e.home;
    var bestIsHome = true;
    var bestIsDraw = false;
    if (e.draw > best) {
      best = e.draw;
      bestIsHome = false;
      bestIsDraw = true;
    }
    if (e.away > best) {
      best = e.away;
      bestIsHome = false;
      bestIsDraw = false;
    }
    final actualHome = h > a;
    final actualDraw = h == a;
    final hit = bestIsHome
        ? actualHome
        : bestIsDraw
            ? actualDraw
            : (!actualHome && !actualDraw);
    top.add(hit, best);

    if (e.over25 >= 0.60) over.add(h + a >= 3, e.over25);
    if (e.over25 <= 0.40) under.add(h + a <= 2, 1 - e.over25);
    if (e.btts >= 0.60) bYes.add(h > 0 && a > 0, e.btts);
    if (e.btts <= 0.40) bNo.add(h == 0 || a == 0, 1 - e.btts);
  }

  final matches = <int>{
    for (final e in log.trends) e.fixtureId,
    for (final e in log.estimates) e.fixtureId,
  };

  return BacktestReport(
    trends: trends,
    top1x2: top,
    over: over,
    under: under,
    bttsYes: bYes,
    bttsNo: bNo,
    pending: pending,
    loggedMatches: matches.length,
  );
}
