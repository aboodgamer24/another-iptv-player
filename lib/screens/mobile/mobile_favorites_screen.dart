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
                final live = favCtrl.favorites
                    .where((f) => f.contentType == ContentType.liveStream)
                    .toList();
                final movies = favCtrl.favorites
                    .where((f) => f.contentType == ContentType.vod)
                    .toList();
                final series = favCtrl.favorites
                    .where((f) => f.contentType == ContentType.series)
                    .toList();

                return TabBarView(
                  children: [
                    _LiveTab(items: live, favCtrl: favCtrl),
                    _ContentTab(items: movies, favCtrl: favCtrl),
                    _ContentTab(items: series, favCtrl: favCtrl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTab extends StatefulWidget {
  final List<Favorite> items;
  final FavoritesController favCtrl;
  const _LiveTab({required this.items, required this.favCtrl});

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.items.isEmpty) return const _EmptyState();

    return ListView.builder(
      cacheExtent: 500,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) =>
              widget.favCtrl.toggleFavorite(item.toContentItem()),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: item.imagePath ?? '',
                width: 50,
                height: 40,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.live_tv, color: Colors.white24),
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () async {
              final resolved = await context
                  .read<FavoritesController>()
                  .resolveContentItem(item);
              if (!context.mounted) return;
              await navigateByContentType(context, resolved);
            },
          ),
        );
      },
    );
  }
}

class _ContentTab extends StatefulWidget {
  final List<Favorite> items;
  final FavoritesController favCtrl;
  const _ContentTab({required this.items, required this.favCtrl});

  @override
  State<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<_ContentTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.items.isEmpty) return const _EmptyState();

    return GridView.builder(
      cacheExtent: 500,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.67,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) =>
              widget.favCtrl.toggleFavorite(item.toContentItem()),
          child: _PosterCard(item: item.toContentItem()),
        );
      },
    );
  }
}

class _PosterCard extends StatelessWidget {
  final ContentItem item;
  const _PosterCard({required this.item});

  @override
  Widget build(BuildContext context) {
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            context.loc.no_favorites_found,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
