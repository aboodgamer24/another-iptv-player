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

class MainNavigationScreen extends StatefulWidget {
  final Playlist playlist;

  const MainNavigationScreen({super.key, required this.playlist});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

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
      default:
        return 'Another IPTV Player';
    }
  }

  Widget _buildContent() {
    final isXtream = widget.playlist.type == PlaylistType.xtream;
    
    if (isXtream) {
      final controller = Provider.of<XtreamCodeHomeController>(context);

      if (PlatformUtils.isMobile) {
        switch (_selectedIndex) {
          case 0:
            return MobileHomeScreen(playlistId: widget.playlist.id);
          case 1:
            if (controller.isLoading) return const Center(child: CircularProgressIndicator());
            return MobileLiveTvScreen(
              categories: controller.liveCategories ?? [],
              title: context.loc.live_streams,
            );
          case 2:
            if (controller.isLoading) return const Center(child: CircularProgressIndicator());
            return MobileContentScreen(
              categories: controller.movieCategories,
              contentType: ContentType.vod,
              title: context.loc.movies,
            );
          case 3:
            if (controller.isLoading) return const Center(child: CircularProgressIndicator());
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
            if (controller.isLoading) return const Center(child: CircularProgressIndicator());
            return const C4LiveGridScreen();
          case 2:
            if (controller.isLoading) return const Center(child: CircularProgressIndicator());
            return const C4ContentGridScreen(contentType: ContentType.vod);
          case 3:
            if (controller.isLoading) return const Center(child: CircularProgressIndicator());
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
            builder: (_) => XtreamCodePlaylistSettingsScreen(
              playlist: widget.playlist,
            ),
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


