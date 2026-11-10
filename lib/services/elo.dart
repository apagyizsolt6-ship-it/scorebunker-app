import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/fixture.dart';

/// Elo-szerű csapaterő a lejátszott meccsek eredményeiből.
/// Csak a bajnokságon belüli különbségnek van értelme (minden csapat 1500-ról indul).
class EloState {
  final Map<int, double> ratings;
  final Map<int, int> games;

  /// Az utolsó feldolgozott nap (yyyy-MM-dd), üres, ha még nincs adat.
  final String lastDate;

  const EloState({
    this.ratings = const {},
    this.games = const {},
    this.lastDate = '',
  });

  static const EloState empty = EloState();

  /// Ennyi lejátszott meccs kell egy csapatnál, hogy az Elo-ja számítson.
  static const int minGames = 8;

  bool get isEmpty => ratings.isEmpty;

  /// Hazai – vendég Elo-különbség, ha mindkét csapatról van elég adat.
  double? diff(int homeId, int awayId) {
    final h = ratings[homeId];
    final a = ratings[awayId];
    if (h == null || a == null) return null;
    if ((games[homeId] ?? 0) < minGames || (games[awayId] ?? 0) < minGames) {
      return null;
    }
    return h - a;
  }

  Map<String, dynamic> toJson() => {
        'd': lastDate,
        'r': {for (final e in ratings.entries) '${e.key}': e.value},
        'g': {for (final e in games.entries) '${e.key}': e.value},
      };

  static EloState? fromJson(dynamic j) {
    if (j is! Map) return null;
    final r = <int, double>{};
    final g = <int, int>{};
    final rm = j['r'];
    final gm = j['g'];
    if (rm is Map) {
      for (final e in rm.entries) {
        final id = int.tryParse('${e.key}');
        if (id != null && e.value is num) r[id] = (e.value as num).toDouble();
      }
    }
    if (gm is Map) {
      for (final e in gm.entries) {
        final id = int.tryParse('${e.key}');
        if (id != null && e.value is num) g[id] = (e.value as num).toInt();
      }
    }
    return EloState(ratings: r, games: g, lastDate: (j['d'] ?? '').toString());
  }
}

/// Egy nap lejátszott meccseinek feldolgozása. Az eredeti állapotot nem módosítja.
EloState applyEloResults(EloState s, List<Fixture> fixtures, String date) {
  final r = <int, double>{...s.ratings};
  final g = <int, int>{...s.games};

  final done = [
    for (final f in fixtures)
      if (f.isFinished && f.hasScore && f.homeId != 0 && f.awayId != 0) f,
  ]..sort(byKickoff);

  const k = 20.0;
  const homeAdv = 60.0;
  for (final f in done) {
    final rh = r[f.homeId] ?? 1500.0;
    final ra = r[f.awayId] ?? 1500.0;
    final expected = 1 / (1 + math.pow(10, -(rh + homeAdv - ra) / 400));
    final hs = f.homeScore!;
    final aw = f.awayScore!;
    final actual = hs > aw ? 1.0 : (hs == aw ? 0.5 : 0.0);
    final gd = (hs - aw).abs();
    final mult = gd <= 1 ? 1.0 : (gd == 2 ? 1.5 : (11 + gd) / 8);
    final delta = k * mult * (actual - expected);
    r[f.homeId] = rh + delta;
    r[f.awayId] = ra - delta;
    g[f.homeId] = (g[f.homeId] ?? 0) + 1;
    g[f.awayId] = (g[f.awayId] ?? 0) + 1;
  }
  return EloState(ratings: r, games: g, lastDate: date);
}

class EloStore {
  static const _k = 'elo_v1';

  static Future<EloState?> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s == null || s.isEmpty) return null;
    try {
      return EloState.fromJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(EloState e) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(e.toJson()));
  }
}
