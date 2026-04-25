import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../database/database.dart';
import '../repositories/user_preferences.dart';
import '../services/service_locator.dart';
import '../services/sync_service.dart';
import '../services/playlist_service.dart';

class AppLifecycleSync extends StatefulWidget {
  final Widget child;
  const AppLifecycleSync({super.key, required this.child});

  @override
  State<AppLifecycleSync> createState() => _AppLifecycleSyncState();
}

class _AppLifecycleSyncState extends State<AppLifecycleSync>
    with WidgetsBindingObserver {
  _WindowCloseListener? _windowListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      _windowListener = _WindowCloseListener(onClose: _backgroundPush);
      windowManager.addListener(_windowListener!);
    }
  }

  @override
  void dispose() {
    if (_windowListener != null) {
      windowManager.removeListener(_windowListener!);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Push when app goes to background or is about to terminate
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundPush();
    }
  }

  Future<void> _backgroundPush() async {
    if (!SyncService.instance.isLoggedIn) return;
    debugPrint(
      '[AppLifecycleSync] App going background/closing — pushing data',
    );
    try {
      final db = getIt<AppDatabase>();
      final playlists = await PlaylistService.getPlaylists();
      final favorites = await db.getAllFavorites();
      final watchLaterItems = await db.getAllWatchLater();
      final watchHistories = await db.getAllWatchHistories();
      final settings = await UserPreferences.buildSettingsSnapshot();

      await SyncService.instance.pushAll({
        'playlists': playlists.map((p) => p.toJson()).toList(),
        'favorites': favorites
            .map(
              (f) => {
                'id': f.id,
                'playlistId': f.playlistId,
                'contentType': f.contentType.toString(),
                'streamId': f.streamId,
                'episodeId': f.episodeId,
                'name': f.name,
                'imagePath': f.imagePath,
                'sortOrder': f.sortOrder,
              },
            )
            .toList(),
        'watch_later': watchLaterItems
            .map(
              (w) => {
                'id': w.id,
                'playlistId': w.playlistId,
                'contentType': w.contentType.toString(),
                'streamId': w.streamId,
                'title': w.title,
                'imagePath': w.imagePath,
              },
            )
            .toList(),
        'continue_watching': watchHistories
            .map(
              (w) => {
                'playlistId': w.playlistId,
                'contentType': w.contentType.toString(),
                'streamId': w.streamId,
                'seriesId': w.seriesId,
                'watchDuration': w.watchDuration,
                'totalDuration': w.totalDuration,
                'lastWatched': w.lastWatched.toIso8601String(),
                'imagePath': w.imagePath,
                'title': w.title,
              },
            )
            .toList(),
        'settings': settings,
      });
      debugPrint('[AppLifecycleSync] Background push complete');
    } catch (e) {
      debugPrint('[AppLifecycleSync] Background push failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WindowCloseListener extends WindowListener {
  final Future<void> Function() onClose;
  _WindowCloseListener({required this.onClose});

  @override
  void onWindowClose() async {
    await onClose();
  }
}
