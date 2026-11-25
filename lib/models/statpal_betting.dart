/// Rugalmas StatPal odds- és hiányzó-játékos adatfeldolgozó.
/// A StatPal egyes piacai különböző mélységű JSON-struktúrával érkezhetnek,
/// ezért a modell több elterjedt mezőnevet kezel.
class StatPalOddsRow {
  final String market;
  final String selection;
  final String bookmaker;
  final String? line;
  final double odds;

  const StatPalOddsRow({
    required this.market,
    required this.selection,
    required this.bookmaker,
    required this.line,
    required this.odds,
  });

  static List<StatPalOddsRow> parse(dynamic root) {
    final rows = <StatPalOddsRow>[];
    final seen = <String>{};

    String text(dynamic v) => v == null ? '' : v.toString().trim();
    String first(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is num) return v.toString();
      }
      return '';
    }

    void walk(dynamic value, {String market = '', String selection = '', String book = '', String? line = '', bool inOdds = false}) {
      if (value is List) {
        for (final item in value) {
          walk(item, market: market, selection: selection, book: book, line: line, inOdds: inOdds);
        }
        return;
      }
      if (value is! Map) return;
      final m = Map<dynamic, dynamic>.from(value);
      final nextBook = first(m, ['bookmaker', 'bookmaker_name', 'book', 'provider', 'source']).isNotEmpty
          ? first(m, ['bookmaker', 'bookmaker_name', 'book', 'provider', 'source']) : book;
      final hasOutcomes = m.containsKey('outcomes') || m.containsKey('selections') || m.containsKey('runners');
      final ownMarket = first(m, ['market_name', 'market', 'market_type', 'bet_type']);
      final named = first(m, ['name', 'title', 'label']);
      final nextMarket = ownMarket.isNotEmpty
          ? ownMarket
          : (hasOutcomes && named.isNotEmpty ? named : market);
      final nextSelection = first(m, ['selection', 'outcome', 'runner', 'team_name', 'participant']).isNotEmpty
          ? first(m, ['selection', 'outcome', 'runner', 'team_name', 'participant'])
          : (named.isNotEmpty && !hasOutcomes && nextMarket != named ? named : selection);
      final rawLine = first(m, ['handicap', 'line', 'total', 'points']);
      final nextLine = rawLine.isNotEmpty ? rawLine : line;

      dynamic rawOdds;
      for (final k in ['decimal_odds', 'odds_decimal', 'odd', 'odds', 'price']) {
        if (m[k] is num || m[k] is String) { rawOdds = m[k]; break; }
      }
      if (rawOdds == null && inOdds && (m['value'] is num || m['value'] is String)) rawOdds = m['value'];
      final parsed = rawOdds is num ? rawOdds.toDouble() : double.tryParse(text(rawOdds));
      if (parsed != null && parsed > 1.0 && parsed < 10000 && nextMarket.isNotEmpty && nextSelection.isNotEmpty) {
        final row = StatPalOddsRow(
          market: nextMarket,
          selection: nextSelection,
          bookmaker: nextBook,
          line: nextLine?.isEmpty == true ? null : nextLine,
          odds: parsed,
        );
        final key = '${row.market}|${row.selection}|${row.bookmaker}|${row.line}|${row.odds}';
        if (seen.add(key)) rows.add(row);
      }
      for (final entry in m.entries) {
        final k = entry.key.toString().toLowerCase();
        final oddsContext = inOdds || k.contains('odds') || k.contains('market') || k.contains('bookmaker');
        if (entry.value is Map || entry.value is List) {
          walk(entry.value, market: nextMarket, selection: nextSelection, book: nextBook, line: nextLine, inOdds: oddsContext);
        }
      }
    }

    walk(root, inOdds: true);
    rows.sort((a, b) => a.market.compareTo(b.market));
    return rows;
  }
}

class StatPalAbsence {
  final String player;
  final String team;
  final String status;
  final String reason;
  const StatPalAbsence({required this.player, required this.team, required this.status, required this.reason});

  static List<StatPalAbsence> parse(dynamic root) {
    final out = <StatPalAbsence>[];
    final seen = <String>{};
    String s(dynamic v) => (v ?? '').toString().trim();
    void walk(dynamic v, {String inheritedTeam = ''}) {
      if (v is List) { for (final x in v) walk(x, inheritedTeam: inheritedTeam); return; }
      if (v is! Map) return;
      final m = Map<dynamic, dynamic>.from(v);
      final teamVal = m['team'];
      final team = teamVal is Map ? s(teamVal['name']) : s(teamVal).isNotEmpty ? s(teamVal) : inheritedTeam;
      final playerVal = m['player'];
      final player = playerVal is Map ? s(playerVal['name'] ?? playerVal['full_name']) : s(playerVal).isNotEmpty ? s(playerVal) : s(m['player_name'] ?? m['name']);
      final status = s(m['status'] ?? m['availability'] ?? m['type']);
      final reason = s(m['reason'] ?? m['injury'] ?? m['description'] ?? m['detail']);
      if (player.isNotEmpty && (status.isNotEmpty || reason.isNotEmpty)) {
        final row = StatPalAbsence(player: player, team: team, status: status, reason: reason);
        if (seen.add('${row.player}|${row.team}|${row.status}|${row.reason}')) out.add(row);
      }
      for (final x in m.values) { if (x is Map || x is List) walk(x, inheritedTeam: team); }
    }
    walk(root);
    return out;
  }
}
