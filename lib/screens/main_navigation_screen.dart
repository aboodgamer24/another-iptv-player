import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/content_type.dart';
import '../controllers/xtream_code_home_controller.dart';
import '../controllers/m3u_home_controller.dart';
import '../controllers/watch_history_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/watch_later_controller.dart';
import '../controllers/home_rails_controller.dart';
import '../l10n/localization_extension.dart';
import '../services/app_state.dart';
import 'main_shell_screen.dart';
import 'common/c4_dashboard.dart';
import 'common/c4_live_grid_screen.dart';
import 'common/c4_content_grid_screen.dart';
import '../widgets/common/c4_search_modal.dart';
import 'm3u/m3u_home_screen.dart';
import 'watch_history_screen.dart';
import 'watch_later_screen.dart';
import 'desktop/desktop_favorites_screen.dart';
import 'xtream-codes/xtream_code_playlist_settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final Playlist playlist;

  const MainNavigationScreen({super.key, required this.playlist});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late dynamic _controller; // Can be XtreamCodeHomeController or M3UHomeController

  @override
  void initState() {
    super.initState();
    if (widget.playlist.type == PlaylistType.xtream) {
      _controller = AppState.preloadedController ?? XtreamCodeHomeController(false);
      AppState.preloadedController = null;
    } else {
      _controller = M3UHomeController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        return context.loc.watch_later;
      case 6:
        return context.loc.settings;
      default:
        return 'Another IPTV Player';
    }
  }

  Widget _buildContent() {
    if (widget.playlist.type == PlaylistType.xtream) {
      switch (_selectedIndex) {
        case 0:
          return C4Dashboard(playlistId: widget.playlist.id);
        case 1:
          return const C4LiveGridScreen();
        case 2:
          return const C4ContentGridScreen(contentType: ContentType.vod);
        case 3:
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
    } else {
      // M3U implementation (simplified for now)
      return M3UHomeScreen(playlist: widget.playlist);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScreen(
      currentTitle: _getTitle(context),
      selectedIndex: _selectedIndex,
      onItemSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      onSearchTap: () => C4SearchModal.show(context),
      child: MultiProvider(
        providers: [
          if (widget.playlist.type == PlaylistType.xtream)
            ChangeNotifierProvider<XtreamCodeHomeController>.value(
              value: _controller as XtreamCodeHomeController,
            )
          else
            ChangeNotifierProvider<M3UHomeController>.value(
              value: _controller as M3UHomeController,
            ),
          ChangeNotifierProvider(create: (_) => WatchHistoryController()),
          ChangeNotifierProvider(create: (_) => HomeRailsController()..load()),
        ],
        child: _buildContent(),
      ),
    );
  }
}
