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
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryChips(),
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
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

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        cacheExtent: 500,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: widget.categories.length + 1,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          final label = index == 0 ? context.loc.all : widget.categories[index - 1].category.categoryName;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategoryIndex = index);
                }
              },
              selectedColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey[900],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          );
        },
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
