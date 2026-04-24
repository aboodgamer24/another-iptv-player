import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/xtream_code_home_controller.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/screens/desktop/desktop_content_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_live_tv_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_home_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_global_search_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_favorites_screen.dart';
import 'package:another_iptv_player/widgets/desktop/desktop_sidebar.dart';
import '../../models/content_type.dart';
import '../mobile/mobile_shell_screen.dart';
import '../mobile/mobile_home_screen.dart';
import '../mobile/mobile_live_tv_screen.dart';
import '../mobile/mobile_content_screen.dart';
import '../mobile/mobile_favorites_screen.dart';
import '../mobile/mobile_watch_later_screen.dart';
import '../mobile/mobile_global_search_screen.dart';
import 'xtream_code_playlist_settings_screen.dart';
import '../../utils/app_transitions.dart';

class XtreamCodeHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const XtreamCodeHomeScreen({super.key, required this.playlist});

  @override
  State<XtreamCodeHomeScreen> createState() => _XtreamCodeHomeScreenState();
}

class _XtreamCodeHomeScreenState extends State<XtreamCodeHomeScreen> {
  static const double _desktopBreakpoint = 900.0;

  int _desktopIndex = 0;
  int _mobileIndex = 0; // 0=Home, 1=Live, 2=Movies, 3=Series

  late final PageController _mobilePageController;
  List<Widget>? _desktopPages;

  @override
  void initState() {
    super.initState();
    _mobilePageController = PageController(initialPage: _mobileIndex);
  }

  @override
  void dispose() {
    _mobilePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<XtreamCodeHomeController>(
      builder: (context, controller, child) =>
          _buildMainContent(context, controller),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    XtreamCodeHomeController controller,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktopLayout(context, controller, constraints);
        }
        return _buildMobileLayout(context, controller);
      },
    );
  }

  // ========================
  // MOBILE LAYOUT
  // ========================

  Widget _buildMobileLayout(
    BuildContext context,
    XtreamCodeHomeController controller,
  ) {
    // Titles for the 4 bottom-nav tabs only
    final titles = [
      context.loc.history,       // 0 - Home (or whatever the home tab loc key is)
      context.loc.live,          // 1 - Live
      context.loc.movies,        // 2 - Movies
      context.loc.series_plural, // 3 - Series
    ];
    final currentTitle = titles[_mobileIndex.clamp(0, titles.length - 1)];
    final showSearch = _mobileIndex == 1 || _mobileIndex == 2 || _mobileIndex == 3;

    return MobileShellScreen(
      selectedIndex: _mobileIndex,
      onItemSelected: (index) {
        setState(() => _mobileIndex = index);
        _mobilePageController.jumpToPage(index);
      },
      currentTitle: currentTitle,
      onSearchTap: showSearch
          ? () => Navigator.push(
                context,
                slideUpRoute(builder: (_) => const MobileGlobalSearchScreen()),
              )
          : null,

      // Favorites → pushed as a full screen route
      onFavoritesTap: () => Navigator.push(
        context,
        slideUpRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(context.loc.favorites),
              centerTitle: true,
            ),
            body: const MobileFavoritesScreen(),
          ),
        ),
      ),

      // Watch Later → pushed as a full screen route
      onWatchLaterTap: () => Navigator.push(
        context,
        slideUpRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(context.loc.rail_watch_later),
              centerTitle: true,
            ),
            body: const MobileWatchLaterScreen(),
          ),
        ),
      ),

      // Settings → pushed as a full screen route
      onSettingsTap: () => Navigator.push(
        context,
        slideUpRoute(
          builder: (_) => XtreamCodePlaylistSettingsScreen(
            playlist: widget.playlist,
          ),
        ),
      ),

      // PageView now only has 4 children matching the 4 bottom-nav tabs
      child: PageView(
        controller: _mobilePageController,
        physics: Platform.isAndroid
            ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
            : const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          // Sync the bottom NavigationBar when user swipes
          setState(() => _mobileIndex = index);
        },
        children: [
          // 0 - Home
          _KeepAlivePage(child: MobileHomeScreen(playlistId: widget.playlist.id)),
          // 1 - Live TV
          _KeepAlivePage(
            child: MobileLiveTvScreen(
              categories: controller.liveCategories ?? [],
              title: context.loc.live_streams,
            ),
          ),
          // 2 - Movies
          _KeepAlivePage(
            child: MobileContentScreen(
              key: ValueKey('mobile_movies_${controller.movieCategories.length}'),
              categories: controller.movieCategories,
              contentType: ContentType.vod,
              title: context.loc.movies,
            ),
          ),
          // 3 - Series
          _KeepAlivePage(
            child: MobileContentScreen(
              key: ValueKey('mobile_series_${controller.seriesCategories.length}'),
              categories: controller.seriesCategories,
              contentType: ContentType.series,
              title: context.loc.series_plural,
            ),
          ),
        ],
      ),
    );
  }


  // ========================
  // DESKTOP LAYOUT (sidebar-driven)
  // ========================

  Widget _buildDesktopLayout(
    BuildContext context,
    XtreamCodeHomeController controller,
    BoxConstraints constraints,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Row(
        children: [
          // Left sidebar
          DesktopSidebar(
            selectedIndex: _desktopIndex,
            onIndexChanged: (index) {
              setState(() => _desktopIndex = index);
            },
            playlistName: widget.playlist.name,
          ),
          // Main content area
          Expanded(child: _buildDesktopPageView(controller)),
        ],
      ),
    );
  }

  Widget _buildDesktopPageView(XtreamCodeHomeController controller) {
    _desktopPages ??= _buildDesktopPages(controller);
    return IndexedStack(
      index: _desktopIndex,
      children: _desktopPages!,
    );
  }

  List<Widget> _buildDesktopPages(XtreamCodeHomeController controller) {
    return [
      // 0 - Home
      DesktopHomeScreen(
        key: ValueKey('desktop_home_$_desktopIndex'),
        playlistId: widget.playlist.id,
      ),
      // 1 - Live TV
      DesktopLiveTvScreen(
        categories: controller.liveCategories!,
        title: context.loc.live_streams,
      ),
      // 2 - Movies
      DesktopContentScreen(
        categories: controller.movieCategories,
        contentType: ContentType.vod,
        title: context.loc.movies,
      ),
      // 3 - Series
      DesktopContentScreen(
        categories: controller.seriesCategories,
        contentType: ContentType.series,
        title: context.loc.series_plural,
      ),
      // 4 - Search
      const DesktopGlobalSearchScreen(),
      // 5 - Favorites
      const DesktopFavoritesScreen(),
      // 6 - Settings
      XtreamCodePlaylistSettingsScreen(playlist: widget.playlist),
    ];
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context); // required by mixin
    return widget.child;
  }
}
