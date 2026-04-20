import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/watch_later_controller.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/widgets/common/c4_card.dart';
import 'package:provider/provider.dart';

class DesktopFavoritesScreen extends StatefulWidget {
  const DesktopFavoritesScreen({super.key});

  @override
  State<DesktopFavoritesScreen> createState() => _DesktopFavoritesScreenState();
}

class _DesktopFavoritesScreenState extends State<DesktopFavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Local mutable list for Live TV drag-and-drop order.
  // Initialized from controller on first build.
  List<Favorite>? _liveOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesController>().loadFavorites();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ContentItem _favToContentItem(Favorite f) =>
      ContentItem(f.streamId, f.name, f.imagePath ?? '', f.contentType);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favCtrl = context.watch<FavoritesController>();
    final watchLaterCtrl = context.watch<WatchLaterController>();

    if (favCtrl.isLoading && favCtrl.favorites.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final liveItems = favCtrl.favorites
        .where((f) => f.contentType == ContentType.liveStream)
        .toList();

    final movieItems = favCtrl.favorites
        .where((f) => f.contentType == ContentType.vod)
        .map(_favToContentItem)
        .toList();

    final seriesItems = favCtrl.favorites
        .where((f) => f.contentType == ContentType.series)
        .map(_favToContentItem)
        .toList();

    // Seed local live order on first load or when items change externally
    if (_liveOrder == null || _liveOrder!.length != liveItems.length) {
      _liveOrder = List.from(liveItems);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Tab Bar ────────────────────────────────────────────
          Container(
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: '${context.loc.live_tv} (${liveItems.length})'),
                Tab(text: '${context.loc.movies} (${movieItems.length})'),
                Tab(text: '${context.loc.series_plural} (${seriesItems.length})'),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.hintColor,
              indicatorColor: theme.colorScheme.primary,
            ),
          ),
          const Divider(height: 1),

          // ── Tab Views ──────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Live TV: drag-and-drop sortable list ─────────
                _liveOrder!.isEmpty
                    ? _buildEmpty(context.loc.no_favorites_found)
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        itemCount: _liveOrder!.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _liveOrder!.removeAt(oldIndex);
                            _liveOrder!.insert(newIndex, item);
                          });
                          // Persist new order to DB
                          final orderedIds = _liveOrder!.map((f) => f.id).toList();
                          context.read<FavoritesController>()
                              .reorderLiveFavorites(orderedIds);
                        },
                        itemBuilder: (context, index) {
                          final item = _liveOrder![index];
                          return ReorderableDragStartListener(
                            key: ValueKey(item.id),
                            index: index,
                            child: ListTile(
                              key: ValueKey('tile_${item.id}'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: (item.imagePath ?? '').isNotEmpty
                                    ? Image.network(
                                        item.imagePath!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.live_tv,
                                                size: 20,
                                                color: Colors.white24),
                                      )
                                    : const SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Icon(Icons.live_tv,
                                            size: 20,
                                            color: Colors.white24),
                                      ),
                              ),
                              title: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.favorite_rounded,
                                    color: Colors.redAccent, size: 20),
                                tooltip: 'Remove from favourites',
                                onPressed: () =>
                                    favCtrl.toggleFavorite(item.toContentItem()),
                              ),
                              onTap: () =>
                                  navigateByContentType(context, item.toContentItem()),
                            ),
                          );
                        },
                      ),

                // ── Movies: card grid ─────────────────────────────
                movieItems.isEmpty
                    ? _buildEmpty(context.loc.no_favorites_found)
                    : _buildCardGrid(
                        context, movieItems, favCtrl, watchLaterCtrl),

                // ── Series: card grid ─────────────────────────────
                seriesItems.isEmpty
                    ? _buildEmpty(context.loc.no_favorites_found)
                    : _buildCardGrid(
                        context, seriesItems, favCtrl, watchLaterCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid(
    BuildContext context,
    List<ContentItem> items,
    FavoritesController favCtrl,
    WatchLaterController watchLaterCtrl,
  ) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 1100
          ? 6
          : constraints.maxWidth > 800
              ? 5
              : constraints.maxWidth > 600
                  ? 4
                  : constraints.maxWidth > 400
                      ? 3
                      : 2;
      return GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return C4Card(
            title: item.name,
            imageUrl: item.imageUrl,
            isFavorite: true,
            onToggleFavorite: () => favCtrl.toggleFavorite(item),
            isInWatchLater: watchLaterCtrl.watchLaterItems.any(
              (w) =>
                  w.streamId == item.id &&
                  w.contentType == item.contentType,
            ),
            onToggleWatchLater: () =>
                watchLaterCtrl.toggleWatchLater(item),
            onFocusChanged: (_) {},
            onTap: () => navigateByContentType(context, item),
          );
        },
      );
    });
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border_rounded,
              size: 48,
              color: Theme.of(context).hintColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 8),
          const Text(
            'Mark channels, movies or series as favorites to see them here.',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
