import 'dart:ui';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/watch_later_controller.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/widgets/player_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Desktop-optimized movie detail page with large backdrop,
/// poster + metadata side-by-side, play/favorite/progress.
class DesktopMovieDetailScreen extends StatefulWidget {
  final ContentItem contentItem;

  const DesktopMovieDetailScreen({super.key, required this.contentItem});

  @override
  State<DesktopMovieDetailScreen> createState() =>
      _DesktopMovieDetailScreenState();
}

class _DesktopMovieDetailScreenState extends State<DesktopMovieDetailScreen> {
  late final WatchHistoryService _watchHistoryService;
  late final IptvRepository? _repository;
  late final FavoritesController _favoritesController;
  late final WatchLaterController _watchLaterController;

  WatchHistory? _watchHistory;
  Map<String, dynamic>? _vodInfo;
  bool _isFavorite = false;
  bool _isInWatchLater = false;
  List<ContentItem> _categoryMovies = [];

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
      final history = await _watchHistoryService.getWatchHistory(
        playlist.id,
        streamId,
      );
      if (mounted) {
        setState(() {
          _watchHistory = history;
        });
      }
    } catch (_) {
      // Watch history load failed silently
    }
  }

  Future<void> _loadVodInfo() async {
    if (!isXtreamCode || _repository == null) {
      return;
    }
    try {
      final info = await _repository.getVodInfo(widget.contentItem.id);
      if (mounted) {
        setState(() {
          _vodInfo = info;
        });
      }
    } catch (_) {}
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
    } catch (e) {
      debugPrint('Error loading category movies: $e');
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

  double? get _progress {
    final h = _watchHistory;
    if (h?.watchDuration == null || h?.totalDuration == null) return null;
    final total = h!.totalDuration!.inMilliseconds;
    if (total <= 0) return null;
    return (h.watchDuration!.inMilliseconds / total).clamp(0.0, 1.0);
  }

  String? get _posterUrl {
    if (_vodInfo != null) {
      final cover = _vodInfo!['cover_big'] ?? _vodInfo!['cover'];
      if (cover is String && cover.isNotEmpty) return cover;
    }
    if (widget.contentItem.coverPath?.isNotEmpty == true) {
      return widget.contentItem.coverPath;
    }
    if (widget.contentItem.imagePath.isNotEmpty) {
      return widget.contentItem.imagePath;
    }
    return widget.contentItem.vodStream?.streamIcon;
  }

  String? get _backdropUrl {
    if (_vodInfo != null) {
      final backdrop = _vodInfo!['backdrop_path'];
      if (backdrop is List && backdrop.isNotEmpty) {
        return backdrop.first.toString();
      } else if (backdrop is String && backdrop.isNotEmpty) {
        return backdrop;
      }
    }
    return null;
  }

  String? get _plot {
    if (_vodInfo != null) {
      final p = _vodInfo!['plot'];
      if (p is String && p.isNotEmpty) return p;
    }
    return widget.contentItem.description?.trim();
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
    ).then((_) {
      _loadHistory(); // Refresh after playback
    });
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop
          _buildBackdrop(),
          // Content
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
              bottom: 40,
              left: 48,
              right: 48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster
                    _buildPoster(),
                    const SizedBox(width: 40),
                    // Details
                    Expanded(child: _buildDetails()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    final url = _backdropUrl ?? _posterUrl;
    if (url == null) return Container(color: const Color(0xFF0B0E14));

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              Container(color: const Color(0xFF0B0E14)),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.black.withValues(alpha: 0.7)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                const Color(0xFF0B0E14).withValues(alpha: 0.9),
                const Color(0xFF0B0E14),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoster() {
    final url = _posterUrl;
    return Container(
      height: 450,
      width: 300,
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
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Icon(Icons.movie, size: 50, color: Colors.grey),
                ),
              )
            : Container(
                color: const Color(0xFF1E1E1E),
                child: const Icon(Icons.movie, size: 50, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildDetails() {
    final progress = _progress;
    final vod = widget.contentItem.vodStream;
    final genre = vod?.genre ?? (_vodInfo != null ? _vodInfo!['genre'] : null);
    final director = _vodInfo != null ? _vodInfo!['director'] : null;
    final cast = _vodInfo != null ? _vodInfo!['cast'] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          widget.contentItem.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Rating + favorite
        Row(
          children: [
            if (vod != null &&
                double.tryParse(vod.rating.trim()) != null &&
                double.parse(vod.rating.trim()) > 0) ...[
              Icon(Icons.star_rounded, color: Colors.amber.shade500, size: 22),
              const SizedBox(width: 4),
              Text(
                '${double.parse(vod.rating.trim()).toStringAsFixed(1)}/10',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 20),
            ],
            if (genre is String && genre.isNotEmpty) ...[
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
              const SizedBox(width: 12),
            ],
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
        const SizedBox(height: 20),

        // Play button + progress
        if (progress != null && progress > 0.01 && progress < 0.98) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFF1E2128),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF5A45FF)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDuration(_watchHistory!.watchDuration!)} / ${_formatDuration(_watchHistory!.totalDuration!)}',
            style: const TextStyle(color: Color(0xFF747B8B), fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: 220,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openPlayer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A45FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(
              progress != null && progress > 0.01
                  ? context.loc.continue_watching
                  : context.loc.start_watching,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Plot
        if (_plot != null && _plot!.isNotEmpty) ...[
          const Text(
            'Synopsis',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _plot!,
            style: const TextStyle(
              color: Color(0xFFA0A5B5),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Director + Cast
        if (director is String && director.isNotEmpty)
          _buildInfoRow('Director', director),
        if (cast is String && cast.isNotEmpty) _buildInfoRow('Cast', cast),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF747B8B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFA0A5B5), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final buf = StringBuffer();
    if (h > 0) buf.write('${h.toString().padLeft(2, '0')}:');
    buf.write('${m.toString().padLeft(2, '0')}:');
    buf.write(s.toString().padLeft(2, '0'));
    return buf.toString();
  }
}
