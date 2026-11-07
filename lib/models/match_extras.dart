import 'fixture.dart';

/// GET /fixtures/{id}: félidei állás, stadion, edzők és az események.
class FixtureDetail {
  final int? htHome;
  final int? htAway;
  final String homeStadium;
  final String homeCity;
  final String homeCoach;
  final String awayCoach;
  final List<FixtureEvent> events;

  const FixtureDetail({
    required this.htHome,
    required this.htAway,
    required this.homeStadium,
    required this.homeCity,
    required this.homeCoach,
    required this.awayCoach,
    required this.events,
  });

  bool get hasHalfTime => htHome != null && htAway != null;

  factory FixtureDetail.fromJson(Map<String, dynamic> j) {
    int? i(dynamic v) => v is num ? v.toInt() : null;
    String s(dynamic v) => (v ?? '').toString();
    final ev = j['events'];
    return FixtureDetail(
      htHome: i(j['ht_home']),
      htAway: i(j['ht_away']),
      homeStadium: s(j['home_stadium']),
      homeCity: s(j['home_city']),
      homeCoach: s(j['home_coach']),
      awayCoach: s(j['away_coach']),
      events: [
        if (ev is List)
          for (final e in ev)
            if (e is Map) FixtureEvent.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}

/// GET /fixtures/{id}/stats: csapatonkénti számok (lövés, passz, ...).
class MatchStats {
  final Map<String, num> home;
  final Map<String, num> away;

  const MatchStats(this.home, this.away);

  bool get isEmpty => home.isEmpty && away.isEmpty;

  static Map<String, num> _read(dynamic m) {
    final out = <String, num>{};
    if (m is Map) {
      for (final e in m.entries) {
        final v = e.value;
        if (v is num) out[e.key.toString()] = v;
      }
    }
    return out;
  }

  factory MatchStats.fromJson(Map<String, dynamic> data) =>
      MatchStats(_read(data['home']), _read(data['away']));
}

class LineupPlayer {
  final String name;
  final String position;
  final int? shirt;
  final bool isCaptain;
  final int? mins;

  const LineupPlayer({
    required this.name,
    required this.position,
    required this.shirt,
    required this.isCaptain,
    required this.mins,
  });

  factory LineupPlayer.fromJson(Map<String, dynamic> j) => LineupPlayer(
        name: (j['name'] ?? '').toString(),
        position: (j['position'] ?? '').toString(),
        shirt: j['shirt'] is num ? (j['shirt'] as num).toInt() : null,
        isCaptain: j['is_captain'] == true,
        mins: j['mins_played'] is num ? (j['mins_played'] as num).toInt() : null,
      );
}

class TeamLineup {
  final List<LineupPlayer> starters;
  final List<LineupPlayer> subs;

  const TeamLineup({required this.starters, required this.subs});

  static List<LineupPlayer> _players(dynamic l) => [
        if (l is List)
          for (final p in l)
            if (p is Map) LineupPlayer.fromJson(Map<String, dynamic>.from(p)),
      ];

  factory TeamLineup.fromJson(dynamic j) {
    final m = j is Map ? j : const {};
    return TeamLineup(
      starters: _players(m['starters']),
      subs: _players(m['subs']),
    );
  }
}

/// GET /fixtures/{id}/lineups
class Lineups {
  final TeamLineup home;
  final TeamLineup away;

  const Lineups({required this.home, required this.away});

  bool get isEmpty =>
      home.starters.isEmpty &&
      away.starters.isEmpty &&
      home.subs.isEmpty &&
      away.subs.isEmpty;

  factory Lineups.fromJson(Map<String, dynamic> data) => Lineups(
        home: TeamLineup.fromJson(data['home']),
        away: TeamLineup.fromJson(data['away']),
      );
}
