import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BackupSummary {
  final int favorites;
  final int slips;
  final bool hasApiKey;
  final String created;
  const BackupSummary({
    required this.favorites,
    required this.slips,
    required this.hasApiKey,
    required this.created,
  });
}

/// Az app adatainak mentése egyetlen szövegbe és visszatöltése.
/// A kedvencek, szelvények, beállítások, bajnokság-szűrő, visszamérési
/// napló és kalibráció kerül bele; az emlékeztetők nem (azokat újra kell kérni).
class BackupService {
  /// kulcs -> típus: s = szöveg, b = logikai, i = egész
  static const Map<String, String> _keys = {
    'fav_teams_v1': 's',
    'slips_v1': 's',
    'backtest_v1': 's',
    'league_prefs_v1': 's',
    'calib_v1': 's',
    'show_logos': 'b',
    'theme_mode': 'i',
    'notify_kickoff': 'b',
    'kickoff_minutes': 'i',
    'notify_goals': 'b',
    'notify_status': 'b',
    'notify_red': 'b',
    'quiet_on': 'b',
    'quiet_start': 'i',
    'quiet_end': 'i',
    'league_rel_v1': 's',
  };
  static const String _apiKey = 'sportapi_key';

  static Future<String> export({bool includeApiKey = false}) async {
    final p = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final e in _keys.entries) {
      final v = switch (e.value) {
        'b' => p.getBool(e.key),
        'i' => p.getInt(e.key),
        _ => p.getString(e.key),
      };
      if (v != null) data[e.key] = v;
    }
    if (includeApiKey) {
      final k = p.getString(_apiKey);
      if (k != null && k.isNotEmpty) data[_apiKey] = k;
    }
    return JsonEncoder.withIndent(' ').convert({
      'app': 'APISCORES',
      'version': 1,
      'created': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  static Map<String, dynamic>? _parse(String text) {
    try {
      final j = jsonDecode(text.trim());
      if (j is! Map || j['app'] != 'APISCORES' || j['data'] is! Map) return null;
      return Map<String, dynamic>.from(j['data'] as Map);
    } catch (_) {
      return null;
    }
  }

  /// Ellenőrzi a szöveget és összefoglalja a tartalmát; null, ha nem mentés.
  static BackupSummary? peek(String text) {
    final data = _parse(text);
    if (data == null) return null;
    int count(String key, bool asMap) {
      final s = data[key];
      if (s is! String) return 0;
      try {
        final j = jsonDecode(s);
        if (asMap && j is Map) return j.length;
        if (!asMap && j is List) return j.length;
      } catch (_) {}
      return 0;
    }

    String created = '';
    try {
      final j = jsonDecode(text.trim());
      created = (j['created'] ?? '').toString();
    } catch (_) {}
    return BackupSummary(
      favorites: count('fav_teams_v1', true),
      slips: count('slips_v1', false),
      hasApiKey: data[_apiKey] is String,
      created: created,
    );
  }

  /// Visszatölti az adatokat. Igaz, ha sikerült.
  static Future<bool> restore(String text) async {
    final data = _parse(text);
    if (data == null) return false;
    final p = await SharedPreferences.getInstance();
    for (final e in _keys.entries) {
      final v = data[e.key];
      if (v == null) continue;
      switch (e.value) {
        case 'b':
          if (v is bool) await p.setBool(e.key, v);
        case 'i':
          if (v is num) await p.setInt(e.key, v.toInt());
        default:
          if (v is String) await p.setString(e.key, v);
      }
    }
    final k = data[_apiKey];
    if (k is String && k.isNotEmpty) await p.setString(_apiKey, k);
    return true;
  }
}
