import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/slip.dart';

class SlipStore {
  static const _k = 'slips_v1';

  static Future<List<Slip>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s == null || s.isEmpty) return [];
    try {
      final j = jsonDecode(s);
      if (j is List) {
        return [
          for (final x in j)
            if (x is Map) Slip.fromJson(Map<String, dynamic>.from(x)),
        ];
      }
    } catch (_) {}
    return [];
  }

  static Future<void> save(List<Slip> slips) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode([for (final s in slips) s.toJson()]));
  }
}
