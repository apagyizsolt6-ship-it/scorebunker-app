import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Kedvenc csapatok: csapatazonosító -> név.
class FavoritesStore {
  static const _k = 'fav_teams_v1';

  static Future<Map<int, String>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    final out = <int, String>{};
    if (s == null || s.isEmpty) return out;
    try {
      final m = jsonDecode(s);
      if (m is Map) {
        for (final e in m.entries) {
          final id = int.tryParse('${e.key}');
          if (id != null) out[id] = '${e.value}';
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> save(Map<int, String> favs) async {
    final p = await SharedPreferences.getInstance();
    final m = <String, String>{
      for (final e in favs.entries) '${e.key}': e.value,
    };
    await p.setString(_k, jsonEncode(m));
  }
}

class AppSettings {
  final bool showLogos;
  final ThemeMode themeMode;

  const AppSettings({
    this.showLogos = false,
    this.themeMode = ThemeMode.system,
  });

  AppSettings copyWith({bool? showLogos, ThemeMode? themeMode}) => AppSettings(
        showLogos: showLogos ?? this.showLogos,
        themeMode: themeMode ?? this.themeMode,
      );
}

class SettingsStore {
  static const _logos = 'show_logos';
  static const _theme = 'theme_mode';

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getInt(_theme) ?? 0;
    final idx = (raw < 0 || raw >= ThemeMode.values.length) ? 0 : raw;
    return AppSettings(
      showLogos: p.getBool(_logos) ?? false,
      themeMode: ThemeMode.values[idx],
    );
  }

  static Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_logos, s.showLogos);
    await p.setInt(_theme, s.themeMode.index);
  }
}
