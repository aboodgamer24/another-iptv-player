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
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryChips(),
        Expanded(
          child: _displayItems.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _displayItems.length,
                  itemBuilder: (context, index) {
                    return _buildChannelCard(_displayItems[index]);
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
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
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

  Widget _buildChannelCard(ContentItem item) {
    return GestureDetector(
      onTap: () => navigateByContentType(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(Icons.live_tv, size: 40, color: Colors.white24),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: Colors.black54,
                child: Text(
                  item.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
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
