import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/backtest.dart';

/// A trendek és becslések naplója a későbbi visszamérésekhez.
/// A bejegyzések 21 napig maradnak meg.
class BacktestStore {
  static const _k = 'backtest_v1';
  static const _maxEntries = 4000;

  /// A mentések sorba rendezve futnak, hogy ne írják felül egymást.
  static Future<void> _chain = Future<void>.value();

  static Future<BacktestLog> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s == null || s.isEmpty) return const BacktestLog();
    try {
      final j = jsonDecode(s);
      if (j is! Map) return const BacktestLog();
      final t = j['t'];
      final e = j['e'];
      return BacktestLog(
        trends: [
          if (t is List)
            for (final x in t)
              if (x is Map)
                TrendLogEntry.fromJson(Map<String, dynamic>.from(x)),
        ],
        estimates: [
          if (e is List)
            for (final x in e)
              if (x is Map)
                EstimateLogEntry.fromJson(Map<String, dynamic>.from(x)),
        ],
      );
    } catch (_) {
      return const BacktestLog();
    }
  }

  static Future<void> _save(BacktestLog log) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode({
        't': [for (final x in log.trends) x.toJson()],
        'e': [for (final x in log.estimates) x.toJson()],
      }),
    );
  }

  static Future<void> add({
    required List<TrendLogEntry> trends,
    required List<EstimateLogEntry> estimates,
  }) {
    if (trends.isEmpty && estimates.isEmpty) return _chain;
    _chain = _chain.then((_) async {
      final cur = await load();
      final tMap = <String, TrendLogEntry>{
        for (final x in cur.trends) '${x.fixtureId}|${x.kind}': x,
      };
      final eMap = <int, EstimateLogEntry>{
        for (final x in cur.estimates) x.fixtureId: x,
      };
      var changed = false;
      for (final x in trends) {
        final key = '${x.fixtureId}|${x.kind}';
        if (!tMap.containsKey(key)) {
          tMap[key] = x;
          changed = true;
        }
      }
      for (final x in estimates) {
        if (!eMap.containsKey(x.fixtureId)) {
          eMap[x.fixtureId] = x;
          changed = true;
        }
      }
      if (!changed) return;

      final limit = DateTime.now().subtract(const Duration(days: 21));
      final minDate =
          '${limit.year.toString().padLeft(4, '0')}-${limit.month.toString().padLeft(2, '0')}-${limit.day.toString().padLeft(2, '0')}';

      var tl = [
        for (final x in tMap.values)
          if (x.date.compareTo(minDate) >= 0) x,
      ]..sort((a, b) => a.date.compareTo(b.date));
      var el = [
        for (final x in eMap.values)
          if (x.date.compareTo(minDate) >= 0) x,
      ]..sort((a, b) => a.date.compareTo(b.date));
      if (tl.length > _maxEntries) tl = tl.sublist(tl.length - _maxEntries);
      if (el.length > _maxEntries) el = el.sublist(el.length - _maxEntries);
      await _save(BacktestLog(trends: tl, estimates: el));
    }).catchError((Object _) {});
    return _chain;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k);
  }
}
