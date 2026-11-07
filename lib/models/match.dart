class Match {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String time;
  final double homeCornersAvg;
  final double awayCornersAvg;
  final double homeCornersFor;
  final double homeCornersAgainst;
  final double awayCornersFor;
  final double awayCornersAgainst;
  final String mainTrend;
  final int trendStrength;
  final List<String> formHome;
  final List<String> formAway;
  final int h2hHomeWins;
  final int h2hDraws;
  final int h2hAwayWins;

  Match({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.time,
    required this.homeCornersAvg,
    required this.awayCornersAvg,
    required this.homeCornersFor,
    required this.homeCornersAgainst,
    required this.awayCornersFor,
    required this.awayCornersAgainst,
    required this.mainTrend,
    required this.trendStrength,
    required this.formHome,
    required this.formAway,
    required this.h2hHomeWins,
    required this.h2hDraws,
    required this.h2hAwayWins,
  });
}
