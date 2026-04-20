import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/xtream_code_home_controller.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/screens/category_detail_screen.dart';
import 'package:another_iptv_player/screens/xtream-codes/xtream_code_playlist_settings_screen.dart';
import 'package:another_iptv_player/screens/watch_history_screen.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:another_iptv_player/widgets/category_section.dart';
import 'package:another_iptv_player/screens/desktop/desktop_content_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_live_tv_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_home_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_global_search_screen.dart';
import 'package:another_iptv_player/screens/desktop/desktop_favorites_screen.dart';
import 'package:another_iptv_player/widgets/desktop/desktop_sidebar.dart';
import '../../models/content_type.dart';

class XtreamCodeHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const XtreamCodeHomeScreen({super.key, required this.playlist});

  @override
  State<XtreamCodeHomeScreen> createState() => _XtreamCodeHomeScreenState();
}

class _XtreamCodeHomeScreenState extends State<XtreamCodeHomeScreen> {
  late XtreamCodeHomeController _controller;
  XtreamCodeHomeController get controller => _controller;
  static const double _desktopBreakpoint = 900.0;
  final ScrollController _scrollController = ScrollController();

  // Desktop sidebar uses indices 0-6:
  // 0=Home, 1=LiveTV, 2=Movies, 3=Series, 4=Search, 5=Favorites, 6=Settings
  int _desktopIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeController() {
    final repository = IptvRepository(
      ApiConfig(
        baseUrl: widget.playlist.url!,
        username: widget.playlist.username!,
        password: widget.playlist.password!,
      ),
      widget.playlist.id,
    );
    AppState.xtreamCodeRepository = repository;
    _controller = XtreamCodeHomeController(false);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<XtreamCodeHomeController>(
        builder: (context, controller, child) =>
            _buildMainContent(context, controller),
      ),
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
  // MOBILE LAYOUT (unchanged)
  // ========================

  Widget _buildMobileLayout(
    BuildContext context,
    XtreamCodeHomeController controller,
  ) {
    return Scaffold(
      body: _buildMobilePageView(controller),
      bottomNavigationBar: _buildBottomNavigationBar(context, controller),
    );
  }

  Widget _buildMobilePageView(XtreamCodeHomeController controller) {
    return IndexedStack(
      index: controller.currentIndex,
      children: _buildMobilePages(controller),
    );
  }

  List<Widget> _buildMobilePages(XtreamCodeHomeController controller) {
    return [
      WatchHistoryScreen(
        key: ValueKey('watch_history_${controller.currentIndex}'),
        playlistId: widget.playlist.id,
      ),
      _buildContentPage(
        controller.liveCategories!,
        ContentType.liveStream,
        controller,
      ),
      _buildContentPage(
        controller.movieCategories,
        ContentType.vod,
        controller,
      ),
      _buildContentPage(
        controller.seriesCategories,
        ContentType.series,
        controller,
      ),
      XtreamCodePlaylistSettingsScreen(playlist: widget.playlist),
    ];
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
          Expanded(
            child: _buildDesktopPageView(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPageView(XtreamCodeHomeController controller) {
    return IndexedStack(
      index: _desktopIndex,
      children: _buildDesktopPages(controller),
    );
  }

  List<Widget> _buildDesktopPages(XtreamCodeHomeController controller) {
    return [
      // 0 - Home
      DesktopHomeScreen(
        key: ValueKey('desktop_home_${_desktopIndex}'),
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

  // ========================
  // SHARED: Content page for MOBILE
  // ========================

  Widget _buildContentPage(
    List<CategoryViewModel> categories,
    ContentType contentType,
    XtreamCodeHomeController controller,
  ) {
    return Scaffold(
      appBar: _buildMobileAppBar(context, controller, contentType),
      body: _buildCategoryList(categories, contentType),
    );
  }

  AppBar _buildMobileAppBar(
    BuildContext context,
    XtreamCodeHomeController controller,
    ContentType contentType,
  ) {
    return AppBar(
      title: SelectableText(
        controller.getPageTitle(context),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _navigateToSearch(context, contentType),
        ),
      ],
    );
  }

  void _navigateToSearch(BuildContext context, ContentType contentType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(contentType: contentType),
      ),
    );
  }

  Widget _buildCategoryList(
    List<CategoryViewModel> categories,
    ContentType contentType,
  ) {
    return Scrollbar(
      controller: _scrollController,
      interactive: true,
      child: ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) =>
            _buildCategorySection(categories[index], contentType),
      ),
    );
  }

  Widget _buildCategorySection(
    CategoryViewModel category,
    ContentType contentType,
  ) {
    return CategorySection(
      category: category,
      cardWidth: ResponsiveHelper.getCardWidth(context),
      cardHeight: ResponsiveHelper.getCardHeight(context),
      onSeeAllTap: () => _navigateToCategoryDetail(category),
      onContentTap: (content) => navigateByContentType(context, content),
    );
  }

  void _navigateToCategoryDetail(CategoryViewModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(category: category),
      ),
    );
  }

  // ========================
  // MOBILE: Bottom Navigation
  // ========================

  BottomNavigationBar _buildBottomNavigationBar(
    BuildContext context,
    XtreamCodeHomeController controller,
  ) {
    return BottomNavigationBar(
      currentIndex: controller.currentIndex,
      onTap: controller.onNavigationTap,
      type: BottomNavigationBarType.fixed,
      items: _buildBottomNavigationItems(context),
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavigationItems(
    BuildContext context,
  ) {
    return _getMobileNavigationItems(context).map((item) {
      return BottomNavigationBarItem(icon: Icon(item.icon), label: item.label);
    }).toList();
  }

  // ========================
  // Navigation Items
  // ========================

  List<NavigationItem> _getMobileNavigationItems(BuildContext context) {
    return [
      NavigationItem(
        icon: Icons.home_rounded,
        label: context.loc.history,
        index: 0,
      ),
      NavigationItem(
        icon: Icons.live_tv_rounded,
        label: context.loc.live,
        index: 1,
      ),
      NavigationItem(
        icon: Icons.movie_rounded,
        label: context.loc.movie,
        index: 2,
      ),
      NavigationItem(
        icon: Icons.tv_rounded,
        label: context.loc.series_plural,
        index: 3,
      ),
      NavigationItem(
        icon: Icons.settings_rounded,
        label: context.loc.settings,
        index: 4,
      ),
    ];
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final int index;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
