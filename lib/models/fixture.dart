import 'package:intl/intl.dart';

import 'live_score.dart';

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
  final String homeShort;
  final String awayShort;
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
    this.homeShort = '',
    this.awayShort = '',
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

  /// Rövid név, ha van, különben a teljes név.
  String get homeLabel => homeShort.isEmpty ? homeTeam : homeShort;
  String get awayLabel => awayShort.isEmpty ? awayTeam : awayShort;

  String get timeLabel {
    if (isLive) return minute ?? 'LIVE';
    if (isScheduled) {
      return kickoff != null ? DateFormat('HH:mm').format(kickoff!) : '--:--';
    }
    return status;
  }

  /// A WebSocketen érkezett friss állás ráhúzása a meccsre.
  /// Befejezett meccset nem írunk felül.
  Fixture withLive(LiveScore s) {
    if (isFinished) return this;
    final liveStatus = s.status.isEmpty ? status : s.status;
    final keepMinute = isLive && liveStatus == 'LIVE';
    return Fixture(
      id: id,
      homeId: homeId,
      awayId: awayId,
      leagueId: leagueId,
      leagueName: leagueName,
      leagueZone: leagueZone,
      leagueGeo: leagueGeo,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeShort: homeShort,
      awayShort: awayShort,
      status: liveStatus,
      minute: keepMinute ? (minute ?? s.minute) : (s.minute ?? minute),
      homeScore: s.homeScore ?? homeScore,
      awayScore: s.awayScore ?? awayScore,
      penaltyHome: s.homePen ?? penaltyHome,
      penaltyAway: s.awayPen ?? penaltyAway,
      date: date,
      kickoff: kickoff,
    );
  }

  factory Fixture.fromJson(Map<String, dynamic> j) {
    int? i(dynamic v) => (v as num?)?.toInt();
    String s(dynamic v) => (v ?? '').toString();
    final k = j['kickoff_utc'] as String?;
    return Fixture(
      id: i(j['id']) ?? 0,
      homeId: i(j['home_id']) ?? 0,
      awayId: i(j['away_id']) ?? 0,
      leagueId: i(j['league_id']) ?? 0,
      leagueName: s(j['league_name']),
      leagueZone: s(j['league_zone']),
      leagueGeo: s(j['league_geo']),
      homeTeam: s(j['home_team']),
      awayTeam: s(j['away_team']),
      homeShort: s(j['home_short']),
      awayShort: s(j['away_short']),
      status: s(j['status']),
      minute: j['minute']?.toString(),
      homeScore: i(j['home_score']),
      awayScore: i(j['away_score']),
      penaltyHome: i(j['penalty_home']),
      penaltyAway: i(j['penalty_away']),
      date: s(j['date']),
      kickoff: k != null ? DateTime.tryParse(k)?.toLocal() : null,
    );
  }
}

/// Kezdési idő szerinti rendezéshez.
int byKickoff(Fixture a, Fixture b) =>
    (a.kickoff ?? DateTime(0)).compareTo(b.kickoff ?? DateTime(0));

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

  /// Rendezéshez: 45+2' -> 45.02
  double get sortKey {
    final m = RegExp(r'(\d+)(?:\s*\+\s*(\d+))?').firstMatch(minute);
    if (m == null) return 999;
    final base = int.parse(m.group(1)!);
    final extraMin = m.group(2) == null ? 0 : int.parse(m.group(2)!);
    return base + extraMin / 100;
  }

  factory FixtureEvent.fromJson(Map<String, dynamic> j) => FixtureEvent(
        type: (j['event_type'] ?? '').toString(),
        side: (j['team_side'] ?? '').toString(),
        player: (j['player_name'] ?? '').toString(),
        minute: (j['minute'] ?? '').toString(),
        extra: j['extra_info']?.toString(),
      );
}
