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
import 'package:another_iptv_player/screens/main_navigation_screen_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLastPlaylist());
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
      final colorScheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.live_tv_rounded,
                      size: 48,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'C4-TV',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              if (_syncMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_syncMessage),
              ],
            ],
          ),
        ),
      );
    }

    if (_lastPlaylist == null) {
      return const PlaylistScreen();
    } else {
      return MainNavigationScreenProvider(playlist: _lastPlaylist!);
    }
  }
}
