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

  factory FixtureDetail.fromStatPal(Map<String, dynamic> j) {
    int? i(dynamic v) => v is num ? v.toInt() : int.tryParse((v ?? '').toString());
    String s(dynamic v) => (v ?? '').toString();
    final ht = j['ht'] is Map ? Map<String, dynamic>.from(j['ht']) : <String, dynamic>{};
    final venue = j['venue'];
    final eventsRoot = j['events'] is Map ? Map<String, dynamic>.from(j['events']) : <String, dynamic>{};
    final eventList = eventsRoot['event'] is List ? eventsRoot['event'] : j['events'];
    return FixtureDetail(
      htHome: i(ht['home_goals']),
      htAway: i(ht['away_goals']),
      homeStadium: s(venue),
      homeCity: '',
      homeCoach: '',
      awayCoach: '',
      events: [
        if (eventList is List)
          for (final e in eventList)
            if (e is Map) FixtureEvent.fromStatPal(
              Map<String, dynamic>.from(e),
              homeId: j['home'] is Map ? (j['home']['id'] ?? '').toString() : '',
              awayId: j['away'] is Map ? (j['away']['id'] ?? '').toString() : '',
              homeName: j['home'] is Map ? (j['home']['name'] ?? '').toString() : '',
              awayName: j['away'] is Map ? (j['away']['name'] ?? '').toString() : '',
            ),
      ],
    );
  }

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
        if (v is Map) {
          final value = v['value'] ?? v['total'] ?? v['count'];
          if (value is num) out[e.key.toString()] = value;
        }
      }
    } else if (m is List) {
      for (final row in m) {
        if (row is! Map) continue;
        final key = (row['type'] ?? row['name'] ?? row['stat'] ?? '').toString();
        final value = row['value'] ?? row['total'];
        if (key.isNotEmpty && value is num) out[key] = value;
      }
    }
    return out;
  }

  factory MatchStats.fromJson(Map<String, dynamic> data) => MatchStats(
        _read(data['home'] ?? data['home_team'] ?? data['local']),
        _read(data['away'] ?? data['away_team'] ?? data['visitor']),
      );
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

  factory LineupPlayer.fromJson(Map<String, dynamic> j) {
    final player = j['player'] is Map ? Map<String, dynamic>.from(j['player']) : j;
    final shirtValue = j['shirt'] ?? j['number'] ?? j['shirt_number'] ?? player['shirt'];
    final minsValue = j['mins_played'] ?? j['minutes'] ?? j['mins'];
    return LineupPlayer(
      name: (player['name'] ?? player['full_name'] ?? j['name'] ?? '').toString(),
      position: (j['position'] ?? player['position'] ?? '').toString(),
      shirt: shirtValue is num ? shirtValue.toInt() : int.tryParse((shirtValue ?? '').toString()),
      isCaptain: j['is_captain'] == true || j['captain'] == true,
      mins: minsValue is num ? minsValue.toInt() : int.tryParse((minsValue ?? '').toString()),
    );
  }
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
      starters: _players(m['starters'] ?? m['starting_xi'] ?? m['starting']),
      subs: _players(m['subs'] ?? m['substitutes'] ?? m['bench']),
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

  factory Lineups.fromJson(Map<String, dynamic> data) {
    final teams = data['teams'] is Map ? Map<String, dynamic>.from(data['teams']) : data;
    return Lineups(
      home: TeamLineup.fromJson(teams['home'] ?? teams['home_team']),
      away: TeamLineup.fromJson(teams['away'] ?? teams['away_team']),
    );
  }
}
