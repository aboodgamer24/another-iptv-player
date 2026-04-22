import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/category_view_model.dart';
import '../../models/playlist_content_model.dart';
import '../../models/content_type.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class MobileContentScreen extends StatefulWidget {
  final List<CategoryViewModel> categories;
  final ContentType contentType;
  final String title;

  const MobileContentScreen({
    super.key,
    required this.categories,
    required this.contentType,
    required this.title,
  });

  @override
  State<MobileContentScreen> createState() => _MobileContentScreenState();
}

class _MobileContentScreenState extends State<MobileContentScreen> {
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

  @override
  void didUpdateWidget(MobileContentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentType != widget.contentType ||
        oldWidget.categories != widget.categories) {
      _selectedCategoryIndex = 0;
      _searchQuery = '';
      _searchController.clear();
      _loadAllItems();
    }
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
                : GridView.builder(
                    cacheExtent: 500,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.67,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _displayItems.length,
                    itemBuilder: (context, index) {
                      return _buildPosterCard(_displayItems[index]);
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
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: _getSearchHint(),
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

  String _getSearchHint() {
    switch (widget.contentType) {
      case ContentType.vod:
        return context.loc.search_movie;
      case ContentType.series:
        return context.loc.search_series;
      default:
        return context.loc.search;
    }
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
              child: Row(
                children: [
                  Icon(
                    widget.contentType == ContentType.vod ? Icons.movie_outlined : Icons.tv_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.loc.categories,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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

  Widget _buildPosterCard(ContentItem item) {
    return GestureDetector(
      onTap: () => navigateByContentType(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.movie, size: 48, color: Colors.white24),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter, size: 64, color: Colors.white24),
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
