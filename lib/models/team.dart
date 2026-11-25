import 'fixture.dart';

String _s(dynamic v) => (v ?? '').toString().trim();
int? _n(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v));
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
dynamic _first(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && _s(v).isNotEmpty) return v;
  }
  return null;
}
String _image(Map<String, dynamic> m) => _s(_first(m, const [
      'image_url', 'image', 'logo_url', 'logo', 'photo_url', 'photo', 'picture', 'avatar'
    ]));

class TeamInfo {
  final int id;
  final String name;
  final String country;
  final String city;
  final String coach;
  final String stadium;
  final int? founded;
  final String imageUrl;
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
    this.imageUrl = '',
    required this.matches,
    required this.leagues,
  });

  factory TeamInfo.fromJson(Map<String, dynamic> j) {
    final root = _map(j['data']);
    final t = _map(_first(root, const ['team', 'club']) ?? _first(j, const ['team', 'club']) ?? root);
    final rawMatches = _first(root, const ['matches', 'fixtures', 'results']) ??
        _first(j, const ['matches', 'fixtures', 'results']);
    final rawLeagues = _first(root, const ['leagues', 'competitions']) ??
        _first(j, const ['leagues', 'competitions']);
    final matches = <Fixture>[];
    if (rawMatches is List) {
      for (final m in rawMatches) {
        if (m is Map) {
          final f = Fixture.fromJson(Map<String, dynamic>.from(m));
          if (f.id != 0) matches.add(f);
        }
      }
    }
    final leagues = <String>[];
    if (rawLeagues is List) {
      for (final l in rawLeagues) {
        final name = l is Map ? _s(_first(Map<String, dynamic>.from(l), const ['name', 'league_name', 'title'])) : _s(l);
        if (name.isNotEmpty && !leagues.contains(name)) leagues.add(name);
      }
    }
    return TeamInfo(
      id: _n(_first(t, const ['id', 'team_id'])) ?? 0,
      name: _s(_first(t, const ['name', 'team_name', 'full_name'])),
      country: _s(_first(t, const ['country', 'country_name'])),
      city: _s(_first(t, const ['city', 'town'])),
      coach: _s(_first(t, const ['coach_name', 'coach', 'manager_name'])),
      stadium: _s(_first(t, const ['stadium_name', 'stadium', 'venue_name', 'venue'])),
      founded: _n(_first(t, const ['founded_year', 'founded', 'year_founded'])),
      imageUrl: _image(t),
      matches: matches,
      leagues: leagues,
    );
  }
}

class SquadPlayer {
  final int? playerId;
  final String name;
  final String position;
  final int? number;
  final String nationality;
  final DateTime? birth;
  final String imageUrl;

  const SquadPlayer({
    this.playerId,
    required this.name,
    required this.position,
    required this.number,
    required this.nationality,
    required this.birth,
    this.imageUrl = '',
  });

  int? get age {
    final b = birth;
    if (b == null) return null;
    final n = DateTime.now();
    var a = n.year - b.year;
    if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
    return a;
  }

  factory SquadPlayer.fromJson(Map<String, dynamic> j) {
    final p = _map(j['player']).isNotEmpty ? _map(j['player']) : j;
    final birthText = _s(_first(p, const ['date_of_birth', 'birth_date', 'dob', 'birthday']));
    return SquadPlayer(
      playerId: _n(_first(p, const ['id', 'player_id'])),
      name: _s(_first(p, const ['full_name', 'name', 'player_name', 'display_name'])),
      position: _s(_first(p, const ['position', 'position_name', 'role'])),
      number: _n(_first(p, const ['jersey_number', 'shirt_number', 'number', 'shirt'])),
      nationality: _s(_first(p, const ['nationality', 'country', 'country_name'])),
      birth: DateTime.tryParse(birthText),
      imageUrl: _image(p),
    );
  }
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
