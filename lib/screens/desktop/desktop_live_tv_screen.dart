import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/widgets/player_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:another_iptv_player/widgets/common/resizable_sidebar.dart';

class DesktopLiveTvScreen extends StatefulWidget {
  final List<CategoryViewModel> categories;
  final String title;

  const DesktopLiveTvScreen({
    super.key,
    required this.categories,
    required this.title,
  });

  @override
  State<DesktopLiveTvScreen> createState() => _DesktopLiveTvScreenState();
}

class _DesktopLiveTvScreenState extends State<DesktopLiveTvScreen> {
  int _selectedCategoryIndex = 0; // 0 = "All"
  String _searchQuery = '';
  ContentItem? _selectedContent;
  int? _hoveredCategoryIndex;
  int? _hoveredContentIndex;

  final ScrollController _listScrollController = ScrollController();
  final ScrollController _catScrollController = ScrollController();
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
    _listScrollController.dispose();
    _catScrollController.dispose();
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

  void _onChannelTap(ContentItem item) {
    setState(() {
      _selectedContent = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14), // Deep dark minimal background
      body: Row(
        children: [
          // Left Sidebar: Categories
          ResizableSidebar(
            initialWidth: 240,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D0F13),
                border: Border(
                  right: BorderSide(color: Color(0xFF1E2128), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.loc.categories,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF1E2128), height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: _catScrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: widget.categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildCategoryItem(
                            context,
                            label: context.loc.all,
                            isSelected: _selectedCategoryIndex == 0,
                            index: 0,
                          );
                        }
                        final cat = widget.categories[index - 1];
                        return _buildCategoryItem(
                          context,
                          label: cat.category.categoryName,
                          isSelected: _selectedCategoryIndex == index,
                          index: index,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Pane: Player (60%) + Details (40%)
                Expanded(
                  flex: 6,
                  child: Row(
                    children: [
                      // Player Area
                      Expanded(
                        flex: 6,
                        child: Container(
                          margin: const EdgeInsets.only(
                            top: 24,
                            left: 24,
                            right: 8,
                            bottom: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1E2128)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedContent != null
                              ? PlayerWidget(
                                  key: ValueKey(_selectedContent!.id),
                                  contentItem: _selectedContent!,
                                  queue: _displayItems,
                                )
                              : _buildEmptyPlayerPlaceholder(),
                        ),
                      ),
                      // Details Area
                      Expanded(
                        flex: 4,
                        child: Container(
                          margin: const EdgeInsets.only(
                            top: 24,
                            right: 24,
                            left: 8,
                            bottom: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13161C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1E2128)),
                          ),
                          child: _buildChannelDetails(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Pane: Full Width Channels List
                Expanded(
                  flex: 5,
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 24,
                      top: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13161C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2128)),
                    ),
                    child: Column(
                      children: [
                        // Search bar inside the channels list
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFF1E2128)),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: context.loc.search,
                              hintStyle: const TextStyle(
                                color: Color(0xFF747B8B),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF747B8B),
                                size: 20,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1A1D24),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isLoadingItems
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF5A45FF),
                                  ),
                                )
                              : _buildChannelList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlayerPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D24),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              size: 48,
              color: Color(0xFF747B8B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a channel to start watching',
            style: TextStyle(color: Color(0xFF747B8B), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelDetails() {
    if (_selectedContent == null) {
      return Center(
        child: Text(
          'No channel selected',
          style: TextStyle(color: Color(0xFF747B8B)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedContent!.imagePath.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _selectedContent!.imagePath,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, err) =>
                            const Icon(Icons.tv, color: Colors.white54),
                      )
                    : const Icon(Icons.tv, color: Colors.white54),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedContent!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A45FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF5A45FF).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF5A45FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1E2128)),
          const SizedBox(height: 16),
          // Placeholder for program info
          const Text(
            'NOW PLAYING',
            style: TextStyle(
              color: Color(0xFF747B8B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Program Information Not Available',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required int index,
  }) {
    final isHovered = _hoveredCategoryIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCategoryIndex = index),
      onExit: (_) => setState(() => _hoveredCategoryIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryIndex = index;
            // Scroll channel list to top
            if (_listScrollController.hasClients) {
              _listScrollController.jumpTo(0);
            }
          });
        },
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
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isHovered ? Colors.white : const Color(0xFFA0A5B5)),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelList() {
    final items = _displayItems;

    if (items.isEmpty) {
      return Center(
        child: Text(
          context.loc.not_found_in_category,
          style: const TextStyle(color: Color(0xFF747B8B)),
        ),
      );
    }

    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedContent?.id == item.id;
        final isHovered = _hoveredContentIndex == index;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredContentIndex = index),
          onExit: (_) => setState(() => _hoveredContentIndex = null),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _onChannelTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1A1D24)
                    : (isHovered
                          ? const Color(0xFF1A1D24).withValues(alpha: 0.5)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF323640)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0E14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.imagePath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imagePath,
                            fit: BoxFit.contain,
                            errorWidget: (context, url, err) => const Icon(
                              Icons.tv,
                              size: 16,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(Icons.tv, size: 16, color: Colors.white54),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFA0A5B5),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Place to put favorite heart if needed
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
