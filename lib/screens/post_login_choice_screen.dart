import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/playlist_controller.dart';
import '../repositories/user_preferences.dart';
import '../services/sync_applier.dart';
import '../models/playlist_model.dart';
import '../models/api_configuration_model.dart';
import '../repositories/iptv_repository.dart';
import '../services/app_state.dart';
import '../services/playlist_service.dart';
import 'main_navigation_screen_provider.dart';
import 'playlist_screen.dart';

class PostLoginChoiceScreen extends StatefulWidget {
  const PostLoginChoiceScreen({super.key});

  @override
  State<PostLoginChoiceScreen> createState() => _PostLoginChoiceScreenState();
}

class _PostLoginChoiceScreenState extends State<PostLoginChoiceScreen>
    with SingleTickerProviderStateMixin {
  String _displayName = 'there';
  bool _isRestoring = false;
  String _loadingMessage = 'Restoring your data...';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadUserName();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final user = await UserPreferences.getSyncUser();
    if (mounted && user['display_name'] != null) {
      setState(() => _displayName = user['display_name']);
    }
  }

  Future<void> _restoreFromCloud() async {
    setState(() {
      _isRestoring = true;
      _loadingMessage = 'Pulling data from server...';
    });

    // Step 1: Pull and apply sync data (playlists, favorites, settings)
    final success = await SyncApplier.pullAndApply();

    if (!mounted) return;

    if (!success) {
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync failed — check your server connection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Step 2: Refresh playlist controller
    setState(() => _loadingMessage = 'Loading playlists...');
    try {
      final playlistController = Provider.of<PlaylistController>(
        context,
        listen: false,
      );
      await playlistController.loadPlaylists(context);
    } catch (_) {}

    if (!mounted) return;

    // Step 3: Set up AppState exactly like AppInitializerScreen does
    setState(() => _loadingMessage = 'Setting up your account...');
    final lastPlaylistId = await UserPreferences.getLastPlaylist();
    Playlist? playlist;
    if (lastPlaylistId != null) {
      playlist = await PlaylistService.getPlaylistById(lastPlaylistId);
      if (playlist != null) {
        AppState.currentPlaylist = playlist;
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

    if (!mounted) return;

    // Step 4: If xtream playlist, pre-fetch all content NOW before navigating
    if (playlist != null && playlist.type == PlaylistType.xtream) {
      setState(() => _loadingMessage = 'Fetching your channels & content...');
      try {
        final repo = AppState.xtreamCodeRepository!;
        await Future.wait([
          repo
              .getLiveCategories(forceRefresh: true)
              .then((_) => repo.getLiveChannelsFromApi()),
          repo
              .getVodCategories(forceRefresh: true)
              .then((_) => repo.getMoviesFromApi()),
          repo
              .getSeriesCategories(forceRefresh: true)
              .then((_) => repo.getSeriesFromApi()),
        ]);
        debugPrint('[PostLoginChoice] Content pre-fetch complete');
      } catch (e) {
        debugPrint('[PostLoginChoice] Content pre-fetch error (non-fatal): $e');
        // Non-fatal — still navigate, controller will read from DB
      }
    }

    if (!mounted) return;

    setState(() => _loadingMessage = 'Almost done...');
    await Future.delayed(const Duration(milliseconds: 300)); // brief settle

    if (!mounted) return;

    // Step 5: Navigate — if playlist exists go directly to MainNavigationScreen
    // (skip AppInitializerScreen entirely since we already set up AppState)
    if (playlist != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainNavigationScreenProvider(playlist: playlist!),
        ),
      );
    } else {
      // No playlist found after restore — go to playlist setup
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlaylistScreen()),
      );
    }
  }

  void _startFresh() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PlaylistScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Full-screen loading overlay while restoring
    if (_isRestoring) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withValues(alpha: 0.95),
                colorScheme.primary.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3.0,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loadingMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a minute on large playlists',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Normal choice screen (unchanged layout)
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withValues(alpha: 0.95),
                colorScheme.primary.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Welcome icon ──
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 40,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Welcome text ──
                      Text(
                        'Welcome back, $_displayName!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'What would you like to do?',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      _buildChoiceCard(
                        colorScheme: colorScheme,
                        icon: Icons.cloud_download_outlined,
                        title: 'Restore My Data',
                        subtitle:
                            'Pull your playlists, favorites, and settings from your account',
                        isLoading:
                            false, // loading is handled by full-screen overlay now
                        onTap: _restoreFromCloud,
                      ),
                      const SizedBox(height: 16),
                      _buildChoiceCard(
                        colorScheme: colorScheme,
                        icon: Icons.add_circle_outline,
                        title: 'Add a New Playlist',
                        subtitle: 'Set up a new playlist and start watching',
                        isLoading: false,
                        onTap: _startFresh,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onTap == null && !isLoading ? 0.5 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3.0,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Restoring your data...',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Icon
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(icon, size: 40, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
