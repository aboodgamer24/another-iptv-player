import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/screens/tv/tv_exo_player_screen.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/watch_later_controller.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:provider/provider.dart';

class TvSeriesDetailScreen extends StatefulWidget {
  final ContentItem contentItem;

  const TvSeriesDetailScreen({super.key, required this.contentItem});

  @override
  State<TvSeriesDetailScreen> createState() => _TvSeriesDetailScreenState();
}

class _TvSeriesDetailScreenState extends State<TvSeriesDetailScreen> {
  late FavoritesController _favoritesController;
  late WatchLaterController _watchLaterController;
  late IptvRepository _repository;
  late WatchHistoryService _watchHistoryService;

  bool _isFavorite = false;
  bool _isInWatchLater = false;
  bool _isLoading = true;
  String? _error;

  SeriesInfosData? _seriesInfo;
  List<SeasonsData> _seasons = [];
  List<EpisodesData> _episodes = [];
  EpisodesData? _lastOpenedEpisode;
  
  int _selectedSeasonIndex = 0;

  final FocusNode _playNode = FocusNode(debugLabel: 'series-play');
  final FocusNode _watchLaterNode = FocusNode(debugLabel: 'series-wl');
  final FocusNode _favoriteNode = FocusNode(debugLabel: 'series-fav');

  @override
  void initState() {
    super.initState();
    _favoritesController = context.read<FavoritesController>();
    _watchLaterController = context.read<WatchLaterController>();
    _watchHistoryService = WatchHistoryService();
    
    _repository = IptvRepository(
      ApiConfig(
        baseUrl: AppState.currentPlaylist!.url!,
        username: AppState.currentPlaylist!.username!,
        password: AppState.currentPlaylist!.password!,
      ),
      AppState.currentPlaylist!.id,
    );
    
    _checkStatus();
    _loadSeriesDetails();
  }

  @override
  void dispose() {
    _playNode.dispose();
    _watchLaterNode.dispose();
    _favoriteNode.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final fav = await _favoritesController.isFavorite(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );
    final wl = await _watchLaterController.isWatchLater(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );

    if (mounted) {
      setState(() {
        _isFavorite = fav;
        _isInWatchLater = wl;
      });
    }
  }
  
  Future<void> _loadSeriesDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final seriesResponse = await _repository.getSeriesInfo(widget.contentItem.id);

      if (seriesResponse != null) {
        if (mounted) {
          setState(() {
            _seriesInfo = seriesResponse.seriesInfo;
            _seasons = seriesResponse.seasons;
            _episodes = seriesResponse.episodes;
            _isLoading = false;
          });
        }
        await _loadLastOpenedEpisodeFromHistory();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _playNode.requestFocus();
        });
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load series details.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadLastOpenedEpisodeFromHistory() async {
    if (_episodes.isEmpty) return;

    final playlistId = AppState.currentPlaylist!.id;
    final allSeriesHistory = await _watchHistoryService.getWatchHistoryByContentType(ContentType.series, playlistId);

    if (!mounted || allSeriesHistory.isEmpty) return;

    final Map<String, EpisodesData> byId = {
      for (final ep in _episodes) ep.episodeId.toString(): ep,
    };

    EpisodesData? matched;
    for (final history in allSeriesHistory) {
      final ep = byId[history.streamId];
      if (ep != null) {
        matched = ep;
        break;
      }
    }

    if (matched != null && mounted) {
      setState(() {
        _lastOpenedEpisode = matched;
        
        // Auto-select the season that contains the last opened episode
        final seasonIndex = _seasons.indexWhere((s) => s.seasonNumber == matched!.season);
        if (seasonIndex != -1) {
          _selectedSeasonIndex = seasonIndex;
        }
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesController.toggleFavorite(widget.contentItem);
    if (mounted) setState(() => _isFavorite = result);
  }

  Future<void> _toggleWatchLater() async {
    final result = await _watchLaterController.toggleWatchLater(widget.contentItem);
    if (mounted) setState(() => _isInWatchLater = result);
  }

  void _playEpisode(EpisodesData episode) {
    setState(() {
      _lastOpenedEpisode = episode;
    });
    
    final queue = _episodes.map((e) => ContentItem(
      e.episodeId,
      e.title,
      e.movieImage ?? widget.contentItem.imagePath,
      ContentType.series,
      containerExtension: e.containerExtension,
      season: e.season,
      seriesStream: widget.contentItem.seriesStream,
    )).toList();

    final currentIndex = _episodes.indexWhere((e) => e.episodeId == episode.episodeId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvExoPlayerScreen(
          contentItem: queue[currentIndex],
          queue: queue,
          currentIndex: currentIndex,
        ),
      ),
    );
  }

  void _playMainAction() {
    if (_lastOpenedEpisode != null) {
      _playEpisode(_lastOpenedEpisode!);
    } else if (_episodes.isNotEmpty) {
      // Play first episode
      final firstEp = _episodes.firstWhere(
        (e) => e.season == _seasons[_selectedSeasonIndex].seasonNumber,
        orElse: () => _episodes.first,
      );
      _playEpisode(firstEp);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1014),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1014),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadSeriesDetails, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final validSeasons = _seasons.where((season) => _episodes.any((episode) => episode.season == season.seasonNumber)).toList();
    final currentSeason = validSeasons.isNotEmpty && _selectedSeasonIndex < validSeasons.length ? validSeasons[_selectedSeasonIndex] : null;
    final seasonEpisodes = currentSeason != null ? _episodes.where((e) => e.season == currentSeason.seasonNumber).toList() : <EpisodesData>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.backspace) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
          // Background Image with Gradient
          Positioned.fill(
            child: widget.contentItem.imagePath.isNotEmpty
                ? Image.network(
                    widget.contentItem.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF0F1014).withValues(alpha: 0.95),
                    const Color(0xFF0F1014).withValues(alpha: 0.8),
                    const Color(0xFF0F1014).withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0F1014),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: Row(
              children: [
                // Left Column (Details & Buttons)
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 64, top: 64, bottom: 64, right: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: widget.contentItem.id,
                          child: Text(
                            _seriesInfo?.name ?? widget.contentItem.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('SERIES', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            if (_seriesInfo?.genre != null)
                              Text(_seriesInfo!.genre!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                        if (_seriesInfo?.plot != null && _seriesInfo!.plot!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            _seriesInfo!.plot!,
                            style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
                        
                        // Action Buttons
                        FocusTraversalGroup(
                          child: Row(
                            children: [
                              _buildButton(
                                focusNode: _playNode,
                                icon: Icons.play_arrow_rounded,
                                label: _lastOpenedEpisode != null 
                                    ? context.loc.continue_watching_label(_lastOpenedEpisode!.season.toString(), _lastOpenedEpisode!.episodeNum.toString())
                                    : context.loc.start_watching,
                                onPressed: _playMainAction,
                                isPrimary: true,
                              ),
                              const SizedBox(width: 16),
                              _buildButton(
                                focusNode: _watchLaterNode,
                                icon: _isInWatchLater ? Icons.watch_later : Icons.watch_later_outlined,
                                label: 'Watch Later',
                                onPressed: _toggleWatchLater,
                              ),
                              const SizedBox(width: 16),
                              _buildButton(
                                focusNode: _favoriteNode,
                                icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                                label: 'Favorite',
                                onPressed: _toggleFavorite,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Column (Seasons & Episodes)
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64, bottom: 64, right: 64, left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Seasons', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        // Seasons List
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: validSeasons.length,
                            itemBuilder: (context, index) {
                              final season = validSeasons[index];
                              final isSelected = _selectedSeasonIndex == index;
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Focus(
                                  onFocusChange: (focused) {
                                    if (focused) setState(() => _selectedSeasonIndex = index);
                                  },
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedSeasonIndex = index),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : Colors.white10,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Center(
                                        child: Text(
                                          season.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        Text(currentSeason?.name ?? 'Episodes', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        // Episodes List
                        Expanded(
                          child: ListView.builder(
                            itemCount: seasonEpisodes.length,
                            itemBuilder: (context, index) {
                              final episode = seasonEpisodes[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
                                      _playEpisode(episode);
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      final isFocused = Focus.of(context).hasFocus;
                                      return GestureDetector(
                                        onTap: () => _playEpisode(episode),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isFocused ? Colors.white : Colors.white10,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 120,
                                                height: 68,
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: episode.movieImage != null && episode.movieImage!.isNotEmpty
                                                    ? ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.network(episode.movieImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Colors.white24)),
                                                      )
                                                    : const Icon(Icons.play_circle_outline, color: Colors.white24, size: 32),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Episode ${episode.episodeNum}',
                                                      style: TextStyle(
                                                        color: isFocused ? Colors.black54 : Colors.white54,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      episode.title,
                                                      style: TextStyle(
                                                        color: isFocused ? Colors.black : Colors.white,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isFocused)
                                                const Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) => setState(() {}),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: focusNode.hasFocus 
                ? Colors.white 
                : (isPrimary ? Theme.of(context).colorScheme.primary : Colors.white10),
            borderRadius: BorderRadius.circular(8),
            border: focusNode.hasFocus ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: focusNode.hasFocus 
                    ? Colors.black 
                    : (isPrimary ? Colors.white : Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: focusNode.hasFocus 
                      ? Colors.black 
                      : (isPrimary ? Colors.white : Colors.white),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
