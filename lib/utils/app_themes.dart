import 'package:flutter/material.dart';
import 'dart:io';

// Smooth fade-through for all platform-default MaterialPageRoute pushes.
final _androidFadeThrough = PageTransitionsTheme(
  builders: {
    if (Platform.isAndroid)
      TargetPlatform.android: _FadeThroughPageTransitionsBuilder(),
  },
);

/// ─────────────────────────────────────────────────────────────────────────────
/// C4TV Design Tokens
/// Brand green is derived directly from the logo icon (#2EBD6B / #30A95E).
/// All four themes share the same structural tokens; only hue/surface differ.
/// ─────────────────────────────────────────────────────────────────────────────
class AppThemes {
  // ── Brand green (from logo) ────────────────────────────────────────────
  static const Color brandGreen        = Color(0xFF2EBD6B);
  static const Color brandGreenDark    = Color(0xFF1F9A54); // hover / pressed
  static const Color brandGreenLight   = Color(0xFFB6EDD0); // container / highlight

  // ── Dark theme surfaces (Midnight) ────────────────────────────────────
  static const Color midnightBg        = Color(0xFF0D1117);
  static const Color midnightSurface   = Color(0xFF161B22);
  static const Color midnightSurface2  = Color(0xFF21262D);
  static const Color midnightOutline   = Color(0xFF30363D);
  static const Color midnightText      = Color(0xFFE6EDF3);
  static const Color midnightTextMuted = Color(0xFF8B949E);

  // ── Sky-Blue palette ──────────────────────────────────────────────────
  static const Color skyPrimary   = Color(0xFF4A90D9);
  static const Color skyAccent    = Color(0xFF2E7BC6);

  // ── Crimson palette ───────────────────────────────────────────────────
  static const Color crimsonPrimary  = Color(0xFFA50000);
  static const Color crimsonAccent   = Color(0xFFD32F2F);
  static const Color crimsonBg       = Color(0xFF0D0000);
  static const Color crimsonSurface  = Color(0xFF1A0000);
  static const Color crimsonSurface2 = Color(0xFF2A0505);
  static const Color crimsonText     = Color(0xFFF5E6E6);
  static const Color crimsonMuted    = Color(0xFFBB8C8C);

  // ════════════════════════════════════════════════════════════════════════
  // DARK theme  (default — Midnight + Brand Green)
  // ════════════════════════════════════════════════════════════════════════
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'DMSans',
    pageTransitionsTheme: _androidFadeThrough,
    colorScheme: ColorScheme.dark(
      primary:                brandGreen,
      onPrimary:              Colors.white,
      primaryContainer:       brandGreen.withValues(alpha: 0.18),
      onPrimaryContainer:     brandGreenLight,
      secondary:              brandGreenDark,
      onSecondary:            Colors.white,
      surface:                midnightSurface,
      onSurface:              midnightText,
      onSurfaceVariant:       midnightTextMuted,
      outline:                midnightOutline,
      surfaceContainerHighest: midnightSurface2,
      surfaceContainerHigh:   const Color(0xFF1C2128),
      surfaceContainer:       const Color(0xFF181C22),
    ),
    scaffoldBackgroundColor: midnightBg,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: midnightBg,
      titleTextStyle: const TextStyle(
        fontFamily: 'DMSans',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: midnightText,
      ),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: midnightSurface,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: midnightBg,
      selectedIconTheme: const IconThemeData(color: brandGreen),
      unselectedIconTheme: const IconThemeData(color: midnightTextMuted),
      selectedLabelTextStyle: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: const TextStyle(color: midnightTextMuted),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: midnightBg,
      selectedItemColor: brandGreen,
      unselectedItemColor: midnightTextMuted,
    ),
    dividerTheme: const DividerThemeData(color: midnightOutline, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: midnightSurface2,
      hintStyle: const TextStyle(color: midnightTextMuted),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: midnightSurface,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: midnightSurface2,
      contentTextStyle: const TextStyle(color: midnightText),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: midnightSurface2,
      selectedColor: brandGreen.withValues(alpha: 0.25),
      labelStyle: const TextStyle(color: midnightText),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(color: midnightText, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: midnightText, fontWeight: FontWeight.bold),
      headlineSmall:  TextStyle(color: midnightText, fontWeight: FontWeight.w600),
      titleLarge:     TextStyle(color: midnightText, fontWeight: FontWeight.w600),
      titleMedium:    TextStyle(color: midnightText),
      bodyLarge:      TextStyle(color: midnightText),
      bodyMedium:     TextStyle(color: midnightTextMuted),
      labelSmall:     TextStyle(color: midnightTextMuted, fontSize: 11),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: brandGreen),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? brandGreen : midnightTextMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? brandGreen.withValues(alpha: 0.4)
            : midnightOutline,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: brandGreen,
      foregroundColor: Colors.white,
    ),
  );

  // ════════════════════════════════════════════════════════════════════════
  // LIGHT theme
  // ════════════════════════════════════════════════════════════════════════
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'DMSans',
    pageTransitionsTheme: _androidFadeThrough,
    colorScheme: ColorScheme.light(
      primary:             brandGreen,
      onPrimary:           Colors.white,
      primaryContainer:    brandGreenLight,
      onPrimaryContainer:  const Color(0xFF004D27),
      secondary:           brandGreenDark,
      onSecondary:         Colors.white,
      surface:             const Color(0xFFF5F5F5),
      onSurface:           const Color(0xFF1C1C1C),
      onSurfaceVariant:    const Color(0xFF5F5F5F),
      outline:             const Color(0xFFD0D0D0),
      surfaceContainerHighest: const Color(0xFFE8E8E8),
    ),
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: brandGreen),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: brandGreen,
      foregroundColor: Colors.white,
    ),
  );

  // ════════════════════════════════════════════════════════════════════════
  // SKY-BLUE theme
  // ════════════════════════════════════════════════════════════════════════
  static final ThemeData skyBlueTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'DMSans',
    pageTransitionsTheme: _androidFadeThrough,
    colorScheme: ColorScheme.light(
      primary:             skyPrimary,
      onPrimary:           Colors.white,
      primaryContainer:    const Color(0xFFD0E8F9),
      onPrimaryContainer:  const Color(0xFF0A3A6B),
      secondary:           skyAccent,
      onSecondary:         Colors.white,
      surface:             const Color(0xFFF0F7FC),
      onSurface:           const Color(0xFF1A2B3D),
      onSurfaceVariant:    const Color(0xFF546E84),
      outline:             const Color(0xFFB8D4EA),
      surfaceContainerHighest: const Color(0xFFDCEDF8),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5FAFF),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Color(0xFFE8F4FD),
      foregroundColor: Color(0xFF1A2B3D),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shadowColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
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

  // ════════════════════════════════════════════════════════════════════════
  // CRIMSON theme
  // ════════════════════════════════════════════════════════════════════════
  static final ThemeData crimsonTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'DMSans',
    pageTransitionsTheme: _androidFadeThrough,
    colorScheme: ColorScheme.dark(
      primary:             crimsonPrimary,
      onPrimary:           Colors.white,
      primaryContainer:    crimsonPrimary.withValues(alpha: 0.25),
      onPrimaryContainer:  const Color(0xFFFFCDD2),
      secondary:           crimsonAccent,
      onSecondary:         Colors.white,
      surface:             crimsonSurface,
      onSurface:           crimsonText,
      onSurfaceVariant:    crimsonMuted,
      outline:             const Color(0xFF4A1515),
      surfaceContainerHighest: crimsonSurface2,
      surfaceContainerHigh:    const Color(0xFF220808),
      surfaceContainer:        const Color(0xFF1E0404),
      error:               const Color(0xFFFF6B6B),
      onError:             Colors.black,
    ),
    scaffoldBackgroundColor: crimsonBg,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: crimsonBg,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: crimsonText,
      ),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: crimsonSurface,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: crimsonBg,
      selectedIconTheme: const IconThemeData(color: crimsonPrimary),
      unselectedIconTheme: const IconThemeData(color: crimsonMuted),
      selectedLabelTextStyle: const TextStyle(color: crimsonPrimary, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: const TextStyle(color: crimsonMuted),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: crimsonBg,
      selectedItemColor: crimsonPrimary,
      unselectedItemColor: crimsonMuted,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: crimsonBg,
      indicatorColor: crimsonPrimary.withValues(alpha: 0.2),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A0A0A), thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: crimsonSurface2,
      hintStyle: const TextStyle(color: crimsonMuted),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: crimsonSurface,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: crimsonSurface2,
      contentTextStyle: const TextStyle(color: crimsonText),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: crimsonSurface2,
      selectedColor: crimsonPrimary.withValues(alpha: 0.3),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(color: crimsonText, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: crimsonText, fontWeight: FontWeight.bold),
      headlineSmall:  TextStyle(color: crimsonText, fontWeight: FontWeight.w600),
      titleLarge:     TextStyle(color: crimsonText, fontWeight: FontWeight.w600),
      titleMedium:    TextStyle(color: crimsonText),
      bodyLarge:      TextStyle(color: crimsonText),
      bodyMedium:     TextStyle(color: crimsonMuted),
      labelSmall:     TextStyle(color: crimsonMuted, fontSize: 11),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: crimsonPrimary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? crimsonPrimary : crimsonMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? crimsonPrimary.withValues(alpha: 0.4)
            : const Color(0xFF4A1515),
      ),
    ),
  );

  static ThemeData getThemeByName(String name) {
    switch (name) {
      case 'light':   return lightTheme;
      case 'dark':    return darkTheme;
      case 'skyBlue': return skyBlueTheme;
      case 'crimson': return crimsonTheme;
      default:        return darkTheme;
    }
  }

  static bool isDarkTheme(String name) => name == 'dark' || name == 'crimson';
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
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    );
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
