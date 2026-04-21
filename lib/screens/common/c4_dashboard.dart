import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/watch_history_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../models/watch_history.dart';
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
  ContentItem? _tmdbHeroItem;
  bool _heroReady = false;
  String? _lastPrecachedHeroId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTmdbHeroFirst(); // fast, independent
      _loadData(); // slow, runs in parallel
    });
  }

  Future<void> _loadTmdbHeroFirst() async {
    try {
      // Fetch trending movies from TMDB
      final results = await _tmdbService.getTrendingMovies();
      if (!mounted || results.isEmpty) {
        if (mounted) setState(() => _heroReady = true);
        return;
      }

      // Pick the first result that has a backdrop
      final pick = results.firstWhere(
        (m) =>
            m['backdrop_path'] != null &&
            (m['backdrop_path'] as String).isNotEmpty,
        orElse: () => results.first,
      );

      final backdropUrl = _tmdbService.getBackdropUrl(
        pick['backdrop_path'] as String?,
      );
      final title = (pick['title'] ?? pick['name'] ?? '') as String;

      final heroItem = ContentItem(
        pick['id'].toString(),
        title,
        // imageUrl for the hero widget — use backdrop here
        backdropUrl,
        ContentType.vod,
      );

      // Pre-warm into cache immediately
      if (backdropUrl.isNotEmpty) {
        await precacheImage(CachedNetworkImageProvider(backdropUrl), context);
      }

      if (mounted) {
        setState(() {
          _tmdbHeroItem = heroItem;
          _heroReady = true;
        });
      }
    } catch (e) {
      debugPrint('TMDB Hero Error: $e');
      if (mounted) setState(() => _heroReady = true);
    }
  }

  Future<void> _loadData() async {
    final trendingMovies = await _tmdbService.getTrendingMovies();
    final trendingTv = await _tmdbService.getTrendingTv();

    if (mounted) {
      setState(() {
        _trendingMovies = trendingMovies
            .map(
              (m) => ContentItem(
                m['id'].toString(),
                m['title'] ?? m['name'] ?? '',
                _tmdbService.getPosterUrl(m['poster_path']),
                ContentType.vod,
              ),
            )
            .toList();
        _trendingSeries = trendingTv
            .map(
              (m) => ContentItem(
                m['id'].toString(),
                m['name'] ?? m['title'] ?? '',
                _tmdbService.getPosterUrl(m['poster_path']),
                ContentType.series,
              ),
            )
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

    // Pre-warm hero image into cache immediately after item is resolved
    final heroItem = xtreamController.heroItem;
    if (heroItem != null &&
        heroItem.imageUrl.isNotEmpty &&
        heroItem.id != _lastPrecachedHeroId) {
      _lastPrecachedHeroId = heroItem.id;
      precacheImage(CachedNetworkImageProvider(heroItem.imageUrl), context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleRails = homeRailsController.visibleRails;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // Hero — always rendered; shimmer until TMDB data arrives
            if (!_heroReady)
              const _HeroBannerShimmer()
            else if (_tmdbHeroItem != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: C4DashboardHero(
                  key: ValueKey(_tmdbHeroItem!.id),
                  item: _tmdbHeroItem!,
                  onPlay: () => _playTmdbItem(context, _tmdbHeroItem!),
                ),
              ),

            const SizedBox(height: 32),

            for (final rail in visibleRails) ...[
              _buildRail(
                context,
                rail.id,
                xtreamController,
                historyController,
                favoritesController,
                watchLaterController,
              ),
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
        if (xtreamController.recommendations.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_recommended,
            items: xtreamController.recommendations,
          ),
        );

      case 'favorites_live':
        if (favoritesController.liveStreamFavorites.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_favorites_live,
            items: favoritesController.liveStreamFavorites
                .map(
                  (f) => ContentItem(
                    f.streamId,
                    f.name,
                    f.imagePath ?? '',
                    f.contentType,
                  ),
                )
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
        if (favoritesController.movieFavorites.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_favorites_movies,
            items: favoritesController.movieFavorites
                .map(
                  (f) => ContentItem(
                    f.streamId,
                    f.name,
                    f.imagePath ?? '',
                    f.contentType,
                  ),
                )
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
        if (favoritesController.seriesFavorites.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_favorites_series,
            items: favoritesController.seriesFavorites
                .map(
                  (f) => ContentItem(
                    f.streamId,
                    f.name,
                    f.imagePath ?? '',
                    f.contentType,
                  ),
                )
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
        if (watchLaterController.watchLaterItems.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_watch_later,
            items: watchLaterController.watchLaterItems
                .map(
                  (h) => ContentItem(
                    h.streamId,
                    h.title,
                    h.imagePath ?? '',
                    h.contentType,
                  ),
                )
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
        if (historyController.continueWatching.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_continue_watching,
            items: historyController.continueWatching
                .where((WatchHistory h) => h.contentType != ContentType.liveStream)
                .map(
                  (WatchHistory h) => ContentItem(
                    h.streamId,
                    h.title,
                    h.imagePath ?? '',
                    h.contentType,
                  ),
                )
                .toList(),
            onItemTap: (ctx, item) {
              final h = historyController.continueWatching.firstWhere(
                (WatchHistory wh) =>
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
        if (historyController.liveHistory.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: C4ContentRail(
            title: context.loc.rail_live_history,
            items: historyController.liveHistory
                .map(
                  (WatchHistory h) => ContentItem(
                    h.streamId,
                    h.title,
                    h.imagePath ?? '',
                    h.contentType,
                  ),
                )
                .toList(),
            isPortrait: false,
            onItemTap: (ctx, item) {
              final h = historyController.liveHistory.firstWhere(
                (WatchHistory wh) =>
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error matching content: $e')));
      }
    }
  }
}

class _HeroBannerShimmer extends StatefulWidget {
  const _HeroBannerShimmer();
  @override
  State<_HeroBannerShimmer> createState() => _HeroBannerShimmerState();
}

class _HeroBannerShimmerState extends State<_HeroBannerShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        height: size.height * 0.45,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFF13161C),
                Color(0xFF1E2430),
                Color(0xFF13161C),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
