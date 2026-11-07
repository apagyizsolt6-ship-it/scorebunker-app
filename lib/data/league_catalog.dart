import '../models/fixture.dart';

// ==================== TOP BAJNOKSÁGOK ====================

class TopLeague {
  final String key;
  final String nameHu;
  final String geo; // zászlóhoz
  final bool Function(Fixture f) matches;

  TopLeague({
    required this.key,
    required this.nameHu,
    required this.geo,
    required this.matches,
  });
}

bool _inCountry(Fixture f, String zone, String geo) =>
    f.leagueZone.toLowerCase() == zone ||
    f.leagueGeo.toUpperCase() == geo;

bool _excluded(String n) {
  const bad = [
    'women',
    'woman',
    'femin',
    'frauen',
    'féminine',
    'qualif',
    'u17',
    'u18',
    'u19',
    'u20',
    'u21',
    'u23',
    'youth',
    'reserve',
  ];
  return bad.any(n.contains);
}

bool _european(Fixture f, String n) {
  final z = f.leagueZone.toLowerCase();
  final other = ['afc', 'caf', 'concacaf', 'conmebol', 'asian', 'african', 'ofc']
      .any(n.contains);
  if (other) return false;
  return n.contains('uefa') ||
      z == 'europe' ||
      f.leagueGeo.toUpperCase() == 'EU';
}

/// A megjelenítés sorrendje megegyezik a lista sorrendjével.
final List<TopLeague> topLeagues = [
  TopLeague(
    key: 'epl',
    nameHu: 'Premier League',
    geo: 'GB-ENG',
    matches: (f) {
      final n = f.leagueName.toLowerCase().trim();
      return _inCountry(f, 'england', 'GB-ENG') &&
          n == 'premier league' &&
          !_excluded(n);
    },
  ),
  TopLeague(
    key: 'laliga',
    nameHu: 'La Liga',
    geo: 'ES',
    matches: (f) {
      final n = f.leagueName.toLowerCase();
      return _inCountry(f, 'spain', 'ES') &&
          n.contains('la liga') &&
          !n.contains('2') &&
          !_excluded(n);
    },
  ),
  TopLeague(
    key: 'bundesliga',
    nameHu: 'Bundesliga',
    geo: 'DE',
    matches: (f) {
      final n = f.leagueName.toLowerCase();
      return _inCountry(f, 'germany', 'DE') &&
          n.contains('bundesliga') &&
          !n.contains('2') &&
          !n.contains('3') &&
          !_excluded(n);
    },
  ),
  TopLeague(
    key: 'seriea',
    nameHu: 'Serie A',
    geo: 'IT',
    matches: (f) {
      final n = f.leagueName.toLowerCase();
      return _inCountry(f, 'italy', 'IT') &&
          n.contains('serie a') &&
          !_excluded(n);
    },
  ),
  TopLeague(
    key: 'ligue1',
    nameHu: 'Ligue 1',
    geo: 'FR',
    matches: (f) {
      final n = f.leagueName.toLowerCase();
      return _inCountry(f, 'france', 'FR') &&
          n.contains('ligue 1') &&
          !_excluded(n);
    },
  ),
  TopLeague(
    key: 'ucl',
    nameHu: 'Bajnokok Ligája',
    geo: 'EU',
    matches: (f) {
      final n = f.leagueName.toLowerCase();
      return n.contains('champions league') &&
          _european(f, n) &&
          !_excluded(n);
    },
  ),
  TopLeague(
    key: 'uel',
    nameHu: 'Európa-liga',
    geo: 'EU',
    matches: (f) {
      final n = f.leagueName.toLowerCase();
      return n.contains('europa league') &&
          !n.contains('conference') &&
          _european(f, n) &&
          !_excluded(n);
    },
  ),
  TopLeague(
    key: 'uecl',
    nameHu: 'Konferencialiga',
    geo: 'EU',
    matches: (f) {
      final n = f.leagueName.toLowerCase();
      return n.contains('conference league') &&
          _european(f, n) &&
          !_excluded(n);
    },
  ),
];

TopLeague? topLeagueOf(Fixture f) {
  for (final t in topLeagues) {
    if (t.matches(f)) return t;
  }
  return null;
}

// ==================== MAGYAR ORSZÁGNEVEK ====================

const Map<String, String> _countriesHu = {
  'england': 'Anglia',
  'scotland': 'Skócia',
  'wales': 'Wales',
  'northern ireland': 'Észak-Írország',
  'ireland': 'Írország',
  'republic of ireland': 'Írország',
  'spain': 'Spanyolország',
  'germany': 'Németország',
  'italy': 'Olaszország',
  'france': 'Franciaország',
  'hungary': 'Magyarország',
  'portugal': 'Portugália',
  'netherlands': 'Hollandia',
  'belgium': 'Belgium',
  'turkey': 'Törökország',
  'türkiye': 'Törökország',
  'turkiye': 'Törökország',
  'greece': 'Görögország',
  'austria': 'Ausztria',
  'switzerland': 'Svájc',
  'denmark': 'Dánia',
  'sweden': 'Svédország',
  'norway': 'Norvégia',
  'finland': 'Finnország',
  'iceland': 'Izland',
  'poland': 'Lengyelország',
  'czech republic': 'Csehország',
  'czechia': 'Csehország',
  'slovakia': 'Szlovákia',
  'slovenia': 'Szlovénia',
  'croatia': 'Horvátország',
  'serbia': 'Szerbia',
  'romania': 'Románia',
  'bulgaria': 'Bulgária',
  'ukraine': 'Ukrajna',
  'russia': 'Oroszország',
  'belarus': 'Fehéroroszország',
  'bosnia and herzegovina': 'Bosznia-Hercegovina',
  'bosnia-herzegovina': 'Bosznia-Hercegovina',
  'montenegro': 'Montenegró',
  'north macedonia': 'Észak-Macedónia',
  'macedonia': 'Észak-Macedónia',
  'albania': 'Albánia',
  'kosovo': 'Koszovó',
  'moldova': 'Moldova',
  'latvia': 'Lettország',
  'lithuania': 'Litvánia',
  'estonia': 'Észtország',
  'cyprus': 'Ciprus',
  'malta': 'Málta',
  'luxembourg': 'Luxemburg',
  'faroe islands': 'Feröer-szigetek',
  'andorra': 'Andorra',
  'san marino': 'San Marino',
  'gibraltar': 'Gibraltár',
  'liechtenstein': 'Liechtenstein',
  'israel': 'Izrael',
  'georgia': 'Grúzia',
  'armenia': 'Örményország',
  'azerbaijan': 'Azerbajdzsán',
  'kazakhstan': 'Kazahsztán',
  'usa': 'Egyesült Államok',
  'united states': 'Egyesült Államok',
  'canada': 'Kanada',
  'mexico': 'Mexikó',
  'brazil': 'Brazília',
  'argentina': 'Argentína',
  'chile': 'Chile',
  'colombia': 'Kolumbia',
  'uruguay': 'Uruguay',
  'paraguay': 'Paraguay',
  'peru': 'Peru',
  'ecuador': 'Ecuador',
  'bolivia': 'Bolívia',
  'venezuela': 'Venezuela',
  'costa rica': 'Costa Rica',
  'honduras': 'Honduras',
  'guatemala': 'Guatemala',
  'panama': 'Panama',
  'jamaica': 'Jamaica',
  'japan': 'Japán',
  'south korea': 'Dél-Korea',
  'korea republic': 'Dél-Korea',
  'china': 'Kína',
  'australia': 'Ausztrália',
  'new zealand': 'Új-Zéland',
  'india': 'India',
  'indonesia': 'Indonézia',
  'thailand': 'Thaiföld',
  'vietnam': 'Vietnam',
  'malaysia': 'Malajzia',
  'singapore': 'Szingapúr',
  'saudi arabia': 'Szaúd-Arábia',
  'qatar': 'Katar',
  'united arab emirates': 'Egyesült Arab Emírségek',
  'uae': 'Egyesült Arab Emírségek',
  'iran': 'Irán',
  'iraq': 'Irak',
  'jordan': 'Jordánia',
  'egypt': 'Egyiptom',
  'morocco': 'Marokkó',
  'algeria': 'Algéria',
  'tunisia': 'Tunézia',
  'south africa': 'Dél-Afrika',
  'nigeria': 'Nigéria',
  'ghana': 'Ghána',
  'kenya': 'Kenya',
  'europe': 'Európa',
  'world': 'Világ',
  'international': 'Nemzetközi',
  'south america': 'Dél-Amerika',
  'north america': 'Észak-Amerika',
  'north & central america': 'Észak- és Közép-Amerika',
  'asia': 'Ázsia',
  'africa': 'Afrika',
  'oceania': 'Óceánia',
};

String countryHu(String zone) => _countriesHu[zone.toLowerCase().trim()] ?? zone;

// ==================== MAGYAR BAJNOKSÁGNEVEK ====================

const List<MapEntry<String, String>> _leaguePhrases = [
  MapEntry('UEFA Champions League', 'UEFA Bajnokok Ligája'),
  MapEntry('UEFA Europa Conference League', 'UEFA Konferencialiga'),
  MapEntry('UEFA Conference League', 'UEFA Konferencialiga'),
  MapEntry('UEFA Europa League', 'UEFA Európa-liga'),
  MapEntry('UEFA Nations League', 'UEFA Nemzetek Ligája'),
  MapEntry('Champions League', 'Bajnokok Ligája'),
  MapEntry('Conference League', 'Konferencialiga'),
  MapEntry('Europa League', 'Európa-liga'),
  MapEntry('Nations League', 'Nemzetek Ligája'),
  MapEntry('Super Cup', 'Szuperkupa'),
  MapEntry('World Cup', 'Világbajnokság'),
  MapEntry('European Championship', 'Európa-bajnokság'),
];

const Map<String, String> _leagueWords = {
  'Cup': 'Kupa',
  'League': 'Liga',
  'Women': 'Női',
  'Men': 'Férfi',
  'Spanish': 'Spanyol',
  'English': 'Angol',
  'German': 'Német',
  'Italian': 'Olasz',
  'French': 'Francia',
  'Dutch': 'Holland',
  'Portuguese': 'Portugál',
  'Belgian': 'Belga',
  'Scottish': 'Skót',
  'Welsh': 'Walesi',
  'Irish': 'Ír',
  'Turkish': 'Török',
  'Greek': 'Görög',
  'Hungarian': 'Magyar',
  'Austrian': 'Osztrák',
  'Swiss': 'Svájci',
  'Danish': 'Dán',
  'Swedish': 'Svéd',
  'Norwegian': 'Norvég',
  'Finnish': 'Finn',
  'Polish': 'Lengyel',
  'Czech': 'Cseh',
  'Slovak': 'Szlovák',
  'Croatian': 'Horvát',
  'Serbian': 'Szerb',
  'Romanian': 'Román',
  'Bulgarian': 'Bolgár',
  'Ukrainian': 'Ukrán',
  'Russian': 'Orosz',
  'Brazilian': 'Brazil',
  'Argentine': 'Argentin',
  'Argentinian': 'Argentin',
  'Chilean': 'Chilei',
  'Colombian': 'Kolumbiai',
  'Uruguayan': 'Uruguayi',
  'Mexican': 'Mexikói',
  'American': 'Amerikai',
  'Canadian': 'Kanadai',
  'Australian': 'Ausztrál',
  'Japanese': 'Japán',
  'Chinese': 'Kínai',
  'Korean': 'Koreai',
  'Saudi': 'Szaúdi',
  'Egyptian': 'Egyiptomi',
  'Moroccan': 'Marokkói',
  'Israeli': 'Izraeli',
  'Cypriot': 'Ciprusi',
};

String leagueHu(String name) {
  var s = name;
  for (final e in _leaguePhrases) {
    s = s.replaceAll(e.key, e.value);
  }
  return s.split(' ').map((w) => _leagueWords[w] ?? w).join(' ');
}
