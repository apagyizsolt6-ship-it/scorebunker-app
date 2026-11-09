import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
