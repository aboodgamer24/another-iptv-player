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

class _C4LiveGridScreenState extends State<C4LiveGridScreen> with AutomaticKeepAliveClientMixin {
  double _sidebarWidth = 200.0;
  static const double _minSidebarWidth = 140.0;
  static const double _maxSidebarWidth = 350.0;
  int _selectedCategoryIndex = 0;
  ContentItem? _selectedChannel;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
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
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              context.loc.live_streams.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedCategoryIndex == index;
                return _CategoryTile(
                  title: categories[index].category.categoryName,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  (f) => f.streamId == channel.id && f.contentType == channel.contentType,
                );

                return Container(
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: isSelected ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)) : null,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedChannel = channel),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                ? Image.network(channel.imageUrl, fit: BoxFit.contain)
                                : const Icon(Icons.live_tv_rounded, size: 24, color: Colors.white24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              channel.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFavorited ? Colors.redAccent : theme.hintColor,
                              size: 20,
                            ),
                            onPressed: () => favoritesController.toggleFavorite(channel),
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
    final favoritesController = context.watch<FavoritesController>();

    if (controller.liveCategories == null || controller.liveCategories!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = controller.liveCategories!;
    final selectedCategory = categories[_selectedCategoryIndex];
    final channels = selectedCategory.contentItems;

    final filteredChannels = channels
        .where((c) => c.name.toLowerCase().contains(_searchQuery))
        .toList();

    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenNotifier,
      builder: (context, isFullscreen, _) {
        return LayoutBuilder(
          builder: (context, outerConstraints) {
            final double rightPanelWidth = 320.0;
            final totalW = outerConstraints.maxWidth;
            final playerAvailableWidth =
                (totalW - _sidebarWidth - rightPanelWidth).clamp(0.0, double.infinity);
            final playerHeight = playerAvailableWidth * 9.0 / 16.0;

            return Stack(
              children: [
                // Layer 0: background layout panels (no PlayerWidget)
                if (!isFullscreen) ...[
                  // 1. Categories Sidebar (Left, resizable)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _sidebarWidth,
                    child: _buildCategorySidebar(theme, controller, categories),
                  ),

                  // 2. Center Column: ONLY the player placeholder (16:9)
                  Positioned(
                    left: _sidebarWidth,
                    right: rightPanelWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: const ColoredBox(color: Colors.black),
                            ),
                          ),
                          // No channel list here anymore
                        ],
                      ),
                    ),
                  ),

                  // 3. Right Panel: channel list instead of info panel
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: rightPanelWidth,
                    child: _buildSearchAndChannelList(
                      theme,
                      favoritesController,
                      filteredChannels,
                    ),
                  ),

                  // Splitter for resizing sidebar
                  Positioned(
                    left: _sidebarWidth - 4,
                    top: 0,
                    bottom: 0,
                    width: 8,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _sidebarWidth = (_sidebarWidth + details.delta.dx)
                                .clamp(_minSidebarWidth, _maxSidebarWidth);
                          });
                        },
                      ),
                    ),
                  ),
                ],

                // Layer 1: PlayerWidget — parent is ALWAYS Positioned
                // We use left/right/bottom instead of width/height so Flutter stretches the render box.
                // This prevents media_kit_video from detecting a constraints change that restarts the stream.
                Positioned(
                  left: isFullscreen ? 0 : _sidebarWidth,
                  top: 0,
                  right: isFullscreen ? 0 : rightPanelWidth,
                  bottom: isFullscreen ? 0 : null,
                  height: isFullscreen ? null : playerHeight,
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
                        ),
                ),
              ],
            );
          },
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
      child: Focus(
        onFocusChange: (focused) {
          if (focused) onTap();
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : (focused ? theme.colorScheme.surface : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : (focused ? theme.colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent),
                  ),
                ),
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected || focused ? Colors.white : theme.hintColor,
                    fontWeight: isSelected || focused ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
