import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/content_type.dart';

/// Desktop 2-panel layout used for Live TV, Movies, and Series tabs.
/// Left panel: category sidebar. Right panel: content grid with search.
class DesktopContentScreen extends StatefulWidget {
  final List<CategoryViewModel> categories;
  final ContentType contentType;
  final String title;

  const DesktopContentScreen({
    super.key,
    required this.categories,
    required this.contentType,
    required this.title,
  });

  @override
  State<DesktopContentScreen> createState() => _DesktopContentScreenState();
}

class _DesktopContentScreenState extends State<DesktopContentScreen> {
  double _sidebarWidth = 240.0;
  static const double _minSidebarWidth = 140.0;
  static const double _maxSidebarWidth = 420.0;

  int _selectedCategoryIndex = 0; // 0 = "All"
  String _searchQuery = '';
  int? _hoveredCategoryIndex;
  final ScrollController _gridScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<ContentItem> _allItems = [];
  bool _isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    _loadAllItems();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllItems() async {
    setState(() => _isLoadingItems = true);

    List<ContentItem> items = [];
    for (final cat in widget.categories) {
      for (final item in cat.contentItems) {
        items.add(item);
      }
    }

    setState(() {
      _allItems = items;
      _isLoadingItems = false;
    });
  }

  List<ContentItem> get _displayItems {
    List<ContentItem> items;
    if (_selectedCategoryIndex == 0) {
      items = _allItems;
    } else {
      final cat = widget.categories[_selectedCategoryIndex - 1];
      items = cat.contentItems;
    }

    if (_searchQuery.isNotEmpty) {
      items = items
          .where(
            (item) =>
                item.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Row(
        children: [
          SizedBox(width: _sidebarWidth, child: _buildCategorySidebar(context)),

          // Draggable vertical splitter
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(
                    _minSidebarWidth,
                    _maxSidebarWidth,
                  );
                });
              },
              child: SizedBox(
                width: 8,
                child: Center(
                  child: Container(width: 1, color: const Color(0xFF1E2128)),
                ),
              ),
            ),
          ),

          Expanded(child: _buildContentArea(context)),
        ],
      ),
    );
  }

  // ========================
  // CATEGORY SIDEBAR (Left Panel)
  // ========================

  Widget _buildCategorySidebar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F13),
        border: Border(right: BorderSide(color: Color(0xFF1E2128), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E2128)),

          // Category list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: widget.categories.length + 1, // +1 for "All"
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildCategoryItem(
                    context,
                    icon: Icons.grid_view_rounded,
                    label: context.loc.all,
                    count: _allItems.length,
                    isSelected: _selectedCategoryIndex == 0,
                    isHovered: _hoveredCategoryIndex == 0,
                    onTap: () => setState(() {
                      _selectedCategoryIndex = 0;
                      _scrollToTop();
                    }),
                    onHover: (hovering) => setState(
                      () => _hoveredCategoryIndex = hovering ? 0 : null,
                    ),
                  );
                }

                final cat = widget.categories[index - 1];
                return _buildCategoryItem(
                  context,
                  label: cat.category.categoryName,
                  count: cat.contentItems.length,
                  isSelected: _selectedCategoryIndex == index,
                  isHovered: _hoveredCategoryIndex == index,
                  onTap: () => setState(() {
                    _selectedCategoryIndex = index;
                    _scrollToTop();
                  }),
                  onHover: (hovering) => setState(
                    () => _hoveredCategoryIndex = hovering ? index : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    IconData? icon,
    required String label,
    required int count,
    required bool isSelected,
    required bool isHovered,
    required VoidCallback onTap,
    required ValueChanged<bool> onHover,
  }) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2C52FF).withValues(alpha: 0.15)
                : (isHovered ? const Color(0xFF1E2128) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2C52FF).withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFFA0A5B5),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFFA0A5B5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2C52FF).withValues(alpha: 0.5)
                      : const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF262A35)),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF747B8B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================
  // CONTENT AREA (Right Panel)
  // ========================

  Widget _buildContentArea(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: _getSearchHint(context),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFF13161C),
              hintStyle: const TextStyle(color: Color(0xFF747B8B)),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // Content grid
        Expanded(
          child: _isLoadingItems
              ? const Center(child: CircularProgressIndicator())
              : _displayItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.loc.not_found_in_category,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildContentGrid(context),
        ),
      ],
    );
  }

  Widget _buildContentGrid(BuildContext context) {
    final items = _displayItems;
    final crossAxisCount = ResponsiveHelper.getCrossAxisCount(context);

    return Scrollbar(
      controller: _gridScrollController,
      interactive: true,
      child: GridView.builder(
        controller: _gridScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _DesktopContentCard(
            item: item,
            onTap: () => navigateByContentType(context, item),
          );
        },
      ),
    );
  }

  String _getSearchHint(BuildContext context) {
    switch (widget.contentType) {
      case ContentType.liveStream:
        return context.loc.search_live_stream;
      case ContentType.vod:
        return context.loc.search_movie;
      case ContentType.series:
        return context.loc.search_series;
    }
  }

  void _scrollToTop() {
    if (_gridScrollController.hasClients) {
      _gridScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}

// ========================
// DESKTOP CONTENT CARD (with hover effects)
// ========================

class _DesktopContentCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onTap;

  const _DesktopContentCard({required this.item, required this.onTap});

  @override
  State<_DesktopContentCard> createState() => _DesktopContentCardState();
}

class _DesktopContentCardState extends State<_DesktopContentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF13161C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2128)),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2C52FF).withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.item.imagePath.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.item.imagePath,
                                fit:
                                    widget.item.contentType ==
                                        ContentType.liveStream
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF0F1115),
                                  child: const Center(
                                    child: Icon(
                                      Icons.movie,
                                      size: 32,
                                      color: Color(0xFF262A35),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    _buildFallbackCard(context),
                              )
                            : _buildFallbackCard(context),

                        // Hover overlay
                        if (_isHovered)
                          Container(
                            color: Colors.black.withValues(alpha: 0.4),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5A45FF),
                                      Color(0xFF00D1FF),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Title
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF13161C),
                    child: Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCard(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1115),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getContentIcon(), size: 32, color: const Color(0xFF262A35)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.item.name,
                style: const TextStyle(fontSize: 10, color: Color(0xFF747B8B)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getContentIcon() {
    switch (widget.item.contentType) {
      case ContentType.liveStream:
        return Icons.live_tv_rounded;
      case ContentType.vod:
        return Icons.movie_rounded;
      case ContentType.series:
        return Icons.tv_rounded;
    }
  }
}
