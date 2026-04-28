import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_rail_config.dart';
import '../utils/app_config.dart';

class UserPreferences {
  static const String _keyLastPlaylist = 'last_playlist';
  static const String _keyVolume = 'volume';
  static const String _keyAudioTrack = 'audio_track';
  static const String _keySubtitleTrack = 'subtitle_track';
  static const String _keyVideoQuality = 'video_quality';
  static const String _keyBackgroundPlay = 'background_play';
  static const String _keySubtitleFontSize = 'subtitle_font_size';
  static const String _keySubtitleHeight = 'subtitle_height';
  static const String _keySubtitleLetterSpacing = 'subtitle_letter_spacing';
  static const String _keySubtitleWordSpacing = 'subtitle_word_spacing';
  static const String _keySubtitleTextColor = 'subtitle_text_color';
  static const String _keySubtitleBackgroundColor = 'subtitle_background_color';
  static const String _keySubtitleFontWeight = 'subtitle_font_weight';
  static const String _keySubtitleTextAlign = 'subtitle_text_align';
  static const String _keySubtitlePadding = 'subtitle_padding';
  static const String _keyLocale = 'locale';
  static const String _hiddenCategoriesKey = 'hidden_categories';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyBrightnessGesture = 'brightness_gesture';
  static const String _keyVolumeGesture = 'volume_gesture';
  static const String _keySeekGesture = 'seek_gesture';
  static const String _keySpeedUpOnLongPress = 'speed_up_on_long_press';
  static const String _keySeekOnDoubleTap = 'seek_on_double_tap';
  static const String _homeRailsKey = 'home_rails_config';
  static const String _keyCurrentPlaylistJson = 'current_playlist_json';

  // Live TV settings
  static const String _keyLiveTvListStyle = 'live_tv_list_style';
  static const String _keyLiveTvShowLogos = 'live_tv_show_logos';
  static const String _keyLiveTvRememberChannel = 'live_tv_remember_channel';
  static const String _keyLiveTvGridColumns = 'live_tv_grid_columns';
  static const String _keyLiveTvSortOrder = 'live_tv_sort_order';
  static const String _keyHasSeenWelcome = 'has_seen_welcome';

  static Future<void> setLastPlaylist(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPlaylist, playlistId);
  }

  static Future<String?> getLastPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastPlaylist);
  }

  static Future<void> removeLastPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastPlaylist);
  }

  static Future<void> setVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVolume, volume);
  }

  static Future<double> getVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyVolume) ?? 100;
  }

  static Future<void> setAudioTrack(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioTrack, language);
  }

  static Future<String> getAudioTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAudioTrack) ?? 'auto';
  }

  static Future<void> setSubtitleTrack(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubtitleTrack, language);
  }

  static Future<String> getSubtitleTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySubtitleTrack) ?? 'auto';
  }

  static Future<void> setVideoTrack(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVideoQuality, id);
  }

  static Future<String> getVideoTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVideoQuality) ?? 'auto';
  }

  static const String _keyUpscalePreset = 'upscale_preset';

  static Future<void> setUpscalePreset(String preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUpscalePreset, preset);
  }

  static Future<String> getUpscalePreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUpscalePreset) ?? 'standard';
  }

  static const String _keyStreamEnhancement = 'stream_enhancement';

  static Future<void> setStreamEnhancement(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStreamEnhancement, enabled);
  }

  static Future<bool> getStreamEnhancement() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyStreamEnhancement) ?? false;
  }

  static Future<void> setBackgroundPlay(bool backgroundPlay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundPlay, backgroundPlay);
  }

  static Future<bool> getBackgroundPlay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundPlay) ?? true;
  }

  static Future<bool> getLowLatencyMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('low_latency_mode') ?? false;
  }

  static Future<void> setLowLatencyMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_latency_mode', value);
  }

  static Future<double> getSubtitleFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleFontSize) ?? 32.0;
  }

  static Future<void> setSubtitleFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleFontSize, fontSize);
  }

  static Future<double> getSubtitleHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleHeight) ?? 1.4;
  }

  static Future<void> setSubtitleHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleHeight, height);
  }

  static Future<double> getSubtitleLetterSpacing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleLetterSpacing) ?? 0.0;
  }

  static Future<void> setSubtitleLetterSpacing(double letterSpacing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleLetterSpacing, letterSpacing);
  }

  static Future<double> getSubtitleWordSpacing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleWordSpacing) ?? 0.0;
  }

  static Future<void> setSubtitleWordSpacing(double wordSpacing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleWordSpacing, wordSpacing);
  }

  static Future<Color> getSubtitleTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_keySubtitleTextColor) ?? 0xffffffff;
    return Color(colorValue);
  }

  static Future<void> setSubtitleTextColor(Color textColor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubtitleTextColor, textColor.toARGB32());
  }

  static Future<Color> getSubtitleBackgroundColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_keySubtitleBackgroundColor) ?? 0xaa000000;
    return Color(colorValue);
  }

  static Future<void> setSubtitleBackgroundColor(Color backgroundColor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubtitleBackgroundColor, backgroundColor.toARGB32());
  }

  static Future<FontWeight> getSubtitleFontWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final weightIndex =
        // ignore: deprecated_member_use
        prefs.getInt(_keySubtitleFontWeight) ?? FontWeight.normal.index;
    return FontWeight.values[weightIndex];
  }

  static Future<void> setSubtitleFontWeight(FontWeight fontWeight) async {
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    await prefs.setInt(_keySubtitleFontWeight, fontWeight.index);
  }

  static Future<TextAlign> getSubtitleTextAlign() async {
    final prefs = await SharedPreferences.getInstance();
    final alignIndex =
        // ignore: deprecated_member_use
        prefs.getInt(_keySubtitleTextAlign) ?? TextAlign.center.index;
    return TextAlign.values[alignIndex];
  }

  static Future<void> setSubtitleTextAlign(TextAlign textAlign) async {
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    await prefs.setInt(_keySubtitleTextAlign, textAlign.index);
  }

  static Future<double> getSubtitlePadding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitlePadding) ?? 24.0;
  }

  static Future<void> setSubtitlePadding(double padding) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitlePadding, padding);
  }

  static Future<String?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale);
  }

  static Future<void> setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale);
  }

  static Future<void> removeLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocale);
  }

  static Future<void> setHiddenCategories(List<String> categoryIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenCategoriesKey, categoryIds);
  }

  static Future<bool> getHiddenCategory(String categoryId) async {
    final hidden = await getHiddenCategories();
    return hidden.contains(categoryId);
  }

  static Future<List<String>> getHiddenCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenCategoriesKey) ?? [];
  }

  static const String _keyThemeName = 'theme_name';

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.toString().split('.').last);
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_keyThemeMode) ?? 'system';
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Named theme support: 'light', 'dark', 'skyBlue'
  static Future<void> setThemeName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeName, name);
  }

  static Future<String> getThemeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeName) ?? 'dark';
  }

  // Player gesture settings
  static Future<bool> getBrightnessGesture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBrightnessGesture) ?? false;
  }

  static Future<void> setBrightnessGesture(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBrightnessGesture, value);
  }

  static Future<bool> getVolumeGesture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVolumeGesture) ?? false;
  }

  static Future<void> setVolumeGesture(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVolumeGesture, value);
  }

  static Future<bool> getSeekGesture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeekGesture) ?? false;
  }

  static Future<void> setSeekGesture(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeekGesture, value);
  }

  static Future<bool> getSpeedUpOnLongPress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySpeedUpOnLongPress) ?? true;
  }

  static Future<void> setSpeedUpOnLongPress(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpeedUpOnLongPress, value);
  }

  static Future<bool> getSeekOnDoubleTap() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeekOnDoubleTap) ?? true;
  }

  static Future<void> setSeekOnDoubleTap(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeekOnDoubleTap, value);
  }

  // Live TV settings getters/setters
  static Future<String> getLiveTvListStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLiveTvListStyle) ?? 'grid';
  }

  static Future<void> setLiveTvListStyle(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLiveTvListStyle, value);
  }

  static Future<bool> getLiveTvShowLogos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLiveTvShowLogos) ?? true;
  }

  static Future<void> setLiveTvShowLogos(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLiveTvShowLogos, value);
  }

  static Future<bool> getLiveTvRememberChannel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLiveTvRememberChannel) ?? true;
  }

  static Future<void> setLiveTvRememberChannel(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLiveTvRememberChannel, value);
  }

  static Future<int> getLiveTvGridColumns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLiveTvGridColumns) ?? 0; // 0 means Auto
  }

  static Future<void> setLiveTvGridColumns(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLiveTvGridColumns, value);
  }

  static Future<String> getLiveTvSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLiveTvSortOrder) ?? 'default';
  }

  static Future<void> setLiveTvSortOrder(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLiveTvSortOrder, value);
  }

  static Future<List<HomeRailConfig>> getHomeRails() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_homeRailsKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((j) => HomeRailConfig.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> setHomeRails(List<HomeRailConfig> rails) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(rails.map((r) => r.toJson()).toList());
    await prefs.setString(_homeRailsKey, jsonString);
  }

  // ── Welcome / Onboarding ───────────────────────────────────────────
  static Future<bool> getHasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenWelcome) ?? false;
  }

  static Future<void> setHasSeenWelcome(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenWelcome, value);
  }

  static Future<void> setCurrentPlaylistJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    // Use the 'flutter.' prefix as SharedPreferences plugin does
    await prefs.setString('flutter.$_keyCurrentPlaylistJson', json);
  }

  static Future<String?> getCurrentPlaylistJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('flutter.$_keyCurrentPlaylistJson');
  }

  // ── Sync session keys ──────────────────────────────────────────────
  static const _keySyncToken = 'sync_token';
  static const _keySyncServerUrl = 'sync_server_url';
  static const _keySyncUser = 'sync_user';

  static Future<String?> getSyncToken() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keySyncToken);
    return (val == null || val.isEmpty) ? null : val;
  }

  static Future<void> setSyncToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncToken, token);
  }

  static Future<String?> getSyncServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keySyncServerUrl);
    return (val == null || val.isEmpty) ? null : val;
  }

  static Future<void> setSyncServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncServerUrl, url);
  }

  static Future<Map<String, dynamic>> getSyncUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySyncUser);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  static Future<void> setSyncUser(Map user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncUser, jsonEncode(user));
  }

  // ── Synced collections ─────────────────────────────────────────────
  static const _keySyncedPlaylists = 'synced_playlists';
  static const _keySyncedFavorites = 'synced_favorites';
  static const _keySyncedWatchLater = 'synced_watch_later';
  static const _keySyncedContinueWatching = 'synced_continue_watching';

  static Future<List<Map>> getSyncedPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySyncedPlaylists);
    if (raw == null) return [];
    try {
      return List<Map>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  @Deprecated(
    'Ghost data — use Drift DB directly via DatabaseService or db.getAllFavorites()',
  )
  static Future<void> setSyncedPlaylists(List<Map> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncedPlaylists, jsonEncode(data));
  }

  static Future<List<Map>> getSyncedFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySyncedFavorites);
    if (raw == null) return [];
    try {
      return List<Map>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  @Deprecated(
    'Ghost data — use Drift DB directly via DatabaseService or db.getAllFavorites()',
  )
  static Future<void> setSyncedFavorites(List<Map> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncedFavorites, jsonEncode(data));
  }

  static Future<List<Map>> getSyncedWatchLater() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySyncedWatchLater);
    if (raw == null) return [];
    try {
      return List<Map>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  @Deprecated(
    'Ghost data — use Drift DB directly via DatabaseService or db.getAllFavorites()',
  )
  static Future<void> setSyncedWatchLater(List<Map> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncedWatchLater, jsonEncode(data));
  }

  static Future<List<Map>> getSyncedContinueWatching() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySyncedContinueWatching);
    if (raw == null) return [];
    try {
      return List<Map>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  @Deprecated(
    'Ghost data — use Drift DB directly via DatabaseService or db.getAllFavorites()',
  )
  static Future<void> setSyncedContinueWatching(List<Map> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncedContinueWatching, jsonEncode(data));
  }

  // Build a snapshot of all current settings to push to server
  static Future<Map<String, dynamic>> buildSettingsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();

    // Serialize home rails config
    final homeRailsRaw = prefs.getString(_homeRailsKey);

    return {
      'upscalePreset': prefs.getString('upscale_preset') ?? 'none',
      'streamEnhancement': prefs.getBool('stream_enhancement') ?? false,
      'tmdbApiKey':
          prefs.getString('tmdb_api_key') ??
          prefs.getString('tmdbApiKey') ??
          '',
      'subtitleSize': prefs.getDouble('subtitle_size') ?? 1.0,
      'subtitleColor': prefs.getInt('subtitle_color') ?? 0xFFFFFFFF,
      'last_playlist_id': prefs.getString(_keyLastPlaylist) ?? '',
      'homeRailsConfig': homeRailsRaw ?? '', // raw JSON string — no re-encoding
    };
  }

  // Apply synced settings snapshot back to SharedPreferences
  static Future<void> applySyncedSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings['upscalePreset'] != null) {
      await prefs.setString('upscale_preset', settings['upscalePreset']);
    }
    if (settings['streamEnhancement'] != null) {
      await prefs.setBool('stream_enhancement', settings['streamEnhancement']);
    }
    final tmdbKey = settings['tmdbApiKey'] ?? settings['tmdb_api_key'];
    if (tmdbKey != null && (tmdbKey as String).isNotEmpty) {
      await AppConfig.setTmdbApiKeyLocally(tmdbKey);
      debugPrint('[UserPreferences] Restored TMDB API key from sync');
    }

    if (settings['subtitleSize'] != null) {
      await prefs.setDouble(
        'subtitle_size',
        (settings['subtitleSize'] as num).toDouble(),
      );
    }
    if (settings['subtitleColor'] != null) {
      await prefs.setInt('subtitle_color', settings['subtitleColor']);
    }
    // Restore last used playlist
    if (settings['last_playlist_id'] != null &&
        (settings['last_playlist_id'] as String).isNotEmpty) {
      await prefs.setString(_keyLastPlaylist, settings['last_playlist_id']);
    }
    // Restore home rails customization
    if (settings['homeRailsConfig'] != null &&
        (settings['homeRailsConfig'] as String).isNotEmpty) {
      await prefs.setString(_homeRailsKey, settings['homeRailsConfig']);
      debugPrint('[UserPreferences] Restored homeRailsConfig from sync');
    }
  }

  static Future<void> clearSyncedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBackgroundPlay);
    await prefs.remove(_keyThemeName);
    await prefs.remove(_keyThemeMode);
    await prefs.remove(_keyBrightnessGesture);
    await prefs.remove(_keyVolumeGesture);
    await prefs.remove(_keySeekGesture);
    await prefs.remove(_keySpeedUpOnLongPress);
    await prefs.remove(_keySeekOnDoubleTap);
    await prefs.remove(_keyUpscalePreset);
    await prefs.remove(_keyStreamEnhancement);

    // Also clear the specific keys used in sync apply/build
    await prefs.remove('subtitle_size');
    await prefs.remove('subtitle_color');
    await prefs.remove('upscale_preset');
    await prefs.remove('stream_enhancement');
    await prefs.remove('tmdb_api_key');
    await prefs.remove('tmdbApiKey');
    await prefs.remove(_homeRailsKey);

    debugPrint('[UserPreferences] clearSyncedSettings: all settings reset');
  }
}
