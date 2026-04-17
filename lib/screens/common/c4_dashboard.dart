import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/watch_history_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../controllers/watch_later_controller.dart';
import '../../l10n/localization_extension.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../services/tmdb_service.dart';
import '../../widgets/common/c4_dashboard_hero.dart';
import '../../widgets/common/c4_content_rail.dart';

class C4Dashboard extends StatefulWidget {
  final String playlistId;

  const C4Dashboard({super.key, required this.playlistId});

  @override
  State<C4Dashboard> createState() => _C4DashboardState();
}

class _C4DashboardState extends State<C4Dashboard> {
  final TmdbService _tmdbService = TmdbService();
  List<ContentItem> _trendingItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final trendingMovies = await _tmdbService.getTrendingMovies();
    final trendingTv = await _tmdbService.getTrendingTv();

    if (mounted) {
      setState(() {
        _trendingItems = [
          ...trendingMovies.map((m) => ContentItem(
                m['id'].toString(),
                m['title'] ?? m['name'] ?? '',
                _tmdbService.getPosterUrl(m['poster_path']),
                ContentType.vod,
              )),
          ...trendingTv.map((m) => ContentItem(
                m['id'].toString(),
                m['name'] ?? m['title'] ?? '',
                _tmdbService.getPosterUrl(m['poster_path']),
                ContentType.series,
              )),
        ];
        _trendingItems.shuffle();
      });
    }

    if (mounted) {
      final historyController = context.read<WatchHistoryController>();
      final favoritesController = context.read<FavoritesController>();
      final watchLaterController = context.read<WatchLaterController>();

      await Future.wait<void>([
        historyController.loadWatchHistory(),
        favoritesController.loadFavorites(),
        watchLaterController.loadWatchLaterItems(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final xtreamController = context.watch<XtreamCodeHomeController>();
    final historyController = context.watch<WatchHistoryController>();
    final favoritesController = context.watch<FavoritesController>();
    final watchLaterController = context.watch<WatchLaterController>();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 1. Hero Section
        if (xtreamController.heroItem != null)
          C4DashboardHero(item: xtreamController.heroItem!),

        const SizedBox(height: 32),

        // 2. Continue watching (VOD/Series) - Moved up for C4-TV feel
        if (historyController.continueWatching.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: C4ContentRail(
              title: context.loc.continue_watching,
              items: historyController.continueWatching
                  .where((h) => h.contentType != ContentType.liveStream)
                  .map((h) => ContentItem(
                        h.streamId,
                        h.title,
                        h.imagePath ?? '',
                        h.contentType,
                      ))
                  .toList(),
            ),
          ),

        // 3. Trending this week (TMDB)
        if (_trendingItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: C4ContentRail(
              title: 'Trending this week',
              items: _trendingItems,
            ),
          ),

        // 4. Recommendations (Local random)
        if (xtreamController.recommendations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: C4ContentRail(
              title: 'Recommended for you',
              items: xtreamController.recommendations,
            ),
          ),

        // 5. Watch later
        if (watchLaterController.watchLaterItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: C4ContentRail(
              title: 'Watch later',
              items: watchLaterController.watchLaterItems
                  .map((h) => ContentItem(
                        h.streamId,
                        h.title,
                        h.imagePath ?? '',
                        h.contentType,
                      ))
                  .toList(),
            ),
          ),

        // 6. Recent channels (Live TV)
        if (historyController.liveHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: C4ContentRail(
              title: 'Recently watched channels',
              items: historyController.liveHistory
                  .map((h) => ContentItem(
                        h.streamId,
                        h.title,
                        h.imagePath ?? '',
                        h.contentType,
                      ))
                  .toList(),
              isPortrait: false,
            ),
          ),

        // 7. Favorites (Live TV)
        if (favoritesController.favorites.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: C4ContentRail(
              title: 'Favorite channels',
              items: favoritesController.favorites
                  .where((f) => f.contentType == ContentType.liveStream)
                  .map((f) => ContentItem(
                        f.streamId,
                        f.name,
                        f.imagePath ?? '',
                        f.contentType,
                      ))
                  .toList(),
              isPortrait: false,
            ),
          ),

        const SizedBox(height: 64),
      ],
    );
  }
}
