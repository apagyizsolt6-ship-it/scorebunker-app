import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/backtest.dart';
import '../models/calibration.dart';

class CalibrationStore {
  static const _k = 'calib_v1';

  static Future<Calibration?> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s == null || s.isEmpty) return null;
    try {
      return Calibration.fromJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Calibration c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(c.toJson()));
  }
}

/// Bajnokságonkénti találati arányok tárolása.
class ReliabilityStore {
  static const _k = 'league_rel_v1';

  static Future<Map<int, LeagueReliability>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    final out = <int, LeagueReliability>{};
    if (s == null || s.isEmpty) return out;
    try {
      final j = jsonDecode(s);
      if (j is Map) {
        for (final e in j.entries) {
          final id = int.tryParse('${e.key}');
          if (id != null && e.value is Map) {
            out[id] = LeagueReliability.fromJson(
                Map<String, dynamic>.from(e.value as Map));
          }
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> save(Map<int, LeagueReliability> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode({for (final e in m.entries) '${e.key}': e.value.toJson()}),
    );
  }
}
