import 'package:c4tv_player/controllers/playlist_controller.dart';
import 'package:c4tv_player/controllers/favorites_controller.dart';
import 'package:c4tv_player/controllers/watch_later_controller.dart';
import 'package:c4tv_player/controllers/home_rails_controller.dart';
import 'package:c4tv_player/screens/app_initializer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'controllers/locale_provider.dart';
import 'controllers/theme_provider.dart';
import 'l10n/app_localizations.dart';
import 'l10n/supported_languages.dart';
import 'services/app_lifecycle_sync.dart';

import 'package:window_manager/window_manager.dart';
import 'dart:io';

import 'package:c4tv_player/utils/platform_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only do truly synchronous/fast setup here
  await PlatformUtils.detectTV();

  // Desktop window setup (platform-gated, fast)
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Run app immediately — splash shows while heavy init runs
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistController()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesController()),
        ChangeNotifierProvider(create: (_) => WatchLaterController()),
        ChangeNotifierProvider(create: (_) => HomeRailsController()),
      ],
      child: const AppLifecycleSyncWrapper(),
    ),
  );
}

class AppLifecycleSyncWrapper extends StatelessWidget {
  const AppLifecycleSyncWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return const AppLifecycleSync(child: MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: MaterialApp(
        locale: localeProvider.locale,
        supportedLocales: supportedLanguages
            .map((lang) => Locale(lang['code']))
            .toList(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        title: 'Another IPTV Player',
        theme: themeProvider.currentThemeData,
        darkTheme: themeProvider.isDark ? themeProvider.currentThemeData : null,
        themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
        debugShowCheckedModeBanner: false,
        // Wire D-pad arrow keys → directional focus movement
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.arrowUp):
              const DirectionalFocusIntent(TraversalDirection.up),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const DirectionalFocusIntent(TraversalDirection.down),
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              const DirectionalFocusIntent(TraversalDirection.left),
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              const DirectionalFocusIntent(TraversalDirection.right),
        },
        // CRITICAL: actions map must exist to actually handle the intents above
        actions: {
          ...WidgetsApp.defaultActions,
        },
        // Wrap the home inside a Builder so FocusTraversalGroup is
        // inside MaterialApp's own FocusScope, not outside it
        home: KeyboardListener(
          focusNode: FocusNode(skipTraversal: true),
          autofocus: true,
          onKeyEvent: (e) {
            if (e is KeyDownEvent) {
              debugPrint('[GlobalKey] Key pressed: ${e.logicalKey.debugName}');
            }
          },
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: const AppInitializerScreen(),
          ),
        ),
      ),
    );
  }
}
