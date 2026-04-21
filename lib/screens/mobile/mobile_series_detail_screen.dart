import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../repositories/iptv_repository.dart';
import '../../models/api_configuration_model.dart';
import '../../services/app_state.dart';
import '../../services/watch_history_service.dart';
import '../../controllers/favorites_controller.dart';
import '../../controllers/watch_later_controller.dart';
import '../../l10n/localization_extension.dart';
import '../../widgets/player_widget.dart';
import '../../database/database.dart';

class MobileSeriesDetailScreen extends StatefulWidget {
  final ContentItem contentItem;

  const MobileSeriesDetailScreen({super.key, required this.contentItem});

  @override
  State<MobileSeriesDetailScreen> createState() => _MobileSeriesDetailScreenState();
}

class _MobileSeriesDetailScreenState extends State<MobileSeriesDetailScreen> with TickerProviderStateMixin {
  late IptvRepository _repository;
  late FavoritesController _favoritesController;
  late WatchLaterController _watchLaterController;
  late WatchHistoryService _watchHistoryService;

  SeriesInfosData? _seriesInfo;
  List<SeasonsData> _seasons = [];
  List<EpisodesData> _episodes = [];
  bool _isLoading = true;
  String? _error;
  bool _isFavorite = false;
  bool _isInWatchLater = false;
  int _selectedSeasonIndex = 0;
  Map<String, double> _episodeProgress = {};
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _repository = IptvRepository(
      ApiConfig(
        baseUrl: AppState.currentPlaylist!.url!,
        username: AppState.currentPlaylist!.username!,
        password: AppState.currentPlaylist!.password!,
      ),
      AppState.currentPlaylist!.id,
    );
    _favoritesController = context.read<FavoritesController>();
    _watchLaterController = context.read<WatchLaterController>();
    _watchHistoryService = WatchHistoryService();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final seriesId = widget.contentItem.id;
      final response = await _repository.getSeriesInfo(seriesId);

      if (response != null) {
        if (mounted) {
          setState(() {
            _seriesInfo = response.seriesInfo;
            _seasons = response.seasons.where((s) => response.episodes.any((ep) => ep.season == s.seasonNumber)).toList();
            _episodes = response.episodes;
            _isLoading = false;
            _tabController = TabController(length: _seasons.length, vsync: this);
            _tabController!.addListener(() {
              if (mounted) setState(() => _selectedSeasonIndex = _tabController!.index);
            });
          });
          await Future.wait([
            _loadEpisodeProgress(),
            _checkStatus(),
          ]);
        }
      } else {
        if (mounted) setState(() { _error = 'Failed to load series info'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _isLoading = false; });
    }
  }

  Future<void> _loadEpisodeProgress() async {
    final playlistId = AppState.currentPlaylist!.id;
    final Map<String, double> progressMap = {};

    for (final ep in _episodes) {
      final history = await _watchHistoryService.getWatchHistory(playlistId, ep.episodeId.toString());
      if (history?.watchDuration != null && history?.totalDuration != null) {
        final total = history!.totalDuration!.inMilliseconds;
        if (total > 0) {
          progressMap[ep.episodeId.toString()] = (history.watchDuration!.inMilliseconds / total).clamp(0.0, 1.0);
        }
      }
    }

    if (mounted) setState(() => _episodeProgress = progressMap);
  }

  Future<void> _checkStatus() async {
    final isFav = await _favoritesController.isFavorite(widget.contentItem.id, widget.contentItem.contentType);
    final isWL = await _watchLaterController.isWatchLater(widget.contentItem.id, widget.contentItem.contentType);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isInWatchLater = isWL;
      });
    }
  }

  void _playEpisode(EpisodesData episode) {
    final allContents = _episodes
        .map((x) => ContentItem(
              x.episodeId,
              x.title,
              x.movieImage ?? '',
              ContentType.series,
              containerExtension: x.containerExtension,
              season: x.season,
            ))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: SizedBox.expand(
              child: PlayerWidget(
                contentItem: ContentItem(
                  episode.episodeId,
                  episode.title,
                  episode.movieImage ?? '',
                  ContentType.series,
                  containerExtension: episode.containerExtension,
                  season: episode.season,
                ),
                queue: allContents,
              ),
            ),
          ),
        ),
      ),
    ).then((_) => _loadEpisodeProgress());
  }

  List<EpisodesData> get _currentSeasonEpisodes {
    if (_seasons.isEmpty) return [];
    final season = _seasons[_selectedSeasonIndex];
    return _episodes.where((ep) => ep.season == season.seasonNumber).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFF0B0E14), body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              TextButton(onPressed: _loadAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _seriesInfo?.cover ?? widget.contentItem.imagePath,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0B0E14)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _seriesInfo?.name ?? widget.contentItem.name,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_seriesInfo?.genre ?? ''} · ⭐ ${(_seriesInfo?.rating5based ?? 0).toStringAsFixed(1)}/5',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () async {
                          final result = await _favoritesController.toggleFavorite(widget.contentItem);
                          setState(() => _isFavorite = result);
                        },
                        icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : null),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final result = await _watchLaterController.toggleWatchLater(widget.contentItem);
                          setState(() => _isInWatchLater = result);
                        },
                        icon: Icon(_isInWatchLater ? Icons.schedule : Icons.schedule_outlined, color: _isInWatchLater ? Colors.blue : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_seriesInfo?.plot != null) ...[
                    const Text('Synopsis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_seriesInfo!.plot!, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
          if (_tabController != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: _seasons.map((s) => Tab(text: s.name)).toList(),
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ep = _currentSeasonEpisodes[index];
                return _buildEpisodeRow(ep);
              },
              childCount: _currentSeasonEpisodes.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(EpisodesData ep) {
    final progress = _episodeProgress[ep.episodeId.toString()];
    return ListTile(
      onTap: () => _playEpisode(ep),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 100,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[900],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: ep.movieImage ?? '',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.tv, color: Colors.white24),
            ),
            if (progress != null && progress > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                ),
              ),
            const Center(child: Icon(Icons.play_arrow, color: Colors.white70)),
          ],
        ),
      ),
      title: Text(
        'E${ep.episodeNum}: ${ep.title}',
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        ep.duration ?? '',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0B0E14),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
