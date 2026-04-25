import 'package:flutter/material.dart';
import 'dart:io';

// Smooth fade-through for all platform-default MaterialPageRoute pushes.
// Only applied to Android; other platforms keep their native feel.
final _androidFadeThrough = PageTransitionsTheme(
  builders: {
    if (Platform.isAndroid)
      TargetPlatform.android: _FadeThroughPageTransitionsBuilder(),
    // Windows/macOS/Linux keep their default (no entry = system default)
  },
);

class AppThemes {
  // Refined teal accent color
  static const Color _primaryDark = Color(0xFF00BFA5);

  // Sky Blue palette
  static const Color _skyBluePrimary = Color(0xFF4A90D9);
  static const Color _skyBlueAccent = Color(0xFF2E7BC6);

  // Crimson palette
  static const Color _crimsonPrimary = Color(0xFFA50000);
  static const Color _crimsonAccent = Color(0xFFD32F2F);
  static const Color _crimsonBg = Color(0xFF0D0000);
  static const Color _crimsonSurface = Color(0xFF1A0000);
  static const Color _crimsonSurface2 = Color(0xFF2A0505);
  static const Color _crimsonText = Color(0xFFF5E6E6);
  static const Color _crimsonTextMuted = Color(0xFFBB8C8C);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _androidFadeThrough,
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
    pageTransitionsTheme: _androidFadeThrough,
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
      headlineLarge: TextStyle(
        color: midnightTextPrimary,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: midnightTextPrimary,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(color: midnightTextPrimary),
      bodyMedium: TextStyle(color: midnightTextSecondary),
    ),
  );

  static final ThemeData skyBlueTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    pageTransitionsTheme: _androidFadeThrough,
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

  static final ThemeData crimsonTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'DMSans',
    pageTransitionsTheme: _androidFadeThrough,
    colorScheme: ColorScheme.dark(
      primary: _crimsonPrimary,
      onPrimary: Colors.white,
      primaryContainer: _crimsonPrimary.withValues(alpha: 0.25),
      onPrimaryContainer: const Color(0xFFFFCDD2),
      secondary: _crimsonAccent,
      onSecondary: Colors.white,
      surface: _crimsonSurface,
      onSurface: _crimsonText,
      onSurfaceVariant: _crimsonTextMuted,
      outline: const Color(0xFF4A1515),
      surfaceContainerHighest: _crimsonSurface2,
      surfaceContainerHigh: const Color(0xFF220808),
      surfaceContainer: const Color(0xFF1E0404),
      error: const Color(0xFFFF6B6B),
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: _crimsonBg,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: _crimsonSurface,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: _crimsonBg,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: _crimsonText,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: _crimsonBg,
      selectedIconTheme: const IconThemeData(color: _crimsonPrimary),
      unselectedIconTheme: IconThemeData(color: _crimsonTextMuted),
      selectedLabelTextStyle: const TextStyle(
        color: _crimsonPrimary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: TextStyle(color: _crimsonTextMuted),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _crimsonBg,
      selectedItemColor: _crimsonPrimary,
      unselectedItemColor: _crimsonTextMuted,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _crimsonBg,
      indicatorColor: _crimsonPrimary.withValues(alpha: 0.2),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A0A0A),
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: _crimsonSurface2,
      hintStyle: TextStyle(color: _crimsonTextMuted),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: _crimsonSurface,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _crimsonSurface2,
      contentTextStyle: const TextStyle(color: _crimsonText),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: _crimsonSurface2,
      selectedColor: _crimsonPrimary.withValues(alpha: 0.3),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: _crimsonText,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: _crimsonText,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(color: _crimsonText),
      bodyMedium: TextStyle(color: _crimsonTextMuted),
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
      case 'crimson':
        return crimsonTheme;
      default:
        return darkTheme;
    }
  }

  /// Check if a theme name represents a dark theme
  static bool isDarkTheme(String name) {
    return name == 'dark' || name == 'crimson';
  }
}

class _FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Incoming: fade + tiny scale up (1.0 → 1.0 with no distortion)
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    );
    // Outgoing: fade out slightly
    final fadeOut = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInCubic),
      ),
    );
    return FadeTransition(
      opacity: fadeOut,
      child: FadeTransition(opacity: fadeIn, child: child),
    );
  }
}
