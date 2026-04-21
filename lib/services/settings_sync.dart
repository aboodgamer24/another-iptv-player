import 'package:flutter/foundation.dart';
import 'sync_service.dart';
import '../repositories/user_preferences.dart';
import '../utils/app_config.dart';

/// Centralized fire-and-forget push of all user settings to the sync server.
class SettingsSync {
  static void push() {
    () async {
      try {
        final settings = <String, dynamic>{};

        // TMDB API key
        final tmdbKey = AppConfig.tmdbApiKey;
        if (tmdbKey.isNotEmpty) settings['tmdb_api_key'] = tmdbKey;

        // Language / locale
        final locale = await UserPreferences.getLocale();
        if (locale != null && locale.isNotEmpty) settings['language'] = locale;

        // Theme
        final theme = await UserPreferences.getThemeName();
        if (theme.isNotEmpty) settings['theme'] = theme;

        // Upscale preset
        final upscale = await UserPreferences.getUpscalePreset();
        settings['upscalePreset'] = upscale;

        // Stream enhancement
        final enhancement = await UserPreferences.getStreamEnhancement();
        settings['streamEnhancement'] = enhancement;

        // Last used playlist id
        final lastPlaylist = await UserPreferences.getLastPlaylist();
        if (lastPlaylist != null) settings['last_playlist_id'] = lastPlaylist;

        SyncService.instance.pushField('settings', settings);
        debugPrint('[SettingsSync] Settings pushed');
      } catch (e) {
        debugPrint('[SettingsSync] Push failed: $e');
      }
    }();
  }
}
