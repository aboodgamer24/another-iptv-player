import 'package:flutter/material.dart';

class AppThemes {
  // Refined teal accent color
  static const Color _primaryColor = Color(0xFF64FFDA);
  static const Color _primaryDark = Color(0xFF00BFA5);

  // Sky Blue palette
  static const Color _skyBluePrimary = Color(0xFF4A90D9);
  static const Color _skyBlueAccent = Color(0xFF2E7BC6);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: _primaryDark,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFB2DFDB),
      onPrimaryContainer: const Color(0xFF00332C),
      secondary: const Color(0xFF4DB6AC),
      onSecondary: Colors.white,
      surface: const Color(0xFFF5F5F5),
      onSurface: const Color(0xFF1C1C1C),
      onSurfaceVariant: const Color(0xFF5F5F5F),
      outline: const Color(0xFFD0D0D0),
      surfaceContainerHighest: const Color(0xFFE8E8E8),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  static const Color midnightBg = Color(0xFF020617);
  static const Color midnightSurface = Color(0xFF0F172A);
  static const Color midnightPrimary = Color(0xFF6366F1);
  static const Color midnightAccent = Color(0xFF10B981);
  static const Color midnightTextPrimary = Color(0xFFF8FAFC);
  static const Color midnightTextSecondary = Color(0xFF94A3B8);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'DMSans',
    colorScheme: ColorScheme.dark(
      primary: midnightPrimary,
      onPrimary: Colors.white,
      primaryContainer: midnightPrimary.withValues(alpha: 0.2),
      onPrimaryContainer: midnightPrimary,
      secondary: midnightAccent,
      onSecondary: Colors.white,
      surface: midnightSurface,
      onSurface: midnightTextPrimary,
      onSurfaceVariant: midnightTextSecondary,
      outline: const Color(0xFF334155),
      surfaceContainerHighest: const Color(0xFF1E293B),
    ),
    scaffoldBackgroundColor: midnightBg,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: midnightSurface,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: midnightBg,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: midnightTextPrimary,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: midnightBg,
      selectedIconTheme: const IconThemeData(color: midnightPrimary),
      unselectedIconTheme: IconThemeData(color: midnightTextSecondary),
      selectedLabelTextStyle: const TextStyle(
        color: midnightPrimary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: TextStyle(color: midnightTextSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: midnightBg,
      selectedItemColor: midnightPrimary,
      unselectedItemColor: midnightTextSecondary,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1E293B),
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      hintStyle: TextStyle(color: midnightTextSecondary),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: midnightSurface,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E293B),
      contentTextStyle: const TextStyle(color: midnightTextPrimary),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: midnightTextPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: midnightTextPrimary, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: midnightTextPrimary),
      bodyMedium: TextStyle(color: midnightTextSecondary),
    ),
  );

  static final ThemeData skyBlueTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _skyBluePrimary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD0E8F9),
      onPrimaryContainer: const Color(0xFF0A3A6B),
      secondary: _skyBlueAccent,
      onSecondary: Colors.white,
      tertiary: const Color(0xFF5BA3E0),
      surface: const Color(0xFFF0F7FC),
      onSurface: const Color(0xFF1A2B3D),
      onSurfaceVariant: const Color(0xFF546E84),
      outline: const Color(0xFFB8D4EA),
      surfaceContainerHighest: const Color(0xFFDCEDF8),
      surfaceContainerHigh: const Color(0xFFE4F1FA),
      surfaceContainer: const Color(0xFFEAF4FC),
      surfaceContainerLow: const Color(0xFFF0F7FC),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5FAFF),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shadowColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Color(0xFFE8F4FD),
      foregroundColor: Color(0xFF1A2B3D),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFE8F4FD),
      indicatorColor: const Color(0xFFD0E8F9),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFE8F4FD),
      selectedItemColor: Color(0xFF2E7BC6),
      unselectedItemColor: Color(0xFF8BADC4),
    ),
    dividerColor: const Color(0xFFB8D4EA),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: const Color(0xFFE4F1FA),
      selectedColor: const Color(0xFFD0E8F9),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  /// Get theme by name string
  static ThemeData getThemeByName(String name) {
    switch (name) {
      case 'light':
        return lightTheme;
      case 'dark':
        return darkTheme;
      case 'skyBlue':
        return skyBlueTheme;
      default:
        return darkTheme;
    }
  }

  /// Check if a theme name represents a dark theme
  static bool isDarkTheme(String name) {
    return name == 'dark';
  }
}
