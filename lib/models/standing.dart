int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);
int? _n(dynamic v) => v is num ? v.toInt() : null;
String _s(dynamic v) => (v ?? '').toString();

/// Egy csapat egy korábbi meccse a tabella `form` listájából.
class FormMatch {
  final String result; // W / D / L
  final String date;
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final bool isHome;

  const FormMatch({
    required this.result,
    required this.date,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.isHome,
  });

  bool get hasScore => homeScore != null && awayScore != null;
  int? get goalsFor => !hasScore ? null : (isHome ? homeScore : awayScore);
  int? get goalsAgainst => !hasScore ? null : (isHome ? awayScore : homeScore);
  int? get totalGoals => !hasScore ? null : homeScore! + awayScore!;
  bool get bothScored => hasScore && homeScore! > 0 && awayScore! > 0;
  String get opponent => isHome ? awayTeam : homeTeam;

  factory FormMatch.fromJson(Map<String, dynamic> j) => FormMatch(
        result: _s(j['result']),
        date: _s(j['date']),
        homeTeam: _s(j['home_team']),
        awayTeam: _s(j['away_team']),
        homeScore: _n(j['home_score']),
        awayScore: _n(j['away_score']),
        isHome: j['is_home'] == true,
      );
}

class TeamRow {
  final int position;
  final int teamId;
  final String name;
  final String shortName;
  final int played;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final String group;
  final List<FormMatch> form;

  const TeamRow({
    required this.position,
    required this.teamId,
    required this.name,
    required this.shortName,
    required this.played,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required this.group,
    required this.form,
  });

  factory TeamRow.fromJson(Map<String, dynamic> r, {String? group}) {
    final t = r['team'];
    final team = t is Map ? t : const {};
    final gf = _i(r['goals_for']);
    final ga = _i(r['goals_against']);
    final g = r['group'];
    final form = r['form'];
    return TeamRow(
      position: _i(r['position']),
      teamId: _i(team['id']),
      name: _s(team['name']),
      shortName: _s(team['short_name']),
      played: _i(r['played']),
      won: _i(r['won']),
      draw: _i(r['draw']),
      lost: _i(r['lost']),
      goalsFor: gf,
      goalsAgainst: ga,
      goalDiff: r['goal_difference'] is num ? _i(r['goal_difference']) : gf - ga,
      points: _i(r['points']),
      group: group ?? (g is String ? g : ''),
      form: [
        if (form is List)
          for (final f in form)
            if (f is Map) FormMatch.fromJson(Map<String, dynamic>.from(f)),
      ],
    );
  }
}

class LeagueTable {
  final String season;
  final String format;
  final List<TeamRow> rows;

  const LeagueTable({
    this.season = '',
    this.format = '',
    this.rows = const [],
  });

  static const LeagueTable empty = LeagueTable();

  TeamRow? rowOf(int teamId) {
    for (final r in rows) {
      if (r.teamId == teamId) return r;
    }
    return null;
  }

  /// Csoportonként (konferencia / zóna) a sorok, pozíció szerint.
  Map<String, List<TeamRow>> get byGroup {
    final out = <String, List<TeamRow>>{};
    for (final r in rows) {
      out.putIfAbsent(r.group, () => []).add(r);
    }
    for (final l in out.values) {
      l.sort((a, b) => a.position.compareTo(b.position));
    }
    return out;
  }

  factory LeagueTable.fromJson(Map<String, dynamic> j) {
    final rows = <TeamRow>[];
    final seen = <int>{};

    void read(dynamic list, String? group) {
      if (list is! List) return;
      for (final r in list) {
        if (r is! Map) continue;
        final row =
            TeamRow.fromJson(Map<String, dynamic>.from(r), group: group);
        if (row.teamId == 0) continue;
        if (seen.add(row.teamId)) rows.add(row);
      }
    }

    read(j['data'], null);
    final groups = j['groups'];
    if (groups is List) {
      for (final g in groups) {
        if (g is Map) {
          final name = (g['group'] ?? g['name'] ?? g['title'])?.toString();
          read(g['table'] ?? g['data'] ?? g['rows'], name);
        }
      }
    }
    return LeagueTable(
      season: _s(j['season']),
      format: _s(j['format']),
      rows: rows,
    );
  }
}
