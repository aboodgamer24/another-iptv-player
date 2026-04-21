import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/screens/playlist_screen.dart';

import 'package:another_iptv_player/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import '../../repositories/user_preferences.dart';
import '../../services/app_state.dart';
import '../../services/playlist_service.dart';
import '../../services/sync_service.dart';
import '../../services/sync_applier.dart';
import 'package:another_iptv_player/screens/main_navigation_screen.dart';

class AppInitializerScreen extends StatefulWidget {
  const AppInitializerScreen({super.key});

  @override
  State<AppInitializerScreen> createState() => _AppInitializerScreenState();
}

class _AppInitializerScreenState extends State<AppInitializerScreen> {
  bool _isLoading = true;
  bool _showWelcome = false;
  Playlist? _lastPlaylist;
  String _syncMessage = '';


  @override
  void initState() {
    super.initState();
    _loadLastPlaylist();
  }

  Future<void> _loadLastPlaylist() async {
    // Check if first launch (never logged in AND never skipped as guest)
    final hasSeenWelcome = await UserPreferences.getHasSeenWelcome();
    final isLoggedIn = SyncService.instance.isLoggedIn;

    if (!hasSeenWelcome && !isLoggedIn) {
      setState(() {
        _showWelcome = true;
        _isLoading = false;
      });
      return;
    }

    // Auto-pull from server if logged in
    if (SyncService.instance.isLoggedIn) {
      setState(() => _syncMessage = 'Syncing with server…');
      try {
        await SyncApplier.pullAndApply();
        debugPrint('[AppInitializer] Auto-pull complete');
      } catch (e) {
        debugPrint('[AppInitializer] Auto-pull failed (continuing): $e');
        // Non-fatal — continue with local data
      }
      setState(() => _syncMessage = '');
    }

    final lastPlaylistId = await UserPreferences.getLastPlaylist();


    if (lastPlaylistId != null) {
      final playlist = await PlaylistService.getPlaylistById(lastPlaylistId);
      if (playlist != null) {
        AppState.currentPlaylist = playlist;
        _lastPlaylist = playlist;

        if (playlist.type == PlaylistType.xtream) {
          AppState.xtreamCodeRepository = IptvRepository(
            ApiConfig(
              baseUrl: playlist.url!,
              username: playlist.username!,
              password: playlist.password!,
            ),
            playlist.id,
          );
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) return const WelcomeScreen();

    if (_isLoading) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_syncMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  _syncMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }


    if (_lastPlaylist == null) {
      return const PlaylistScreen();
    } else {
      return MainNavigationScreen(playlist: _lastPlaylist!);
    }
  }
}
