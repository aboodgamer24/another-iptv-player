import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/category_view_model.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class MobileLiveTvScreen extends StatefulWidget {
  final List<CategoryViewModel> categories;
  final String title;

  const MobileLiveTvScreen({
    super.key,
    required this.categories,
    required this.title,
  });

  @override
  State<MobileLiveTvScreen> createState() => _MobileLiveTvScreenState();
}

class _MobileLiveTvScreenState extends State<MobileLiveTvScreen> {
  int _selectedCategoryIndex = 0; // 0 = "All"
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<ContentItem> _allItems = [];

  @override
  void initState() {
    super.initState();
    _loadAllItems();
  }

  void _loadAllItems() {
    List<ContentItem> items = [];
    for (final cat in widget.categories) {
      items.addAll(cat.contentItems);
    }
    setState(() {
      _allItems = items;
    });
  }

  List<ContentItem> get _displayItems {
    List<ContentItem> items;
    if (_selectedCategoryIndex == 0) {
      items = _allItems;
    } else {
      items = widget.categories[_selectedCategoryIndex - 1].contentItems;
    }

    if (_searchQuery.isNotEmpty) {
      items = items
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: _buildCategoryDrawer(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _displayItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    cacheExtent: 500,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: _displayItems.length,
                    itemBuilder: (context, index) {
                      return _buildChannelListTile(_displayItems[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final selectedLabel = _selectedCategoryIndex == 0 ? context.loc.all : widget.categories[_selectedCategoryIndex - 1].category.categoryName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          // Categories button
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      selectedLabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Search field — takes remaining space
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: context.loc.search,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDrawer() {
    return Drawer(
      width: 260,
      backgroundColor: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                context.loc.categories,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Category list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.categories.length + 1, // +1 for "All"
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategoryIndex == index;
                  final label = index == 0 ? context.loc.all : widget.categories[index - 1].category.categoryName;
                  final count = index == 0 ? _allItems.length : widget.categories[index - 1].contentItems.length;

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedCategoryIndex = index);
                      Navigator.of(context).pop(); // close drawer
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)) : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: isSelected ? Theme.of(context).primaryColor : Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelListTile(ContentItem item) {
    return GestureDetector(
      onTap: () => navigateByContentType(context, item),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Channel logo
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.live_tv,
                      size: 28,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Channel name
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Play arrow indicator
              const Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white24,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            context.loc.not_found_in_category,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
