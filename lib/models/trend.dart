import '../services/estimator.dart';
import 'fixture.dart';
import 'slip.dart';

enum TrendKind { over25, under25, btts, win, unbeaten, scoring, cleanSheet }

enum TrendGroup { goals, btts, form }

class Trend {
  final Fixture fixture;
  final TrendKind kind;
  final String title;
  final String detail;
  final int hits;
  final int total;

  /// Ha van hozzá megfelelő tipp, egy koppintással szelvényre tehető.
  final Pick? pick;

  const Trend({
    required this.fixture,
    required this.kind,
    required this.title,
    required this.detail,
    required this.hits,
    required this.total,
    this.pick,
  });

  double get ratio => total == 0 ? 0 : hits / total;

  /// 1–10: a találati arány tizedekben.
  int get strength {
    final s = (ratio * 10).round();
    if (s < 1) return 1;
    if (s > 10) return 10;
    return s;
  }

  TrendGroup get group => switch (kind) {
        TrendKind.over25 || TrendKind.under25 => TrendGroup.goals,
        TrendKind.btts => TrendGroup.btts,
        _ => TrendGroup.form,
      };
}

/// Egy meccs és a rá számolt esély-becslés (alapmodell).
class FixtureEstimate {
  final Fixture fixture;
  final MatchEstimate est;
  const FixtureEstimate(this.fixture, this.est);
}

class TrendsResult {
  final List<Trend> trends;
  final List<FixtureEstimate> estimates;
  final int matches;
  final int leagues;
  final int failed;

  const TrendsResult({
    required this.trends,
    this.estimates = const [],
    required this.matches,
    required this.leagues,
    required this.failed,
  });
}
