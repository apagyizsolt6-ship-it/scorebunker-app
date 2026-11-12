import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Egy csapat a helyi csapatindexben (a lekért meccslistákból épül).
class TeamEntry {
  final int id;
  final String name;
  final String league;

  const TeamEntry(this.id, this.name, this.league);

  Map<String, dynamic> toJson() => {'i': id, 'n': name, 'l': league};

  factory TeamEntry.fromJson(Map<String, dynamic> j) => TeamEntry(
        (j['i'] as num?)?.toInt() ?? 0,
        (j['n'] ?? '').toString(),
        (j['l'] ?? '').toString(),
      );
}

class TeamIndexStore {
  static const _k = 'team_index_v1';

  static Future<Map<int, TeamEntry>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    final out = <int, TeamEntry>{};
    if (s == null || s.isEmpty) return out;
    try {
      final j = jsonDecode(s);
      if (j is List) {
        for (final x in j) {
          if (x is Map) {
            final e = TeamEntry.fromJson(Map<String, dynamic>.from(x));
            if (e.id != 0 && e.name.isNotEmpty) out[e.id] = e;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> save(Map<int, TeamEntry> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode([for (final e in m.values) e.toJson()]));
  }
}

const Map<String, String> _fold = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ő': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'ű': 'u', 'û': 'u',
  'ç': 'c', 'č': 'c', 'ć': 'c', 'ñ': 'n', 'ń': 'n', 'š': 's', 'ś': 's',
  'ž': 'z', 'ź': 'z', 'ż': 'z', 'ł': 'l', 'ß': 'ss', 'ğ': 'g', 'ý': 'y',
};

/// Kereséshez: kisbetű, ékezetek nélkül.
String foldText(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(_fold[c] ?? c);
  }
  return b.toString();
}
