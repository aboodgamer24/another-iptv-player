import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../repositories/iptv_repository.dart';
import '../../models/api_configuration_model.dart';
import '../../services/app_state.dart';
import '../../services/watch_history_service.dart';
import '../../utils/get_playlist_type.dart';
import '../../controllers/favorites_controller.dart';
import '../../controllers/watch_later_controller.dart';
import '../../l10n/localization_extension.dart';
import '../../widgets/player_widget.dart';

class MobileMovieDetailScreen extends StatefulWidget {
  final ContentItem contentItem;

  const MobileMovieDetailScreen({super.key, required this.contentItem});

  @override
  State<MobileMovieDetailScreen> createState() =>
      _MobileMovieDetailScreenState();
}

class _MobileMovieDetailScreenState extends State<MobileMovieDetailScreen> {
  late final WatchHistoryService _watchHistoryService;
  late final IptvRepository? _repository;
  late final FavoritesController _favoritesController;
  late final WatchLaterController _watchLaterController;

  Map<String, dynamic>? _vodInfo;
  bool _isFavorite = false;
  bool _isInWatchLater = false;
  List<ContentItem> _categoryMovies = [];
  bool _isPlotExpanded = false;

  @override
  void initState() {
    super.initState();
    _watchHistoryService = WatchHistoryService();
    _favoritesController = context.read<FavoritesController>();
    _watchLaterController = context.read<WatchLaterController>();

    if (isXtreamCode && AppState.currentPlaylist != null) {
      _repository = IptvRepository(
        ApiConfig(
          baseUrl: AppState.currentPlaylist!.url!,
          username: AppState.currentPlaylist!.username!,
          password: AppState.currentPlaylist!.password!,
        ),
        AppState.currentPlaylist!.id,
      );
    } else {
      _repository = null;
    }

    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadHistory(),
      _loadVodInfo(),
      _loadCategoryMovies(),
      _checkStatus(),
    ]);
  }

  Future<void> _loadHistory() async {
    final playlist = AppState.currentPlaylist;
    if (playlist == null) return;
    try {
      final streamId = isXtreamCode
          ? widget.contentItem.id
          : widget.contentItem.m3uItem?.id ?? widget.contentItem.id;
      await _watchHistoryService.getWatchHistory(
        playlist.id,
        streamId,
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadVodInfo() async {
    if (!isXtreamCode || _repository == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final info = await _repository.getVodInfo(widget.contentItem.id);
      if (mounted) {
        setState(() {
          _vodInfo = info;
        });
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadCategoryMovies() async {
    try {
      if (isXtreamCode && _repository != null) {
        final vod = widget.contentItem.vodStream;
        final categoryId = vod?.categoryId;
        if (categoryId != null) {
          final movies = await _repository.getMovies(categoryId: categoryId);
          if (movies != null && mounted) {
            setState(() {
              _categoryMovies = movies
                  .map(
                    (x) => ContentItem(
                      x.streamId,
                      x.name,
                      x.streamIcon,
                      ContentType.vod,
                      vodStream: x,
                      containerExtension: x.containerExtension,
                    ),
                  )
                  .toList();
            });
          }
        }
      }
    } catch (_) {}
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

  void _openPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: SizedBox.expand(
              child: PlayerWidget(
                contentItem: widget.contentItem,
                queue: _categoryMovies.isNotEmpty ? _categoryMovies : null,
              ),
            ),
          ),
        ),
      ),
    ).then((_) => _loadHistory());
  }

  String? get _posterUrl {
    if (_vodInfo != null) {
      final cover = _vodInfo!['cover_big'] ?? _vodInfo!['cover'];
      if (cover is String && cover.isNotEmpty) return cover;
    }
    return widget.contentItem.imagePath;
  }

  String? get _backdropUrl {
    if (_vodInfo != null) {
      final backdrop = _vodInfo!['backdrop_path'];
      if (backdrop is List && backdrop.isNotEmpty) {
        return backdrop.first.toString();
      }
      if (backdrop is String && backdrop.isNotEmpty) return backdrop;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vod = widget.contentItem.vodStream;
    final metadata = [
      if (_vodInfo != null)
        (_vodInfo!['releaseDate'] ??
            _vodInfo!['release_date'] ??
            _vodInfo!['year']),
      if (vod?.genre != null) vod!.genre,
      if (vod?.rating != null && vod!.rating.isNotEmpty) '⭐ ${vod.rating}',
      if (_vodInfo?['duration'] != null) _vodInfo!['duration'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(' · ');

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
                    imageUrl: _backdropUrl ?? _posterUrl ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey[900]),
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
                    widget.contentItem.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metadata,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openPlayer,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.loc.start_watching),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () async {
                          final result = await _favoritesController
                              .toggleFavorite(widget.contentItem);
                          setState(() => _isFavorite = result);
                        },
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final result = await _watchLaterController
                              .toggleWatchLater(widget.contentItem);
                          setState(() => _isInWatchLater = result);
                        },
                        icon: Icon(
                          _isInWatchLater
                              ? Icons.schedule
                              : Icons.schedule_outlined,
                          color: _isInWatchLater ? Colors.blue : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _isPlotExpanded = !_isPlotExpanded),
                    child: Text(
                      _vodInfo?['plot'] ??
                          widget.contentItem.description ??
                          'No description available.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: _isPlotExpanded ? null : 3,
                      overflow: _isPlotExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isPlotExpanded)
                    TextButton(
                      onPressed: () => setState(() => _isPlotExpanded = true),
                      child: const Text('Read more'),
                    ),
                  if (_vodInfo?['cast'] != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _vodInfo!['cast'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
