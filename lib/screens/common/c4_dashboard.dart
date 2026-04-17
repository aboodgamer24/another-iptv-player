import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/watch_history_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../controllers/watch_later_controller.dart';
import '../../controllers/home_rails_controller.dart';
import '../../l10n/localization_extension.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../services/tmdb_service.dart';
import '../../widgets/common/c4_dashboard_hero.dart';
import '../../widgets/common/c4_content_rail.dart';
import '../../services/service_locator.dart';
import '../../database/database.dart';
import '../../services/app_state.dart';
import '../../utils/navigate_by_content_type.dart';

class C4Dashboard extends StatefulWidget {
  final String playlistId;

  const C4Dashboard({super.key, required this.playlistId});

  @override
  State<C4Dashboard> createState() => _C4DashboardState();
}

class _C4DashboardState extends State<C4Dashboard> {
  final TmdbService _tmdbService = TmdbService();
  List<ContentItem> _trendingMovies = [];
  List<ContentItem> _trendingSeries = [];

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
        _trendingMovies = trendingMovies
            .map((m) => ContentItem(
                  m['id'].toString(),
                  m['title'] ?? m['name'] ?? '',
                  _tmdbService.getPosterUrl(m['poster_path']),
                  ContentType.vod,
                ))
            .toList();
        _trendingSeries = trendingTv
            .map((m) => ContentItem(
                  m['id'].toString(),
                  m['name'] ?? m['title'] ?? '',
                  _tmdbService.getPosterUrl(m['poster_path']),
                  ContentType.series,
                ))
            .toList();
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
    final homeRailsController = context.watch<HomeRailsController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleRails = homeRailsController.visibleRails;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // Hero Section is always first (not togglable for now based on request)
            if (xtreamController.heroItem != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: C4DashboardHero(
                  key: ValueKey(xtreamController.heroItem!.id),
                  item: xtreamController.heroItem!,
                ),
              ),

            const SizedBox(height: 32),

            for (final rail in visibleRails) ...[
              _buildRail(context, rail.id, xtreamController, historyController,
                  favoritesController, watchLaterController),
            ],

            const SizedBox(height: 64),
          ],
        );
      },
    );
  }

  Widget _buildRail(
    BuildContext context,
    String id,
    XtreamCodeHomeController xtreamController,
    WatchHistoryController historyController,
    FavoritesController favoritesController,
    WatchLaterController watchLaterController,
  ) {
    switch (id) {
      case 'recommended':
        if (xtreamController.recommendations.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_recommended,
            items: xtreamController.recommendations,
          ),
        );

      case 'favorites_live':
        if (favoritesController.liveStreamFavorites.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_favorites_live,
            items: favoritesController.liveStreamFavorites
                .map((f) => ContentItem(
                      f.streamId,
                      f.name,
                      f.imagePath ?? '',
                      f.contentType,
                    ))
                .toList(),
            isPortrait: false,
            onItemTap: (ctx, item) {
              final fav = favoritesController.liveStreamFavorites.firstWhere(
                (f) =>
                    f.streamId == item.id && f.contentType == item.contentType,
                orElse: () => throw Exception('Favorite not found'),
              );
              favoritesController.playFavorite(ctx, fav);
            },
          ),
        );

      case 'favorites_movies':
        if (favoritesController.movieFavorites.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_favorites_movies,
            items: favoritesController.movieFavorites
                .map((f) => ContentItem(
                      f.streamId,
                      f.name,
                      f.imagePath ?? '',
                      f.contentType,
                    ))
                .toList(),
            onItemTap: (ctx, item) {
              final fav = favoritesController.movieFavorites.firstWhere(
                (f) =>
                    f.streamId == item.id && f.contentType == item.contentType,
                orElse: () => throw Exception('Favorite not found'),
              );
              favoritesController.playFavorite(ctx, fav);
            },
          ),
        );

      case 'favorites_series':
        if (favoritesController.seriesFavorites.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_favorites_series,
            items: favoritesController.seriesFavorites
                .map((f) => ContentItem(
                      f.streamId,
                      f.name,
                      f.imagePath ?? '',
                      f.contentType,
                    ))
                .toList(),
            onItemTap: (ctx, item) {
              final fav = favoritesController.seriesFavorites.firstWhere(
                (f) =>
                    f.streamId == item.id && f.contentType == item.contentType,
                orElse: () => throw Exception('Favorite not found'),
              );
              favoritesController.playFavorite(ctx, fav);
            },
          ),
        );

      case 'watch_later':
        if (watchLaterController.watchLaterItems.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_watch_later,
            items: watchLaterController.watchLaterItems
                .map((h) => ContentItem(
                      h.streamId,
                      h.title,
                      h.imagePath ?? '',
                      h.contentType,
                    ))
                .toList(),
            onItemTap: (ctx, item) {
              final data = watchLaterController.watchLaterItems.firstWhere(
                (i) =>
                    i.streamId == item.id && i.contentType == item.contentType,
              );
              watchLaterController.playContent(ctx, data);
            },
          ),
        );

      case 'continue_watching':
        if (historyController.continueWatching.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_continue_watching,
            items: historyController.continueWatching
                .where((h) => h.contentType != ContentType.liveStream)
                .map((h) => ContentItem(
                      h.streamId,
                      h.title,
                      h.imagePath ?? '',
                      h.contentType,
                    ))
                .toList(),
            onItemTap: (ctx, item) {
              final h = historyController.continueWatching.firstWhere(
                (wh) =>
                    wh.streamId == item.id &&
                    wh.contentType == item.contentType,
                orElse: () =>
                    throw Exception('WatchHistory not found for item'),
              );
              historyController.playContent(ctx, h);
            },
          ),
        );

      case 'live_history':
        if (historyController.liveHistory.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_live_history,
            items: historyController.liveHistory
                .map((h) => ContentItem(
                      h.streamId,
                      h.title,
                      h.imagePath ?? '',
                      h.contentType,
                    ))
                .toList(),
            isPortrait: false,
            onItemTap: (ctx, item) {
              final h = historyController.liveHistory.firstWhere(
                (wh) =>
                    wh.streamId == item.id &&
                    wh.contentType == item.contentType,
                orElse: () =>
                    throw Exception('WatchHistory not found for item'),
              );
              historyController.playContent(ctx, h);
            },
          ),
        );

      case 'trending_movies':
        if (_trendingMovies.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_trending_movies,
            items: _trendingMovies,
            onItemTap: (ctx, item) => _playTmdbItem(ctx, item),
          ),
        );

      case 'trending_series':
        if (_trendingSeries.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_trending_series,
            items: _trendingSeries,
            onItemTap: (ctx, item) => _playTmdbItem(ctx, item),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _playTmdbItem(BuildContext context, ContentItem item) async {
    final db = getIt<AppDatabase>();
    final playlistId = AppState.currentPlaylist?.id;

    if (playlistId == null) return;

    ContentItem? mapped;

    try {
      if (item.contentType == ContentType.vod) {
        final movies = await db.searchMovie(playlistId, item.name);
        if (movies.isNotEmpty) {
          // Look for exact match first
          final exact = movies.firstWhere(
            (m) => m.name.toLowerCase() == item.name.toLowerCase(),
            orElse: () => movies.first,
          );
          mapped = ContentItem(
            exact.streamId,
            exact.name,
            exact.streamIcon,
            ContentType.vod,
            containerExtension: exact.containerExtension,
            vodStream: exact,
          );
        }
      } else if (item.contentType == ContentType.series) {
        final series = await db.searchSeries(playlistId, item.name);
        if (series.isNotEmpty) {
          final exact = series.firstWhere(
            (s) => s.name.toLowerCase() == item.name.toLowerCase(),
            orElse: () => series.first,
          );
          mapped = ContentItem(
            exact.seriesId,
            exact.name,
            exact.cover ?? '',
            ContentType.series,
            seriesStream: exact,
          );
        }
      }

      if (mounted) {
        if (mapped != null) {
          navigateByContentType(context, mapped);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This title is not available in your playlist'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error matching content: $e')),
        );
      }
    }
  }
}
