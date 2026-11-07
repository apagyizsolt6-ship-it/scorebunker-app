/// Az élő (WebSocket) kapcsolat állapota.
enum LiveConn { off, connecting, on }

/// Egy `score_update` üzenet a SportAPI WebSocketről.
class LiveScore {
  final int fixtureId;
  final int? homeScore;
  final int? awayScore;
  final int? homePen;
  final int? awayPen;
  final String status;
  final String? minute;

  const LiveScore({
    required this.fixtureId,
    required this.homeScore,
    required this.awayScore,
    required this.homePen,
    required this.awayPen,
    required this.status,
    required this.minute,
  });

  static LiveScore? tryParse(dynamic data) {
    if (data is! Map) return null;
    if (data['type'] != 'score_update') return null;
    int? i(dynamic v) => v is num ? v.toInt() : null;
    final id = i(data['fixture_id']);
    if (id == null) return null;
    return LiveScore(
      fixtureId: id,
      homeScore: i(data['home_score']),
      awayScore: i(data['away_score']),
      homePen: i(data['home_pen']),
      awayPen: i(data['away_pen']),
      status: (data['status'] ?? '').toString(),
      minute: data['minute']?.toString(),
    );
  }
}

class LiveState {
  final Map<int, LiveScore> scores;
  final LiveConn conn;

  const LiveState({this.scores = const {}, this.conn = LiveConn.off});

  LiveState copyWith({Map<int, LiveScore>? scores, LiveConn? conn}) =>
      LiveState(scores: scores ?? this.scores, conn: conn ?? this.conn);
}
