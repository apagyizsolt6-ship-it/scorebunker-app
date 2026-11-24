import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyStore {
  static const _key = 'statpal_access_key';
  static const _legacyKey = 'sportapi_key';

  static Future<String?> load() async {
    final p = await SharedPreferences.getInstance();
    // A régi SportAPI-kulcsot nem használjuk és nem visszük át StatPalra.
    await p.remove(_legacyKey);
    final k = p.getString(_key);
    return (k == null || k.isEmpty) ? null : k;
  }

  static Future<void> save(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_legacyKey);
    await p.setString(_key, key);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    await p.remove(_legacyKey);
  }
}
