String _s(dynamic v) => (v ?? '').toString();
int _i(dynamic v) => v is num ? v.toInt() : 0;

class PlayerMatch {
  final String date;
  final String home;
  final String away;
  final int homeId;
  final int? homeScore;
  final int? awayScore;
  final String league;
  final int goals;
  final int assists;
  final int mins;
  final bool starter;

  const PlayerMatch({
    required this.date,
    required this.home,
    required this.away,
    required this.homeId,
    required this.homeScore,
    required this.awayScore,
    required this.league,
    required this.goals,
    required this.assists,
    required this.mins,
    required this.starter,
  });

  factory PlayerMatch.fromJson(Map<String, dynamic> j) => PlayerMatch(
        date: _s(j['date']),
        home: _s(j['home_team']),
        away: _s(j['away_team']),
        homeId: _i(j['home_id']),
        homeScore: j['home_score'] is num ? (j['home_score'] as num).toInt() : null,
        awayScore: j['away_score'] is num ? (j['away_score'] as num).toInt() : null,
        league: _s(j['league_name']),
        goals: _i(j['goals']),
        assists: _i(j['assists']),
        mins: _i(j['mins_played']),
        starter: j['is_starter'] == 1 || j['is_starter'] == true,
      );
}

/// GET /players/stats: összesített számok és meccsenkénti bontás.
class PlayerStats {
  final String position;
  final String nationality;
  final Map<String, num> totals;
  final List<PlayerMatch> matches;

  const PlayerStats({
    required this.position,
    required this.nationality,
    required this.totals,
    required this.matches,
  });

  num total(String key) => totals[key] ?? 0;

  factory PlayerStats.fromJson(Map<String, dynamic> j) {
    final p = j['player'] is Map ? Map<String, dynamic>.from(j['player'] as Map) : <String, dynamic>{};
    final t = j['totals'];
    final ms = j['matches'];
    final totals = <String, num>{};
    if (t is Map) {
      for (final e in t.entries) {
        if (e.value is num) totals[e.key.toString()] = e.value as num;
      }
    }
    return PlayerStats(
      position: _s(p['position']),
      nationality: _s(p['nationality']),
      totals: totals,
      matches: [
        if (ms is List)
          for (final m in ms)
            if (m is Map) PlayerMatch.fromJson(Map<String, dynamic>.from(m)),
      ],
    );
  }
}
