import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/favorites_controller.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../models/favorite.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class MobileFavoritesScreen extends StatefulWidget {
  const MobileFavoritesScreen({super.key});

  @override
  State<MobileFavoritesScreen> createState() => _MobileFavoritesScreenState();
}

class _MobileFavoritesScreenState extends State<MobileFavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesController>().loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Live'),
              Tab(text: 'Movies'),
              Tab(text: 'Series'),
            ],
          ),
          Expanded(
            child: Consumer<FavoritesController>(
              builder: (context, favCtrl, _) {
                final live = favCtrl.favorites.where((f) => f.contentType == ContentType.liveStream).toList();
                final movies = favCtrl.favorites.where((f) => f.contentType == ContentType.vod).toList();
                final series = favCtrl.favorites.where((f) => f.contentType == ContentType.series).toList();

                return TabBarView(
                  children: [
                    _buildLiveTab(live, favCtrl),
                    _buildContentTab(movies, favCtrl),
                    _buildContentTab(series, favCtrl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTab(List<Favorite> items, FavoritesController favCtrl) {
    if (items.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => favCtrl.toggleFavorite(item.toContentItem()),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: item.imagePath ?? '',
                width: 50,
                height: 40,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.white24),
              ),
            ),
            title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
            onTap: () => navigateByContentType(context, item.toContentItem()),
          ),
        );
      },
    );
  }

  Widget _buildContentTab(List<Favorite> items, FavoritesController favCtrl) {
    if (items.isEmpty) return _buildEmptyState();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.67,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => favCtrl.toggleFavorite(item.toContentItem()),
          child: _buildPosterCard(item.toContentItem()),
        );
      },
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
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
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
          const Icon(Icons.favorite_border, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(context.loc.no_favorites_found, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
