import 'dart:ui';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/watch_later_controller.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/widgets/player_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Desktop-optimized series detail page with season selector,
/// episode list with thumbnails and progress, auto-play next.
class DesktopSeriesDetailScreen extends StatefulWidget {
  final ContentItem contentItem;

  const DesktopSeriesDetailScreen({super.key, required this.contentItem});

  @override
  State<DesktopSeriesDetailScreen> createState() =>
      _DesktopSeriesDetailScreenState();
}

class _DesktopSeriesDetailScreenState extends State<DesktopSeriesDetailScreen> {
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
  EpisodesData? _lastWatchedEpisode;
  Map<String, double> _episodeProgress = {};

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
        setState(() {
          _seriesInfo = response.seriesInfo;
          _seasons = response.seasons;
          _episodes = response.episodes;
          _isLoading = false;
        });
        await Future.wait([
          _loadEpisodeProgress(),
          _loadLastWatched(),
          _checkStatus(),
        ]);
      } else {
        setState(() {
          _error = 'Failed to load series info';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEpisodeProgress() async {
    final playlistId = AppState.currentPlaylist!.id;
    final Map<String, double> progressMap = {};

    for (final ep in _episodes) {
      final history = await _watchHistoryService.getWatchHistory(
        playlistId,
        ep.episodeId.toString(),
      );
      if (history?.watchDuration != null && history?.totalDuration != null) {
        final total = history!.totalDuration!.inMilliseconds;
        if (total > 0) {
          progressMap[ep.episodeId.toString()] =
              (history.watchDuration!.inMilliseconds / total).clamp(0.0, 1.0);
        }
      }
    }

    if (mounted) setState(() => _episodeProgress = progressMap);
  }

  Future<void> _loadLastWatched() async {
    final playlistId = AppState.currentPlaylist!.id;
    final allHistory = await _watchHistoryService.getWatchHistoryByContentType(
      ContentType.series,
      playlistId,
    );

    if (!mounted || allHistory.isEmpty) return;

    final byId = <String, EpisodesData>{
      for (final ep in _episodes) ep.episodeId.toString(): ep,
    };

    for (final h in allHistory) {
      final ep = byId[h.streamId];
      if (ep != null) {
        setState(() => _lastWatchedEpisode = ep);
        return;
      }
    }
  }

  Future<void> _checkStatus() async {
    final isFav = await _favoritesController.isFavorite(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );
    final isWL = await _watchLaterController.isWatchLater(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isInWatchLater = isWL;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesController.toggleFavorite(
      widget.contentItem,
    );
    if (mounted) {
      setState(() => _isFavorite = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? context.loc.added_to_favorites
                : context.loc.removed_from_favorites,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleWatchLater() async {
    final result = await _watchLaterController.toggleWatchLater(
      widget.contentItem,
    );
    if (mounted) {
      setState(() => _isInWatchLater = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? context.loc.added_to_watch_later
                : context.loc.removed_from_watch_later,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _playEpisode(EpisodesData episode) {
    final allContents = _episodes
        .map(
          (x) => ContentItem(
            x.episodeId,
            x.title,
            x.movieImage ?? '',
            ContentType.series,
            containerExtension: x.containerExtension,
            season: x.season,
          ),
        )
        .toList();

    setState(() => _lastWatchedEpisode = episode);

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
    ).then((_) {
      _loadEpisodeProgress();
      _loadLastWatched();
    });
  }

  List<SeasonsData> get _validSeasons {
    return _seasons.where((s) {
      return _episodes.any((ep) => ep.season == s.seasonNumber);
    }).toList();
  }

  List<EpisodesData> get _currentSeasonEpisodes {
    if (_validSeasons.isEmpty) return [];
    final season = _validSeasons[_selectedSeasonIndex];
    return _episodes.where((ep) => ep.season == season.seasonNumber).toList();
  }

  String? get _coverUrl {
    if (_seriesInfo?.cover != null && _seriesInfo!.cover!.isNotEmpty) {
      return _seriesInfo!.cover;
    }
    if (widget.contentItem.imagePath.isNotEmpty) {
      return widget.contentItem.imagePath;
    }
    return widget.contentItem.seriesStream?.cover;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5A45FF)),
            )
          : _error != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAll,
            child: Text(context.loc.try_again),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop
        if (_coverUrl != null) ...[
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: _coverUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF0B0E14)),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: Colors.black.withValues(alpha: 0.75)),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0B0E14).withValues(alpha: 0.8),
                    const Color(0xFF0B0E14),
                  ],
                  stops: const [0.0, 0.4, 0.7],
                ),
              ),
            ),
          ),
        ],
        // Main layout
        SingleChildScrollView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            bottom: 40,
            left: 48,
            right: 48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Poster + Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPoster(),
                      const SizedBox(width: 36),
                      Expanded(child: _buildSeriesInfo()),
                    ],
                  ),
                  const SizedBox(height: 36),
                  // Season selector
                  _buildSeasonSelector(),
                  const SizedBox(height: 20),
                  // Episode list
                  _buildEpisodeList(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoster() {
    return Container(
      width: 260,
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _coverUrl != null
            ? CachedNetworkImage(
                imageUrl: _coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Icon(Icons.tv, size: 50, color: Colors.grey),
                ),
              )
            : Container(
                color: const Color(0xFF1E1E1E),
                child: const Icon(Icons.tv, size: 50, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildSeriesInfo() {
    final name = _seriesInfo?.name ?? widget.contentItem.name;
    final genre = _seriesInfo?.genre ?? widget.contentItem.seriesStream?.genre;
    final plot = _seriesInfo?.plot ?? widget.contentItem.seriesStream?.plot;
    final rating = _seriesInfo?.rating5based ?? 0;
    final cast = _seriesInfo?.cast ?? widget.contentItem.seriesStream?.cast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Rating + Genre + Fav
        Row(
          children: [
            if (rating > 0) ...[
              ...List.generate(
                5,
                (i) => Icon(
                  i < rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${rating.toStringAsFixed(1)}/5',
                style: const TextStyle(color: Colors.amber, fontSize: 14),
              ),
              const SizedBox(width: 16),
            ],
            if (genre != null && genre.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF262A35)),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(
                    color: Color(0xFFA0A5B5),
                    fontSize: 12,
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              onPressed: _toggleWatchLater,
              icon: Icon(
                _isInWatchLater
                    ? Icons.watch_later
                    : Icons.watch_later_outlined,
                color: _isInWatchLater
                    ? Colors.blueAccent
                    : const Color(0xFF747B8B),
              ),
            ),
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : const Color(0xFF747B8B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Continue watching button
        if (_lastWatchedEpisode != null) ...[
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _playEpisode(_lastWatchedEpisode!),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A45FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                'Continue: S${_lastWatchedEpisode!.season} E${_lastWatchedEpisode!.episodeNum}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Plot
        if (plot != null && plot.isNotEmpty) ...[
          Text(
            plot,
            style: const TextStyle(
              color: Color(0xFFA0A5B5),
              fontSize: 14,
              height: 1.6,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],

        // Cast
        if (cast != null && cast.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cast: ',
                style: TextStyle(
                  color: Color(0xFF747B8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  cast,
                  style: const TextStyle(
                    color: Color(0xFFA0A5B5),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    if (_validSeasons.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _validSeasons.length,
        itemBuilder: (context, index) {
          final season = _validSeasons[index];
          final isSelected = index == _selectedSeasonIndex;
          final epCount = _episodes
              .where((e) => e.season == season.seasonNumber)
              .length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _selectedSeasonIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF5A45FF)
                        : const Color(0xFF13161C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF5A45FF)
                          : const Color(0xFF1E2128),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        season.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFA0A5B5),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($epCount)',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : const Color(0xFF747B8B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeList() {
    final eps = _currentSeasonEpisodes;

    if (eps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF13161C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            context.loc.not_found_in_category,
            style: const TextStyle(color: Color(0xFF747B8B)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eps.length,
      itemBuilder: (context, index) {
        final ep = eps[index];
        return _EpisodeCard(
          episode: ep,
          progress: _episodeProgress[ep.episodeId.toString()],
          onTap: () => _playEpisode(ep),
        );
      },
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final EpisodesData episode;
  final double? progress;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    this.progress,
    required this.onTap,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1A1D24) : const Color(0xFF13161C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF323640)
                  : const Color(0xFF1E2128),
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 140,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0E14),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.episode.movieImage != null &&
                            widget.episode.movieImage!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.episode.movieImage!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF0F1115),
                              child: const Icon(
                                Icons.tv,
                                color: Color(0xFF262A35),
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF0F1115),
                            child: const Icon(
                              Icons.tv,
                              color: Color(0xFF262A35),
                              size: 28,
                            ),
                          ),
                    if (_hovered)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    // Progress bar
                    if (widget.progress != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: widget.progress!,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF5A45FF),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.episode.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: _hovered
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S${widget.episode.season} · Episode ${widget.episode.episodeNum}',
                      style: const TextStyle(
                        color: Color(0xFF747B8B),
                        fontSize: 12,
                      ),
                    ),
                    if (widget.progress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(widget.progress! * 100).toInt()}% watched',
                        style: const TextStyle(
                          color: Color(0xFF5A45FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Play icon
              Icon(
                Icons.chevron_right_rounded,
                color: _hovered ? Colors.white : const Color(0xFF747B8B),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
