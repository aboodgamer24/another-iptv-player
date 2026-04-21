import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/watch_history_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';
import '../../services/tmdb_service.dart';
import '../../models/content_type.dart';
import '../../models/watch_history.dart';
import '../../models/favorite.dart';

class MobileHomeScreen extends StatefulWidget {
  final String playlistId;

  const MobileHomeScreen({super.key, required this.playlistId});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  late WatchHistoryController _historyController;
  late FavoritesController _favoritesController;
  late final TmdbService _tmdb;
  List<Map<String, dynamic>> _trendingMovies = [];
  List<Map<String, dynamic>> _trendingSeries = [];
  bool _tmdbLoading = false;

  @override
  void initState() {
    super.initState();
    _tmdb = TmdbService();
    _historyController = context.read<WatchHistoryController>();
    _favoritesController = context.read<FavoritesController>();

    // Only load if controllers have no data yet — avoids re-fetching on every mount
    if (_historyController.isAllEmpty) {
      _historyController.loadWatchHistory();
    }
    if (_favoritesController.favorites.isEmpty) {
      _favoritesController.loadFavorites();
    }

    // TMDB always fetches fresh on first mount
    if (_trendingMovies.isEmpty) _fetchTmdb();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _tmdbLoading = true);

    await Future.wait([
      _historyController.loadWatchHistory(),
      _favoritesController.loadFavorites(),
      _fetchTmdb(),
    ]);

    if (mounted) {
      setState(() => _tmdbLoading = false);
    }
  }

  Future<void> _fetchTmdb() async {
    try {
      final results = await Future.wait([
        _tmdb.getTrendingMovies(),
        _tmdb.getTrendingTv(),
      ]);
      if (mounted) {
        setState(() {
          _trendingMovies = results[0];
          _trendingSeries = results[1];
        });
      }
    } catch (_) {
      // silently fail — TMDB is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHistoryLoading = context.select<WatchHistoryController, bool>(
      (c) => c.isLoading,
    );
    final isFavLoading = context.select<FavoritesController, bool>(
      (c) => c.isLoading,
    );

    if (isHistoryLoading || isFavLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final continueWatching = context.select<WatchHistoryController, List<WatchHistory>>(
      (c) => c.continueWatching,
    );
    final movieHistory = context.select<WatchHistoryController, List<WatchHistory>>(
      (c) => c.movieHistory,
    );
    final seriesHistory = context.select<WatchHistoryController, List<WatchHistory>>(
      (c) => c.seriesHistory,
    );
    final favItems = context.select<FavoritesController, List<Favorite>>(
      (c) => c.favorites,
    );

    final heroItem = _getHeroItem();
    final continueWatchingFiltered = continueWatching
        .where((WatchHistory h) => h.contentType != ContentType.liveStream)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        children: [
          if (heroItem != null) _buildHero(heroItem),
          const SizedBox(height: 16),
          if (continueWatchingFiltered.isNotEmpty)
            _buildSection(
              context.loc.continue_watching,
              continueWatchingFiltered
                  .map(
                    (h) => ContentItem(
                      h.streamId,
                      h.title,
                      h.imagePath ?? '',
                      h.contentType,
                    ),
                  )
                  .toList(),
            ),
          if (favItems.isNotEmpty)
            _buildSection(
              context.loc.favorites,
              favItems
                  .map(
                    (f) => ContentItem(
                      f.streamId,
                      f.name,
                      f.imagePath ?? '',
                      f.contentType,
                    ),
                  )
                  .toList(),
            ),

          if (_trendingMovies.isNotEmpty)
            _buildTmdbSection('Trending Movies', _trendingMovies),
          if (_trendingSeries.isNotEmpty)
            _buildTmdbSection('Trending Series', _trendingSeries),

          if (movieHistory.isNotEmpty)
            _buildSection(
              'Recent Movies',
              movieHistory
                  .map(
                    (WatchHistory h) => ContentItem(
                      h.streamId,
                      h.title,
                      h.imagePath ?? '',
                      h.contentType,
                    ),
                  )
                  .toList(),
            ),
          if (seriesHistory.isNotEmpty)
            _buildSection(
              'Recent Series',
              seriesHistory
                  .map(
                    (WatchHistory h) => ContentItem(
                      h.streamId,
                      h.title,
                      h.imagePath ?? '',
                      h.contentType,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTmdbSection(String title, List<Map<String, dynamic>> items) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemExtent: 118.0,
              itemBuilder: (context, index) {
                final item = items[index];
                final posterPath = item['poster_path'] as String?;
                final name = (item['title'] ?? item['name'] ?? '') as String;
                return GestureDetector(
                  onTap: () {/* TMDB detail navigation if available */},
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
                            imageUrl: _tmdb.getPosterUrl(posterPath),
                            fit: BoxFit.cover,
                            memCacheWidth: 220,
                            memCacheHeight: 330,
                            fadeInDuration: const Duration(milliseconds: 150),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.movie, color: Colors.white24),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  ContentItem? _getHeroItem() {
    // Prefer first non-live continue watching item
    final nonLiveContinue = _historyController.continueWatching
        .where((WatchHistory h) => h.contentType != ContentType.liveStream)
        .toList();
    if (nonLiveContinue.isNotEmpty) {
      final h = nonLiveContinue.first;
      return ContentItem(h.streamId, h.title, h.imagePath ?? '', h.contentType);
    }
    // Fallback: first non-live favorite
    final nonLiveFav = _favoritesController.favorites
        .where((f) => f.contentType != ContentType.liveStream)
        .toList();
    if (nonLiveFav.isNotEmpty) {
      final f = nonLiveFav.first;
      return ContentItem(f.streamId, f.name, f.imagePath ?? '', f.contentType);
    }
    return null;
  }

  Widget _buildHero(ContentItem item) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: GestureDetector(
          onTap: () => navigateByContentType(context, item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 780,
                memCacheHeight: 440,
                fadeInDuration: const Duration(milliseconds: 200),
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
      ),
    );
  }

  Widget _buildSection(String title, List<ContentItem> items) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
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
              cacheExtent: 500,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemExtent: 120.0,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildPosterCard(item);
              },
            ),
          ),
        ],
      ),
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
                memCacheWidth: 220,
                memCacheHeight: 330,
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.movie, color: Colors.white24),
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
