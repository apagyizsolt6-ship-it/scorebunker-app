enum LeaderKind { scorers, assists, cards }

extension LeaderKindX on LeaderKind {
  String get path => switch (this) {
        LeaderKind.scorers => 'topscorers',
        LeaderKind.assists => 'topassists',
        LeaderKind.cards => 'topcards',
      };

  String get title => switch (this) {
        LeaderKind.scorers => 'Góllövők',
        LeaderKind.assists => 'Gólpasszok',
        LeaderKind.cards => 'Lapok',
      };

  String get unit => switch (this) {
        LeaderKind.scorers => 'gól',
        LeaderKind.assists => 'assziszt',
        LeaderKind.cards => 'lap',
      };
}

/// Egy sor a góllövő / gólpassz / lapok listában.
class LeaderRow {
  final int rank;
  final String player;
  final int teamId;
  final String team;
  final int value;
  final String extra;

  const LeaderRow({
    required this.rank,
    required this.player,
    required this.teamId,
    required this.team,
    required this.value,
    required this.extra,
  });

  factory LeaderRow.fromJson(Map<String, dynamic> j, LeaderKind kind) {
    int i(dynamic v) => v is num ? v.toInt() : 0;
    var value = 0;
    var extra = '';
    switch (kind) {
      case LeaderKind.scorers:
        value = i(j['goals']);
        final pens = i(j['penalties']);
        if (pens > 0) extra = '$pens tizenegyesből';
      case LeaderKind.assists:
        value = i(j['assists']);
      case LeaderKind.cards:
        value = i(j['total_cards']);
        final y = i(j['yellow_cards']);
        final r = i(j['red_cards']);
        extra = '🟨 $y' '${r > 0 ? '  🟥 $r' : ''}';
    }
    return LeaderRow(
      rank: i(j['rank']),
      player: (j['player_name'] ?? '').toString(),
      teamId: i(j['team_id']),
      team: (j['team_name'] ?? '').toString(),
      value: value,
      extra: extra,
    );
  }
}
