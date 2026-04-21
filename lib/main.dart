import 'package:another_iptv_player/controllers/playlist_controller.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/watch_later_controller.dart';
import 'package:another_iptv_player/screens/app_initializer_screen.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'controllers/locale_provider.dart';
import 'controllers/theme_provider.dart';
import 'l10n/app_localizations.dart';
import 'l10n/supported_languages.dart';
import 'services/sync_service.dart';
import 'services/app_lifecycle_sync.dart';


import 'package:another_iptv_player/utils/app_config.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await SyncService.instance.init();
  
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

  await setupServiceLocator();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistController()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesController()),
        ChangeNotifierProvider(create: (_) => WatchLaterController()),
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

    return MaterialApp(
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
      // Use the named theme system — supports Light, Dark, and Sky Blue
      theme: themeProvider.currentThemeData,
      darkTheme: themeProvider.isDark ? themeProvider.currentThemeData : null,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: AppInitializerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
