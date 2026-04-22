import 'package:flutter/material.dart';
import '../repositories/user_preferences.dart';
import '../services/settings_sync.dart';
import '../utils/app_themes.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _themeName = 'dark';

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  String get themeName => _themeName;

  /// Returns the resolved ThemeData based on the current theme name.
  ThemeData get currentThemeData => AppThemes.getThemeByName(_themeName);

  /// Whether the current theme is a dark variant.
  bool get isDark => _themeName == 'dark' || _themeName == 'crimson';

  Future<void> _loadTheme() async {
    _themeName = await UserPreferences.getThemeName();
    _themeMode = _themeModeFromName(_themeName);
    notifyListeners();
  }

  Future<void> setTheme(String name) async {
    _themeName = name;
    _themeMode = _themeModeFromName(name);
    await UserPreferences.setThemeName(name);
    notifyListeners();
    SettingsSync.push();
  }

  // Legacy helpers (kept for compatibility)
  bool isDarkMode() => _themeName == 'dark';
  bool isLightMode() => _themeName == 'light';
  bool isSystemMode() => false; // no longer used for custom themes
  bool isSkyBlueMode() => _themeName == 'skyBlue';
  bool isCrimsonMode() => _themeName == 'crimson';

  ThemeMode _themeModeFromName(String name) {
    switch (name) {
      case 'light':
      case 'skyBlue':
        return ThemeMode.light;
      case 'dark':
      case 'crimson':
        return ThemeMode.dark;
      default:
        return ThemeMode.dark;
    }
  }
}
