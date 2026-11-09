/// Egy bajnokság a GET /leagues listából.
class LeagueInfo {
  final int id;
  final String name;
  final String country;
  final String geo;
  final int fixtures;

  const LeagueInfo({
    required this.id,
    required this.name,
    required this.country,
    required this.geo,
    required this.fixtures,
  });

  /// A válasz országonként csoportosít; ezt laposítja ki.
  static List<LeagueInfo> parseAll(dynamic data) {
    final out = <LeagueInfo>[];
    if (data is! List) return out;
    for (final c in data) {
      if (c is! Map) continue;
      final country = (c['country'] ?? '').toString();
      final geo = (c['geo'] ?? '').toString();
      final ls = c['leagues'];
      if (ls is! List) continue;
      for (final l in ls) {
        if (l is! Map) continue;
        final id = l['id'];
        if (id is! num) continue;
        final fx = l['fixtures_count'];
        out.add(LeagueInfo(
          id: id.toInt(),
          name: (l['name'] ?? '').toString(),
          country: country,
          geo: (l['geo'] ?? geo).toString(),
          fixtures: fx is num ? fx.toInt() : 0,
        ));
      }
    }
    return out;
  }
}
