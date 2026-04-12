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
import '../../models/content_type.dart';

class XtreamCodeHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const XtreamCodeHomeScreen({super.key, required this.playlist});

  @override
  State<XtreamCodeHomeScreen> createState() => _XtreamCodeHomeScreenState();
}

class _XtreamCodeHomeScreenState extends State<XtreamCodeHomeScreen> {
  late XtreamCodeHomeController _controller;
  static const double _desktopBreakpoint = 900.0;
  int? _hoveredIndex;
  final ScrollController _scrollController = ScrollController();

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
    if (controller.isLoading) {
      return _buildLoadingScreen(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktopLayout(context, controller, constraints);
        }
        return _buildMobileLayout(context, controller);
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.loc.loading_playlists),
          ],
        ),
      ),
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
  // DESKTOP LAYOUT (new sidebar + desktop screens)
  // ========================

  Widget _buildDesktopLayout(
    BuildContext context,
    XtreamCodeHomeController controller,
    BoxConstraints constraints,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Column(
        children: [
          _buildTopNavigationBar(context, controller),
          Expanded(child: _buildDesktopPageView(controller)),
        ],
      ),
    );
  }

  Widget _buildDesktopPageView(XtreamCodeHomeController controller) {
    return IndexedStack(
      index: controller.currentIndex,
      children: _buildDesktopPages(controller),
    );
  }

  List<Widget> _buildDesktopPages(XtreamCodeHomeController controller) {
    return [
      WatchHistoryScreen(
        key: ValueKey('watch_history_desktop_${controller.currentIndex}'),
        playlistId: widget.playlist.id,
      ),
      DesktopLiveTvScreen(
        categories: controller.liveCategories!,
        title: context.loc.live_streams,
      ),
      DesktopContentScreen(
        categories: controller.movieCategories,
        contentType: ContentType.vod,
        title: context.loc.movies,
      ),
      DesktopContentScreen(
        categories: controller.seriesCategories,
        contentType: ContentType.series,
        title: context.loc.series_plural,
      ),
      XtreamCodePlaylistSettingsScreen(playlist: widget.playlist),
    ];
  }

  // ========================
  // DESKTOP TOP BAR
  // ========================

  Widget _buildTopNavigationBar(
    BuildContext context,
    XtreamCodeHomeController controller,
  ) {
    final items = _getNavigationItems(context);

    // Filter main tabs: Live TV (1), Movies (2), Series (3)
    final mainTabs = items
        .where((i) => i.index == 1 || i.index == 2 || i.index == 3)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF13161C), // Deep dark minimal color
        border: Border(bottom: BorderSide(color: Color(0xFF1E2128), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Clock & Free Mode placeholder
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Color(0xFF747B8B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Desktop Player",
                    style: TextStyle(color: Color(0xFFA0A5B5), fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D24),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF262A35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.rocket_launch,
                          color: Color(0xFFE55D5D),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "FREE MODE",
                          style: TextStyle(
                            color: Color(0xFFE55D5D),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Center: Logo Z (Click to go Home/History)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => controller.onNavigationTap(0),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A45FF), Color(0xFF00D1FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Z",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Right: Profile and Settings
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF262A35)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.playlist.name ?? 'Playlist',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              "User Profile",
                              style: TextStyle(
                                color: Color(0xFF747B8B),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.person,
                          color: Color(0xFFA0A5B5),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Notifications
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1D24),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none,
                      color: Color(0xFFA0A5B5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => controller.onNavigationTap(4),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: controller.currentIndex == 4
                              ? const Color(0xFF2C52FF).withValues(alpha: 0.15)
                              : const Color(0xFF1A1D24),
                          shape: BoxShape.circle,
                          border: controller.currentIndex == 4
                              ? Border.all(
                                  color: const Color(
                                    0xFF2C52FF,
                                  ).withValues(alpha: 0.5),
                                )
                              : null,
                        ),
                        child: Icon(
                          Icons.settings,
                          color: controller.currentIndex == 4
                              ? Colors.white
                              : const Color(0xFFA0A5B5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Nav tabs (Live TV, Movies, Series)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: mainTabs
                .map((item) => _buildTopNavItem(context, item, controller))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavItem(
    BuildContext context,
    NavigationItem item,
    XtreamCodeHomeController controller,
  ) {
    final isSelected = controller.currentIndex == item.index;
    final isHovered = _hoveredIndex == item.index;

    final iconColor = isSelected
        ? Colors.white
        : (isHovered ? const Color(0xFFDCE0EA) : const Color(0xFF747B8B));
    final textColor = isSelected
        ? Colors.white
        : (isHovered ? const Color(0xFFDCE0EA) : const Color(0xFFA0A5B5));
    final bgColor = isSelected
        ? const Color(0xFF1A1D24)
        : (isHovered ? const Color(0xFF13161C) : Colors.transparent);
    final borderColor = isSelected
        ? const Color(0xFF262A35)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = item.index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => controller.onNavigationTap(item.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    return _getNavigationItems(context).map((item) {
      return BottomNavigationBarItem(icon: Icon(item.icon), label: item.label);
    }).toList();
  }

  // ========================
  // Navigation Items
  // ========================

  List<NavigationItem> _getNavigationItems(BuildContext context) {
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
