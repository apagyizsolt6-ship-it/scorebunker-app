import 'package:intl/intl.dart';

class Fixture {
  final int id;
  final int homeId;
  final int awayId;
  final int leagueId;
  final String leagueName;
  final String leagueZone;
  final String leagueGeo;
  final String homeTeam;
  final String awayTeam;
  final String status;
  final String? minute;
  final int? homeScore;
  final int? awayScore;
  final int? penaltyHome;
  final int? penaltyAway;
  final String date;
  final DateTime? kickoff;

  const Fixture({
    required this.id,
    required this.homeId,
    required this.awayId,
    required this.leagueId,
    required this.leagueName,
    required this.leagueZone,
    required this.leagueGeo,
    required this.homeTeam,
    required this.awayTeam,
    required this.status,
    required this.minute,
    required this.homeScore,
    required this.awayScore,
    required this.penaltyHome,
    required this.penaltyAway,
    required this.date,
    required this.kickoff,
  });

  bool get isLive => status == 'LIVE';
  bool get isScheduled => status == 'Scheduled';
  bool get isFinished =>
      status == 'FT' || status == 'AET' || status == 'PENS';
  bool get hasScore => homeScore != null && awayScore != null;

  String get timeLabel {
    if (isLive) return minute ?? 'LIVE';
    if (isScheduled) {
      return kickoff != null ? DateFormat('HH:mm').format(kickoff!) : '--:--';
    }
    return status;
  }

  factory Fixture.fromJson(Map<String, dynamic> j) {
    int? i(dynamic v) => (v as num?)?.toInt();
    final k = j['kickoff_utc'] as String?;
    return Fixture(
      id: i(j['id']) ?? 0,
      homeId: i(j['home_id']) ?? 0,
      awayId: i(j['away_id']) ?? 0,
      leagueId: i(j['league_id']) ?? 0,
      leagueName: (j['league_name'] ?? '') as String,
      leagueZone: (j['league_zone'] ?? '') as String,
      leagueGeo: (j['league_geo'] ?? '') as String,
      homeTeam: (j['home_team'] ?? '') as String,
      awayTeam: (j['away_team'] ?? '') as String,
      status: (j['status'] ?? '') as String,
      minute: j['minute']?.toString(),
      homeScore: i(j['home_score']),
      awayScore: i(j['away_score']),
      penaltyHome: i(j['penalty_home']),
      penaltyAway: i(j['penalty_away']),
      date: (j['date'] ?? '') as String,
      kickoff: k != null ? DateTime.tryParse(k)?.toLocal() : null,
    );
  }
}

class FixtureEvent {
  final String type;
  final String side;
  final String player;
  final String minute;
  final String? extra;

  const FixtureEvent({
    required this.type,
    required this.side,
    required this.player,
    required this.minute,
    required this.extra,
  });

  String get icon {
    if (type.contains('goal')) return '⚽';
    if (type.contains('yellow')) return '🟨';
    if (type.contains('red')) return '🟥';
    if (type.contains('sub')) return '🔁';
    return '•';
  }

  factory FixtureEvent.fromJson(Map<String, dynamic> j) => FixtureEvent(
        type: (j['event_type'] ?? '') as String,
        side: (j['team_side'] ?? '') as String,
        player: (j['player_name'] ?? '') as String,
        minute: (j['minute'] ?? '') as String,
        extra: j['extra_info'] as String?,
      );
}
