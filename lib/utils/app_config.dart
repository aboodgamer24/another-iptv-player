import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_sync.dart';

class AppConfig {
  static const _tmdbKeyPref = 'tmdb_api_key';
  static String tmdbApiKey = '';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    tmdbApiKey = prefs.getString(_tmdbKeyPref) ?? '';
  }

  static Future<void> setTmdbApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tmdbKeyPref, key);
    await prefs.setString('tmdbApiKey', key); // Compatibility
    tmdbApiKey = key; // update in-memory value
    SettingsSync.push();
  }
}
