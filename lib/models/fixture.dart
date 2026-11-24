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

  /// A külön élő végpontból érkezett friss állás ráhúzása a meccsre.
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

  factory Fixture.fromStatPal(Map<String, dynamic> j, Map<String, dynamic> league, {bool forceLive = false}) {
    int? number(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse((value ?? '').toString());
    }
    String str(dynamic value) => (value ?? '').toString();
    final home = j['home'] is Map ? Map<String, dynamic>.from(j['home']) : <String, dynamic>{};
    final away = j['away'] is Map ? Map<String, dynamic>.from(j['away']) : <String, dynamic>{};
    final dateText = str(j['date']);
    final timeText = str(j['time']);
    DateTime? kickoff;
    try {
      final date = DateFormat('dd.MM.yyyy').parseStrict(dateText);
      final hm = timeText.split(':');
      kickoff = DateTime(date.year, date.month, date.day, int.parse(hm[0]), int.parse(hm[1]));
    } catch (_) {}
    final rawStatus = str(j['status']).trim();
    final upper = rawStatus.toUpperCase();
    final status = forceLive ? 'LIVE' : const {'1H', '2H', 'HT', 'ET', 'PEN', 'LIVE', 'INPLAY', 'IN PLAY'}.contains(upper)
        ? 'LIVE'
        : const {'FT', 'AET', 'PENS', 'PENALTIES', 'FINISHED', 'ENDED'}.contains(upper)
            ? (upper == 'PENALTIES' ? 'PENS' : upper == 'FINISHED' || upper == 'ENDED' ? 'FT' : upper)
            : const {'NS', 'NOT STARTED', 'SCHEDULED', 'TIMED'}.contains(upper)
                ? 'Scheduled' : rawStatus.isEmpty ? 'Scheduled' : rawStatus;
    final penalties = j['penalties'] is Map ? Map<String, dynamic>.from(j['penalties']) : <String, dynamic>{};
    final mainId = number(j['main_id']) ?? number(j['fallback_id_1']) ?? number(j['fallback_id_2']) ?? number(j['fallback_id_3']) ?? 0;
    return Fixture(
      id: mainId,
      homeId: number(home['id']) ?? 0,
      awayId: number(away['id']) ?? 0,
      leagueId: number(league['id']) ?? 0,
      leagueName: str(league['name']),
      leagueZone: str(league['country']),
      leagueGeo: str(league['country']),
      homeTeam: str(home['name']),
      awayTeam: str(away['name']),
      status: status,
      minute: j['inj_minute']?.toString() ?? j['inj_time']?.toString(),
      homeScore: number(home['goals']),
      awayScore: number(away['goals']),
      penaltyHome: number(penalties['home_goals']),
      penaltyAway: number(penalties['away_goals']),
      date: dateText,
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
    if (type.contains('yellow') || type.contains('booking')) return '🟨';
    if (type.contains('red') || type.contains('send')) return '🟥';
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

  factory FixtureEvent.fromStatPal(
    Map<String, dynamic> j, {
    String homeId = '',
    String awayId = '',
    String homeName = '',
    String awayName = '',
  }) {
    final rawType = (j['type'] ?? '').toString().toLowerCase();
    final rawTeamValue = (j['team'] ?? '').toString();
    final rawTeam = rawTeamValue.toLowerCase();
    final side = rawTeam == 'home' || rawTeam == '1' ||
            (homeId.isNotEmpty && rawTeamValue == homeId) ||
            (homeName.isNotEmpty && rawTeam == homeName.toLowerCase())
        ? 'home'
        : rawTeam == 'away' || rawTeam == '2' ||
                (awayId.isNotEmpty && rawTeamValue == awayId) ||
                (awayName.isNotEmpty && rawTeam == awayName.toLowerCase())
            ? 'away'
            : ''; 
    final rawMinute = (j['minute'] ?? '').toString();
    final extraMinute = (j['extra_min'] ?? '').toString();
    final minute = extraMinute.isEmpty || extraMinute == '0'
        ? rawMinute
        : '$rawMinute+$extraMinute';
    return FixtureEvent(
      type: rawType,
      side: side,
      player: (j['player'] ?? '').toString(),
      minute: minute,
      extra: j['result']?.toString(),
    );
  }
}
