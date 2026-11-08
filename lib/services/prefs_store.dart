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

  /// Értesítés a kedvenc csapatok meccsei előtt.
  final bool notifyKickoff;

  /// Ennyi perccel a kezdés előtt jön az értesítés.
  final int kickoffMinutes;

  /// Gól-értesítés a kedvenc csapatok meccsein (megnyitott appnál).
  final bool notifyGoals;

  const AppSettings({
    this.showLogos = false,
    this.themeMode = ThemeMode.system,
    this.notifyKickoff = false,
    this.kickoffMinutes = 30,
    this.notifyGoals = true,
  });

  AppSettings copyWith({
    bool? showLogos,
    ThemeMode? themeMode,
    bool? notifyKickoff,
    int? kickoffMinutes,
    bool? notifyGoals,
  }) =>
      AppSettings(
        showLogos: showLogos ?? this.showLogos,
        themeMode: themeMode ?? this.themeMode,
        notifyKickoff: notifyKickoff ?? this.notifyKickoff,
        kickoffMinutes: kickoffMinutes ?? this.kickoffMinutes,
        notifyGoals: notifyGoals ?? this.notifyGoals,
      );
}

class SettingsStore {
  static const _logos = 'show_logos';
  static const _theme = 'theme_mode';
  static const _nKick = 'notify_kickoff';
  static const _nMin = 'kickoff_minutes';
  static const _nGoal = 'notify_goals';

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getInt(_theme) ?? 0;
    final idx = (raw < 0 || raw >= ThemeMode.values.length) ? 0 : raw;
    return AppSettings(
      showLogos: p.getBool(_logos) ?? false,
      themeMode: ThemeMode.values[idx],
      notifyKickoff: p.getBool(_nKick) ?? false,
      kickoffMinutes: p.getInt(_nMin) ?? 30,
      notifyGoals: p.getBool(_nGoal) ?? true,
    );
  }

  static Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_logos, s.showLogos);
    await p.setInt(_theme, s.themeMode.index);
    await p.setBool(_nKick, s.notifyKickoff);
    await p.setInt(_nMin, s.kickoffMinutes);
    await p.setBool(_nGoal, s.notifyGoals);
  }
}

/// A beütemezett kezdés-értesítések azonosítói (meccsazonosítók),
/// hogy a következő szinkronnál le lehessen mondani őket.
class NotifStore {
  static const _k = 'notif_ids_v1';

  static Future<List<int>> load() async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k) ?? const <String>[];
    return [
      for (final s in l)
        if (int.tryParse(s) != null) int.parse(s),
    ];
  }

  static Future<void> save(List<int> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_k, [for (final i in ids) '$i']);
  }
}
