import 'fixture.dart';

String _s(dynamic v) => (v ?? '').toString();
int? _n(dynamic v) => v is num ? v.toInt() : null;

class TeamInfo {
  final int id;
  final String name;
  final String country;
  final String city;
  final String coach;
  final String stadium;
  final int? founded;
  final List<Fixture> matches;
  final List<String> leagues;

  const TeamInfo({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.coach,
    required this.stadium,
    required this.founded,
    required this.matches,
    required this.leagues,
  });

  factory TeamInfo.fromJson(Map<String, dynamic> j) {
    final t = j['team'] is Map ? Map<String, dynamic>.from(j['team'] as Map) : <String, dynamic>{};
    final ms = j['matches'];
    final ls = j['leagues'];
    return TeamInfo(
      id: _n(t['id']) ?? 0,
      name: _s(t['name']),
      country: _s(t['country']),
      city: _s(t['city']),
      coach: _s(t['coach_name']),
      stadium: _s(t['stadium_name']),
      founded: _n(t['founded_year']),
      matches: [
        if (ms is List)
          for (final m in ms)
            if (m is Map) Fixture.fromJson(Map<String, dynamic>.from(m)),
      ],
      leagues: [
        if (ls is List)
          for (final l in ls)
            if (l is Map && _s(l['name']).isNotEmpty) _s(l['name']),
      ],
    );
  }
}

class SquadPlayer {
  final String name;
  final String position;
  final int? number;
  final String nationality;
  final DateTime? birth;

  const SquadPlayer({
    required this.name,
    required this.position,
    required this.number,
    required this.nationality,
    required this.birth,
  });

  int? get age {
    final b = birth;
    if (b == null) return null;
    final n = DateTime.now();
    var a = n.year - b.year;
    if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
    return a;
  }

  factory SquadPlayer.fromJson(Map<String, dynamic> j) => SquadPlayer(
        name: _s(j['full_name']),
        position: _s(j['position']),
        number: _n(j['jersey_number']),
        nationality: _s(j['nationality']),
        birth: DateTime.tryParse(_s(j['date_of_birth'])),
      );
}

class Trophy {
  final int year;
  final int position;
  final String name;
  final String type;

  const Trophy({
    required this.year,
    required this.position,
    required this.name,
    required this.type,
  });

  factory Trophy.fromJson(Map<String, dynamic> j) => Trophy(
        year: _n(j['year']) ?? 0,
        position: _n(j['position']) ?? 0,
        name: _s(j['name']),
        type: _s(j['type']),
      );
}
