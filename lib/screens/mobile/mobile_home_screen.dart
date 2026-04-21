import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/watch_history_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class MobileHomeScreen extends StatefulWidget {
  final String playlistId;

  const MobileHomeScreen({super.key, required this.playlistId});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  late WatchHistoryController _historyController;
  late FavoritesController _favoritesController;

  @override
  void initState() {
    super.initState();
    _historyController = context.read<WatchHistoryController>();
    _favoritesController = context.read<FavoritesController>();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _historyController.loadWatchHistory(),
      _favoritesController.loadFavorites(),
    ]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<WatchHistoryController>();
    final favorites = context.watch<FavoritesController>();

    if (history.isLoading || favorites.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final heroItem = _getHeroItem();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        children: [
          if (heroItem != null) _buildHero(heroItem),
          const SizedBox(height: 16),
          if (history.continueWatching.isNotEmpty)
            _buildSection(
              context.loc.continue_watching,
              history.continueWatching.map((h) => ContentItem(
                h.streamId,
                h.title,
                h.imagePath ?? '',
                h.contentType,
              )).toList(),
            ),
          if (favorites.favorites.isNotEmpty)
            _buildSection(
              context.loc.favorites,
              favorites.favorites.map((f) => ContentItem(
                f.streamId,
                f.name,
                f.imagePath ?? '',
                f.contentType,
              )).toList(),
            ),
          if (history.movieHistory.isNotEmpty)
            _buildSection(
              'Recent Movies',
              history.movieHistory.map((h) => ContentItem(
                h.streamId,
                h.title,
                h.imagePath ?? '',
                h.contentType,
              )).toList(),
            ),
          if (history.seriesHistory.isNotEmpty)
            _buildSection(
              'Recent Series',
              history.seriesHistory.map((h) => ContentItem(
                h.streamId,
                h.title,
                h.imagePath ?? '',
                h.contentType,
              )).toList(),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  ContentItem? _getHeroItem() {
    if (_historyController.continueWatching.isNotEmpty) {
      final h = _historyController.continueWatching.first;
      return ContentItem(h.streamId, h.title, h.imagePath ?? '', h.contentType);
    }
    if (_favoritesController.favorites.isNotEmpty) {
      final f = _favoritesController.favorites.first;
      return ContentItem(f.streamId, f.name, f.imagePath ?? '', f.contentType);
    }
    return null;
  }

  Widget _buildHero(ContentItem item) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: () => navigateByContentType(context, item),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<ContentItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {}, // See all
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildPosterCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPosterCard(ContentItem item) {
    return GestureDetector(
      onTap: () => navigateByContentType(context, item),
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[900],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.movie, color: Colors.white24),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                item.name,
                style: const TextStyle(color: Colors.white, fontSize: 10),
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
