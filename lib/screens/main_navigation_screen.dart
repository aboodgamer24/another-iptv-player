import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/content_type.dart';
import '../controllers/xtream_code_home_controller.dart';
import '../l10n/localization_extension.dart';
import '../utils/platform_utils.dart';
import 'main_shell_screen.dart';
import 'common/c4_dashboard.dart';
import 'common/c4_live_grid_screen.dart';
import 'common/c4_content_grid_screen.dart';
import '../widgets/common/c4_search_modal.dart';
import 'm3u/m3u_home_screen.dart';
import 'watch_later_screen.dart';
import 'desktop/desktop_favorites_screen.dart';
import 'xtream-codes/xtream_code_playlist_settings_screen.dart';

// Mobile Imports
import 'mobile/mobile_shell_screen.dart';
import 'mobile/mobile_home_screen.dart';
import 'mobile/mobile_live_tv_screen.dart';
import 'mobile/mobile_content_screen.dart';
import 'mobile/mobile_favorites_screen.dart';
import 'mobile/mobile_watch_later_screen.dart';
import 'mobile/mobile_global_search_screen.dart';

// TV Imports
import 'tv/tv_shell_screen.dart';
import 'tv/tv_home_screen.dart';
import 'tv/tv_live_tv_screen.dart';
import 'tv/tv_movies_screen.dart';
import 'tv/tv_series_screen.dart';
import 'tv/tv_search_screen.dart';
import 'tv/tv_favorites_screen.dart';
import 'tv/tv_watch_later_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final Playlist playlist;

  const MainNavigationScreen({super.key, required this.playlist});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0}; // Home loads immediately

  String _getTitle(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return context.loc.live_streams;
      case 2:
        return context.loc.movies;
      case 3:
        return context.loc.series_plural;
      case 4:
        return context.loc.favorites;
      case 5:
        return context.loc.rail_watch_later;
      case 6:
        return context.loc.settings;
      case 7:
        return 'Favorites';
      case 8:
        return 'Watch Later';
      default:
        return 'Another IPTV Player';
    }
  }

  Widget _buildContent() {
    final isXtream = widget.playlist.type == PlaylistType.xtream;

    if (isXtream) {
      final controller = Provider.of<XtreamCodeHomeController>(context);

      if (PlatformUtils.isTV) {
        if (!_loadedTabs.contains(_selectedIndex) || controller.isLoading) {
          return const _TvLoadingSkeleton();
        }

        switch (_selectedIndex) {
          case 0:
            return TvHomeScreen(playlistId: widget.playlist.id);
          case 1:
            return const TvLiveTvScreen();
          case 2:
            return const TvMoviesScreen();
          case 3:
            return const TvSeriesScreen();
          case 4:
            return const TvSearchScreen();
          case 5:
            return XtreamCodePlaylistSettingsScreen(playlist: widget.playlist);
          case 6:
            return const TvFavoritesScreen();
          case 7:
            return const TvWatchLaterScreen();
          default:
            return const SizedBox.shrink();
        }
      }

      if (PlatformUtils.isMobile) {
        switch (_selectedIndex) {
          case 0:
            return MobileHomeScreen(playlistId: widget.playlist.id);
          case 1:
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return MobileLiveTvScreen(
              categories: controller.liveCategories ?? [],
              title: context.loc.live_streams,
            );
          case 2:
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return MobileContentScreen(
              categories: controller.movieCategories,
              contentType: ContentType.vod,
              title: context.loc.movies,
            );
          case 3:
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return MobileContentScreen(
              categories: controller.seriesCategories,
              contentType: ContentType.series,
              title: context.loc.series_plural,
            );
          default:
            return const SizedBox.shrink();
        }
      } else {
        // Desktop Content
        switch (_selectedIndex) {
          case 0:
            return C4Dashboard(playlistId: widget.playlist.id);
          case 1:
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const C4LiveGridScreen();
          case 2:
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const C4ContentGridScreen(contentType: ContentType.vod);
          case 3:
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const C4ContentGridScreen(contentType: ContentType.series);
          case 4:
            return const DesktopFavoritesScreen();
          case 5:
            return const WatchLaterScreen();
          case 6:
            return XtreamCodePlaylistSettingsScreen(playlist: widget.playlist);
          default:
            return const SizedBox.shrink();
        }
      }
    } else {
      // M3U implementation (simplified for now)
      return M3UHomeScreen(playlist: widget.playlist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (PlatformUtils.isTV) {
      return TvShellScreen(
        selectedIndex: _selectedIndex,
        onItemSelected: (i) => setState(() {
          _selectedIndex = i;
          _loadedTabs.add(i);
        }),
        items: const [
          TvNavItem(icon: Icons.home_rounded, label: 'Home'),
          TvNavItem(icon: Icons.live_tv_rounded, label: 'Live TV'),
          TvNavItem(icon: Icons.movie_rounded, label: 'Movies'),
          TvNavItem(icon: Icons.tv_rounded, label: 'Series'),
          TvNavItem(icon: Icons.search_rounded, label: 'Search'),
          TvNavItem(icon: Icons.settings_rounded, label: 'Settings'),
          TvNavItem(icon: Icons.favorite_rounded, label: 'Favorites'),
          TvNavItem(icon: Icons.watch_later_rounded, label: 'Watch Later'),
        ],
        child: content,
      );
    }

    if (PlatformUtils.isMobile) {
      return MobileShellScreen(
        currentTitle: _getTitle(context),
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        onSearchTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileGlobalSearchScreen()),
          );
        },
        onFavoritesTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(context.loc.favorites),
                centerTitle: true,
              ),
              body: const MobileFavoritesScreen(),
            ),
          ),
        ),
        onWatchLaterTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(context.loc.rail_watch_later),
                centerTitle: true,
              ),
              body: const MobileWatchLaterScreen(),
            ),
          ),
        ),
        onSettingsTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                XtreamCodePlaylistSettingsScreen(playlist: widget.playlist),
          ),
        ),
        child: content,
      );
    }

    return MainShellScreen(
      currentTitle: _getTitle(context),
      selectedIndex: _selectedIndex,
      onItemSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      onSearchTap: () => C4SearchModal.show(context),
      child: content,
    );
  }
}

class _TvLoadingSkeleton extends StatefulWidget {
  const _TvLoadingSkeleton();
  @override
  State<_TvLoadingSkeleton> createState() => _TvLoadingSkeletonState();
}

class _TvLoadingSkeletonState extends State<_TvLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.3 + (_anim.value * 0.4);
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero skeleton
              Opacity(
                opacity: opacity,
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Row label skeleton
              Opacity(
                opacity: opacity,
                child: Container(
                  width: 160,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Card row skeleton
              Row(
                children: List.generate(5, (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 4 ? 12 : 0),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                )),
              ),
            ],
          ),
        );
      },
    );
  }
}
