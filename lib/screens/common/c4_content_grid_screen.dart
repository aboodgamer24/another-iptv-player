import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/favorites_controller.dart';
import '../../controllers/watch_later_controller.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../widgets/common/c4_card.dart';
import '../../l10n/localization_extension.dart';
import '../../models/playlist_content_model.dart';
import '../../models/category_view_model.dart';
import '../../models/content_type.dart';
import '../../utils/navigate_by_content_type.dart';

class C4ContentGridScreen extends StatefulWidget {
  final ContentType contentType;

  const C4ContentGridScreen({super.key, required this.contentType});

  @override
  State<C4ContentGridScreen> createState() => _C4ContentGridScreenState();
}

class _C4ContentGridScreenState extends State<C4ContentGridScreen> {
  int _selectedCategoryIndex = 0;
  ContentItem? _focusedItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<XtreamCodeHomeController>();
    
    final List<CategoryViewModel> categories = widget.contentType == ContentType.vod 
        ? controller.movieCategories 
        : controller.seriesCategories;

    if (categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedCategory = categories[_selectedCategoryIndex];
    final items = selectedCategory.contentItems;

    return Row(
      children: [
        // 1. Categories Sidebar (Left)
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  context.loc.categories,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
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
                      onTap: () => setState(() => _selectedCategoryIndex = index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 2. Grid (Middle)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCategory.category.categoryName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(context),
                      childAspectRatio: 2 / 3, // Poster aspect ratio
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final favoritesController = context.watch<FavoritesController>();
                      final watchLaterController = context.watch<WatchLaterController>();

                      return C4Card(
                        title: item.name,
                        imageUrl: item.imageUrl,
                        isFavorite: favoritesController.favorites.any(
                          (f) => f.streamId == item.id && f.contentType == item.contentType,
                        ),
                        onToggleFavorite: () => favoritesController.toggleFavorite(item),
                        isInWatchLater: watchLaterController.watchLaterItems.any(
                          (w) => w.streamId == item.id && w.contentType == item.contentType,
                        ),
                        onToggleWatchLater: () => watchLaterController.toggleWatchLater(item),
                        onFocusChanged: (focused) {
                          if (focused) setState(() => _focusedItem = item);
                        },
                        onTap: () {
                           navigateByContentType(context, item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Info Panel (Right)
        if (_focusedItem != null)
          Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              border: Border(left: BorderSide(color: theme.dividerColor, width: 0.5)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black,
                        image: DecorationImage(
                          image: NetworkImage(_focusedItem!.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _focusedItem!.name,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (widget.contentType == ContentType.vod && _focusedItem!.vodStream != null) ...[
                     _buildRatingRow(theme, _focusedItem!.vodStream!.rating),
                    const SizedBox(height: 16),
                  ],
                  if (widget.contentType == ContentType.series && _focusedItem!.seriesStream != null) ...[
                     _buildRatingRow(theme, _focusedItem!.seriesStream!.rating ?? ''),
                    const SizedBox(height: 16),
                  ],
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    context.loc.description,
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPlotText(),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingRow(ThemeData theme, String rating) {
    if (rating.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _getPlotText() {
    if (_focusedItem == null) return '';
    if (widget.contentType == ContentType.vod) {
      return 'Movie Plot not available in grid view.';
    } else {
      return _focusedItem!.seriesStream?.plot ?? 'Series Plot not available.';
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    // Sidebar(200) + InfoPanel(320 if active) + Padding(48)
    double infoPanelWidth = _focusedItem != null ? 320 : 0;
    double availableWidth = width - 200 - infoPanelWidth - 48;

    if (availableWidth > 1400) return 6;
    if (availableWidth > 1100) return 5;
    if (availableWidth > 800) return 4;
    if (availableWidth > 500) return 3;
    return 2;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                      ? theme.colorScheme.primary.withOpacity(0.15) 
                      : (focused ? theme.colorScheme.surface : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected || focused ? Colors.white : theme.hintColor,
                    fontWeight: isSelected || focused ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
