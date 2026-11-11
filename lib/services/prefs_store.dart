import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';

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

  /// Félidő és végeredmény jelzése a kedvenc csapatok meccsein.
  final bool notifyStatus;

  /// Piros lap jelzése a kedvenc csapatok meccsein.
  final bool notifyRed;

  /// Csendes órák: ebben az idősávban nem jön értesítés.
  final bool quietEnabled;
  final int quietStart;
  final int quietEnd;

  /// Akcentszín (a `kAccents` listából) és valódi fekete (OLED) sötét téma.
  final int accentIndex;
  final bool oledBlack;

  const AppSettings({
    this.showLogos = false,
    this.themeMode = ThemeMode.system,
    this.notifyKickoff = false,
    this.kickoffMinutes = 30,
    this.notifyGoals = true,
    this.notifyStatus = true,
    this.notifyRed = true,
    this.quietEnabled = false,
    this.quietStart = 23,
    this.quietEnd = 7,
    this.accentIndex = 0,
    this.oledBlack = false,
  });

  AppSettings copyWith({
    bool? showLogos,
    ThemeMode? themeMode,
    bool? notifyKickoff,
    int? kickoffMinutes,
    bool? notifyGoals,
    bool? notifyStatus,
    bool? notifyRed,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
    int? accentIndex,
    bool? oledBlack,
  }) =>
      AppSettings(
        showLogos: showLogos ?? this.showLogos,
        themeMode: themeMode ?? this.themeMode,
        notifyKickoff: notifyKickoff ?? this.notifyKickoff,
        kickoffMinutes: kickoffMinutes ?? this.kickoffMinutes,
        notifyGoals: notifyGoals ?? this.notifyGoals,
        notifyStatus: notifyStatus ?? this.notifyStatus,
        notifyRed: notifyRed ?? this.notifyRed,
        quietEnabled: quietEnabled ?? this.quietEnabled,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        accentIndex: accentIndex ?? this.accentIndex,
        oledBlack: oledBlack ?? this.oledBlack,
      );
}

/// Igaz, ha az adott időpont a beállított csendes órákba esik.
bool isQuiet(AppSettings s, [DateTime? at]) {
  if (!s.quietEnabled) return false;
  final h = (at ?? DateTime.now()).hour;
  final a = s.quietStart;
  final b = s.quietEnd;
  if (a == b) return false;
  return a < b ? (h >= a && h < b) : (h >= a || h < b);
}

class SettingsStore {
  static const _logos = 'show_logos';
  static const _theme = 'theme_mode';
  static const _nKick = 'notify_kickoff';
  static const _nMin = 'kickoff_minutes';
  static const _nGoal = 'notify_goals';
  static const _nStatus = 'notify_status';
  static const _nRed = 'notify_red';
  static const _qOn = 'quiet_on';
  static const _qStart = 'quiet_start';
  static const _qEnd = 'quiet_end';
  static const _accent = 'accent_idx';
  static const _oled = 'oled_black';

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
      notifyStatus: p.getBool(_nStatus) ?? true,
      notifyRed: p.getBool(_nRed) ?? true,
      quietEnabled: p.getBool(_qOn) ?? false,
      quietStart: p.getInt(_qStart) ?? 23,
      quietEnd: p.getInt(_qEnd) ?? 7,
      accentIndex: p.getInt(_accent) ?? 0,
      oledBlack: p.getBool(_oled) ?? false,
    );
  }

  static Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_logos, s.showLogos);
    await p.setInt(_theme, s.themeMode.index);
    await p.setBool(_nKick, s.notifyKickoff);
    await p.setInt(_nMin, s.kickoffMinutes);
    await p.setBool(_nGoal, s.notifyGoals);
    await p.setBool(_nStatus, s.notifyStatus);
    await p.setBool(_nRed, s.notifyRed);
    await p.setBool(_qOn, s.quietEnabled);
    await p.setInt(_qStart, s.quietStart);
    await p.setInt(_qEnd, s.quietEnd);
    await p.setInt(_accent, s.accentIndex);
    await p.setBool(_oled, s.oledBlack);
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

/// Kiemelt és elrejtett bajnokságok.
class LeaguePrefs {
  final Set<int> pinned;
  final Set<int> hidden;
  const LeaguePrefs({this.pinned = const {}, this.hidden = const {}});
}

class LeaguePrefsStore {
  static const _k = 'league_prefs_v1';

  static Future<LeaguePrefs> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s == null || s.isEmpty) return const LeaguePrefs();
    try {
      final j = jsonDecode(s);
      if (j is! Map) return const LeaguePrefs();
      Set<int> read(dynamic l) => {
            if (l is List)
              for (final x in l)
                if (x is num) x.toInt(),
          };
      return LeaguePrefs(pinned: read(j['p']), hidden: read(j['h']));
    } catch (_) {
      return const LeaguePrefs();
    }
  }

  static Future<void> save(LeaguePrefs lp) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode({'p': lp.pinned.toList(), 'h': lp.hidden.toList()}),
    );
  }
}

/// Egy-egy meccsre kért emlékeztetők (meccsazonosító -> emlékeztető).
class ReminderStore {
  static const _k = 'reminders_v1';

  static Future<Map<int, Reminder>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    final out = <int, Reminder>{};
    if (s == null || s.isEmpty) return out;
    try {
      final j = jsonDecode(s);
      if (j is List) {
        for (final x in j) {
          if (x is Map) {
            final r = Reminder.fromJson(Map<String, dynamic>.from(x));
            if (r.fixtureId != 0) out[r.fixtureId] = r;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> save(Map<int, Reminder> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode([for (final r in m.values) r.toJson()]));
  }
}

/// A "Követem" módban kiemelt meccsek (meccsazonosítók, legfeljebb 30).
class FollowedStore {
  static const _k = 'followed_v1';

  static Future<Set<int>> load() async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k) ?? const <String>[];
    return <int>{
      for (final x in l)
        if (int.tryParse(x) != null) int.parse(x),
    };
  }

  static Future<void> save(Set<int> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_k, [for (final i in ids) '$i']);
  }
}

/// Kedvenc játékos.
class FavPlayer {
  final String name;
  final int teamId;
  final String teamName;
  final int? shirt;
  final String position;

  const FavPlayer({
    required this.name,
    required this.teamId,
    required this.teamName,
    required this.shirt,
    required this.position,
  });

  String get key => '$teamId|$name';

  Map<String, dynamic> toJson() => {
        'n': name,
        't': teamId,
        'tn': teamName,
        's': shirt,
        'p': position,
      };

  factory FavPlayer.fromJson(Map<String, dynamic> j) => FavPlayer(
        name: (j['n'] ?? '').toString(),
        teamId: (j['t'] as num?)?.toInt() ?? 0,
        teamName: (j['tn'] ?? '').toString(),
        shirt: (j['s'] as num?)?.toInt(),
        position: (j['p'] ?? '').toString(),
      );
}

class FavPlayersStore {
  static const _k = 'fav_players_v1';

  static Future<Map<String, FavPlayer>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    final out = <String, FavPlayer>{};
    if (s == null || s.isEmpty) return out;
    try {
      final j = jsonDecode(s);
      if (j is List) {
        for (final x in j) {
          if (x is Map) {
            final f = FavPlayer.fromJson(Map<String, dynamic>.from(x));
            if (f.name.isNotEmpty && f.teamId != 0) out[f.key] = f;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> save(Map<String, FavPlayer> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode([for (final f in m.values) f.toJson()]));
  }
}
