import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../l10n/localization_extension.dart';
import '../../models/category_view_model.dart';
import '../../models/playlist_content_model.dart';
import '../../services/fullscreen_notifier.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../widgets/player_widget.dart';

class C4LiveGridScreen extends StatefulWidget {
  const C4LiveGridScreen({super.key});

  @override
  State<C4LiveGridScreen> createState() => _C4LiveGridScreenState();
}

class _C4LiveGridScreenState extends State<C4LiveGridScreen>
    with AutomaticKeepAliveClientMixin {
  double _sidebarWidth = 200.0;
  static const double _minSidebarWidth = 140.0;
  static const double _maxSidebarWidth = 350.0;

  double _channelListWidth = 300.0;
  static const double _minChannelListWidth = 200.0;
  static const double _maxChannelListWidth = 500.0;

  int _selectedCategoryIndex = 0;
  ContentItem? _selectedChannel;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categorySearchController =
      TextEditingController();
  String _categorySearchQuery = '';
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() =>
          _searchQuery = _searchController.text.toLowerCase().trim());
    });
    _categorySearchController.addListener(() {
      setState(() =>
          _categorySearchQuery =
              _categorySearchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    // Wrap in addPostFrameCallback to avoid 'tree locked' error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      windowManager.setFullScreen(false);
      fullscreenNotifier.value = false;
    });
    _searchController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    final entering = !fullscreenNotifier.value;
    fullscreenNotifier.value = entering;
    if (entering) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      windowManager.setFullScreen(true);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      windowManager.setFullScreen(false);
    }
  }

  List<ContentItem> get _currentCategoryChannels {
    final controller = context.read<XtreamCodeHomeController>();
    final categories = controller.liveCategories!;
    return categories[_selectedCategoryIndex].contentItems;
  }

  Widget _buildIdlePlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Select a channel to start watching',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySidebar(
    ThemeData theme,
    XtreamCodeHomeController controller,
    List<CategoryViewModel> categories,
  ) {
    final filtered = _categorySearchQuery.isEmpty
        ? categories
        : categories
            .where((c) => c.category.categoryName
                .toLowerCase()
                .contains(_categorySearchQuery))
            .toList();

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              context.loc.live_streams.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          // Search bar for categories
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _categorySearchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search categories...',
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor),
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 18),
                suffixIcon:
                    _categorySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 16),
                            onPressed: () =>
                                _categorySearchController.clear(),
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    theme.colorScheme.surface.withValues(alpha: 0.6),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No categories found',
                      style: TextStyle(
                          fontSize: 12, color: theme.hintColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      // Map back to original index for selection
                      final origIndex = _categorySearchQuery.isEmpty
                          ? index
                          : categories.indexOf(filtered[index]);
                      final isSelected =
                          _selectedCategoryIndex == origIndex;
                      return _CategoryTile(
                        title: filtered[index]
                            .category
                            .categoryName,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = origIndex;
                            _selectedChannel = null;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

// ignore: unused_element
  Widget _buildSearchAndChannelList(
    ThemeData theme,
    FavoritesController favoritesController,
    List<ContentItem> filteredChannels,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search channels...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filteredChannels.length,
              itemBuilder: (context, index) {
                final channel = filteredChannels[index];
                final isSelected = _selectedChannel?.id == channel.id;
                final isFavorited = favoritesController.favorites.any(
                  (f) =>
                      f.streamId == channel.id &&
                      f.contentType == channel.contentType,
                );

                return Container(
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: isSelected
                        ? Border(
                            left: BorderSide(
                                color: theme.colorScheme.primary, width: 3))
                        : null,
                  ),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedChannel = channel),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: theme.colorScheme.surface,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: channel.imageUrl.isNotEmpty
                                ? Image.network(channel.imageUrl,
                                    fit: BoxFit.contain)
                                : const Icon(Icons.live_tv_rounded,
                                    size: 24, color: Colors.white24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              channel.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isFavorited
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorited
                                  ? Colors.redAccent
                                  : theme.hintColor,
                              size: 20,
                            ),
                            onPressed: () =>
                                favoritesController.toggleFavorite(channel),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// ignore: unused_element
  Widget _buildInfoPanel(
      ThemeData theme, FavoritesController favoritesController) {
    if (_selectedChannel == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_off_rounded,
                size: 48,
                color: theme.hintColor.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No channel selected',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedChannel!.imageUrl.isNotEmpty
                  ? Image.network(_selectedChannel!.imageUrl,
                      fit: BoxFit.contain)
                  : const Icon(Icons.live_tv_rounded,
                      size: 64, color: Colors.white10),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _selectedChannel!.name,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  navigateByContentType(context, _selectedChannel!),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Watch Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  favoritesController.toggleFavorite(_selectedChannel!),
              icon: Icon(
                favoritesController.favorites.any(
                        (f) => f.streamId == _selectedChannel!.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 18,
              ),
              label: Text(
                favoritesController.favorites.any(
                        (f) => f.streamId == _selectedChannel!.id)
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: favoritesController.favorites
                        .any((f) => f.streamId == _selectedChannel!.id)
                    ? Colors.redAccent
                    : Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 20),
                side: BorderSide(
                  color: favoritesController.favorites.any(
                          (f) => f.streamId == _selectedChannel!.id)
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : theme.dividerColor,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'NEXT PROGRAM',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 16),
          Text('No program info available.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildInlineChannelList(
    ThemeData theme,
    FavoritesController favoritesController,
  ) {
    final channels = _currentCategoryChannels;
    final filtered = _searchQuery.isEmpty
        ? channels
        : channels
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery))
            .toList();

    int selectedIndex = -1;
    if (_selectedChannel != null) {
      selectedIndex =
          filtered.indexWhere((c) => c.id == _selectedChannel!.id);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          left: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                bottom: BorderSide(
                    color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.live_tv_rounded,
                    size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedIndex >= 0
                        ? 'Channels  ${selectedIndex + 1}/${filtered.length}'
                        : 'Channels  ${filtered.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search channels...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: Colors.grey.shade500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: Colors.grey.shade500),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey.shade800, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey.shade800, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: theme.colorScheme.primary, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade900,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
          // Channel list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No channels found',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final channel = filtered[index];
                      final isSelected =
                          _selectedChannel?.id == channel.id;
                      final isFavorited =
                          favoritesController.favorites.any(
                        (f) =>
                            f.streamId == channel.id &&
                            f.contentType == channel.contentType,
                      );

                      return InkWell(
                        onTap: () => setState(
                            () => _selectedChannel = channel),
                        child: Container(
                          height: 56,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.5),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade900,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: channel.imageUrl.isNotEmpty
                                      ? Image.network(
                                          channel.imageUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.live_tv,
                                            size: 18,
                                            color: Colors.white24,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.live_tv,
                                          size: 18,
                                          color: Colors.white24,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    channel.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                ),
                                // Favorite button
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: Icon(
                                    isFavorited
                                        ? Icons.favorite_rounded
                                        : Icons
                                            .favorite_border_rounded,
                                    color: isFavorited
                                        ? Colors.redAccent
                                        : Colors.grey.shade600,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      favoritesController
                                          .toggleFavorite(channel),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color:
                                        theme.colorScheme.primary,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final controller = context.watch<XtreamCodeHomeController>();

    if (controller.liveCategories == null ||
        controller.liveCategories!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = controller.liveCategories!;




    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenNotifier,
      builder: (context, isFullscreen, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Row(
            children: [
              // ── LEFT: Resizable categories sidebar ──────────────
              if (!isFullscreen) ...[
                SizedBox(
                  width: _sidebarWidth,
                  child: _buildCategorySidebar(
                      theme, controller, categories),
                ),

                // Sidebar splitter
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (d) {
                      setState(() {
                        _sidebarWidth =
                            (_sidebarWidth + d.delta.dx)
                                .clamp(_minSidebarWidth,
                                    _maxSidebarWidth);
                      });
                    },
                    child: Container(
                      width: 8,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],

              // ── CENTER+RIGHT: Player + channel list splitter ─────
              Expanded(
                child: Row(
                  children: [
                    // Video area — idle placeholder until a channel is picked
                    Expanded(
                      child: _selectedChannel == null
                          ? _buildIdlePlaceholder()
                          : PlayerWidget(
                              key: ValueKey(_selectedChannel!.id),
                              contentItem: _selectedChannel!,
                              showControls: true,
                              showInfo: false,
                              onFullscreen: _toggleFullscreen,
                              queue: _currentCategoryChannels,
                              isInline: true,
                              showPersistentSidebar: false,
                            ),
                    ),

                    // Channel list — always visible (hidden only in fullscreen)
                    if (!isFullscreen) ...[
                      // Splitter
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (d) {
                            setState(() {
                              _channelListWidth =
                                  (_channelListWidth - d.delta.dx).clamp(
                                    _minChannelListWidth,
                                    _maxChannelListWidth,
                                  );
                            });
                          },
                          child: Container(
                            width: 8,
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: _channelListWidth,
                        child: _buildInlineChannelList(
                          theme,
                          context.watch<FavoritesController>(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected ? Colors.white : theme.hintColor,
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
