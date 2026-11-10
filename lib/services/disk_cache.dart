import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Egyszerű lemezes gyorsítótár az API-válaszoknak. Ha egy válasz elég friss,
/// az app nem küld új kérést, így a kérés-keretből nem fogy.
class DiskCache {
  static Directory? _dir;

  static Future<Directory?> _root() async {
    final cached = _dir;
    if (cached != null) return cached;
    try {
      final base = await getTemporaryDirectory();
      final d = Directory('${base.path}/sb_cache');
      if (!await d.exists()) await d.create(recursive: true);
      _dir = d;
      _purge(d);
      return d;
    } catch (_) {
      return null;
    }
  }

  /// A 15 napnál régebbi fájlok törlése (háttérben, hiba esetén csendben).
  static Future<void> _purge(Directory d) async {
    try {
      final limit = DateTime.now().subtract(const Duration(days: 15));
      await for (final e in d.list()) {
        if (e is File && (await e.lastModified()).isBefore(limit)) {
          await e.delete();
        }
      }
    } catch (_) {}
  }

  static String _prefix(String path) =>
      path.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');

  static String _name(String path) => '${_prefix(path)}.json';

  /// A mentett válasz, ha fiatalabb a megadott élettartamnál.
  static Future<Map<String, dynamic>?> read(String path, Duration maxAge) async {
    try {
      final d = await _root();
      if (d == null) return null;
      final f = File('${d.path}/${_name(path)}');
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map) return null;
      final t = j['t'];
      final b = j['b'];
      if (t is! num || b is! Map) return null;
      final age = DateTime.now().millisecondsSinceEpoch - t.toInt();
      if (age < 0 || age > maxAge.inMilliseconds) return null;
      return Map<String, dynamic>.from(b);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String path, Map<String, dynamic> body) async {
    try {
      final d = await _root();
      if (d == null) return;
      final f = File('${d.path}/${_name(path)}');
      await f.writeAsString(jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'b': body,
      }));
    } catch (_) {}
  }

  /// Azonnali (szinkron) törlés az adott útvonal-előtagú fájlokra,
  /// pl. `/standings`. Előtag nélkül mindent töröl.
  static void clearSync([String? pathPrefix]) {
    final d = _dir;
    if (d == null) return;
    try {
      final prefix = pathPrefix == null ? '' : _prefix(pathPrefix);
      for (final e in d.listSync()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.isEmpty ? '' : e.uri.pathSegments.last;
        if (name.startsWith(prefix)) e.deleteSync();
      }
    } catch (_) {}
  }
}
