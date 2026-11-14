import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kézi korrekció egy csapatra (pl. hiányzó kulcsjátékos, rossz forma).
/// A becsült várható gólokat módosítja a megadott százalékkal.
class TeamAdjust {
  /// A csapat által lőtt gólok módosítása százalékban (−30…+30).
  final int attackPct;

  /// A csapat által kapott gólok módosítása százalékban (+: több gólt kap).
  final int defencePct;

  final String note;

  /// A korrekció lejárata (epoch ms); utána magától megszűnik.
  final int untilMs;

  const TeamAdjust({
    required this.attackPct,
    required this.defencePct,
    required this.note,
    required this.untilMs,
  });

  bool get isNeutral => attackPct == 0 && defencePct == 0;

  bool get expired => untilMs <= DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'a': attackPct,
        'd': defencePct,
        'n': note,
        'u': untilMs,
      };

  factory TeamAdjust.fromJson(Map<String, dynamic> j) => TeamAdjust(
        attackPct: (j['a'] as num?)?.toInt() ?? 0,
        defencePct: (j['d'] as num?)?.toInt() ?? 0,
        note: (j['n'] ?? '').toString(),
        untilMs: (j['u'] as num?)?.toInt() ?? 0,
      );
}

class TeamAdjustStore {
  static const _k = 'team_adjust_v1';

  static Future<Map<int, TeamAdjust>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    final out = <int, TeamAdjust>{};
    if (s == null || s.isEmpty) return out;
    try {
      final j = jsonDecode(s);
      if (j is Map) {
        for (final e in j.entries) {
          final id = int.tryParse('${e.key}');
          if (id != null && e.value is Map) {
            final a = TeamAdjust.fromJson(Map<String, dynamic>.from(e.value as Map));
            if (!a.expired && !a.isNeutral) out[id] = a;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> save(Map<int, TeamAdjust> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode({for (final e in m.entries) '${e.key}': e.value.toJson()}),
    );
  }
}
