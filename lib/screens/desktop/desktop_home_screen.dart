import 'package:c4tv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:c4tv_player/controllers/favorites_controller.dart';
import 'package:c4tv_player/controllers/watch_history_controller.dart';
import 'package:c4tv_player/models/content_type.dart';
import 'package:c4tv_player/models/favorite.dart';
import 'package:c4tv_player/models/playlist_content_model.dart';
import 'package:c4tv_player/models/watch_history.dart';
import 'package:c4tv_player/utils/navigate_by_content_type.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Desktop Home / Dashboard showing Continue Watching, Recently Viewed
/// channels, and Favorites.
class DesktopHomeScreen extends StatefulWidget {
  final String playlistId;

  const DesktopHomeScreen({super.key, required this.playlistId});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  late WatchHistoryController _historyController;
  late FavoritesController _favoritesController;

  @override
  void initState() {
    super.initState();
    _historyController = WatchHistoryController();
    _favoritesController = FavoritesController();
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: _historyController.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5A45FF)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.loc.history,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Continue Watching
                  if (_historyController.continueWatching.isNotEmpty) ...[
                    _buildSectionTitle(
                      context.loc.continue_watching,
                      Icons.play_circle,
                    ),
                    const SizedBox(height: 12),
                    _buildContinueWatchingRow(),
                    const SizedBox(height: 32),
                  ],

                  // Recently Viewed Channels
                  if (_historyController.liveHistory.isNotEmpty) ...[
                    _buildSectionTitle(
                      'Recently Viewed Channels',
                      Icons.history_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildRecentChannelsRow(),
                    const SizedBox(height: 32),
                  ],

                  // Recently Watched Movies
                  if (_historyController.movieHistory.isNotEmpty) ...[
                    _buildSectionTitle('Recent Movies', Icons.movie_rounded),
                    const SizedBox(height: 12),
                    _buildHistoryRow(_historyController.movieHistory),
                    const SizedBox(height: 32),
                  ],

                  // Recently Watched Series
                  if (_historyController.seriesHistory.isNotEmpty) ...[
                    _buildSectionTitle('Recent Series', Icons.tv_rounded),
                    const SizedBox(height: 12),
                    _buildHistoryRow(_historyController.seriesHistory),
                    const SizedBox(height: 32),
                  ],

                  // Favorite Channels
                  if (_favoritesController.liveStreamFavorites.isNotEmpty) ...[
                    _buildSectionTitle(
                      'Favorite Channels',
                      Icons.favorite_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildFavoritesRow(
                      _favoritesController.liveStreamFavorites,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Empty state
                  if (_historyController.isAllEmpty &&
                      _favoritesController.favorites.isEmpty) ...[
                    const SizedBox(height: 80),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1A1D24),
                            ),
                            child: const Icon(
                              Icons.tv_rounded,
                              color: Color(0xFF747B8B),
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Start watching to see your history here',
                            style: TextStyle(
                              color: Color(0xFF747B8B),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF5A45FF), size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatchingRow() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _historyController.continueWatching.length,
        itemBuilder: (context, index) {
          final item = _historyController.continueWatching[index];
          return _ContinueWatchingCard(
            history: item,
            onTap: () => _historyController.playContent(context, item),
          );
        },
      ),
    );
  }

  Widget _buildRecentChannelsRow() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _historyController.liveHistory.take(15).length,
        itemBuilder: (context, index) {
          final item = _historyController.liveHistory[index];
          return _RecentChannelCard(
            history: item,
            onTap: () => _historyController.playContent(context, item),
          );
        },
      ),
    );
  }

  Widget _buildHistoryRow(List<WatchHistory> items) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.take(15).length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _HistoryCard(
            history: item,
            onTap: () => _historyController.playContent(context, item),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesRow(List<Favorite> items) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.take(15).length,
        itemBuilder: (context, index) {
          final fav = items[index];
          return _FavoriteChannelCard(favorite: fav);
        },
      ),
    );
  }
}

// ─── Cards ────────────────────────────────────────

class _ContinueWatchingCard extends StatefulWidget {
  final WatchHistory history;
  final VoidCallback onTap;

  const _ContinueWatchingCard({required this.history, required this.onTap});

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  bool _hovered = false;

  double? get _progress {
    final h = widget.history;
    if (h.watchDuration == null || h.totalDuration == null) return null;
    final total = h.totalDuration!.inMilliseconds;
    if (total <= 0) return null;
    return (h.watchDuration!.inMilliseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF13161C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2128)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.history.imagePath != null &&
                              widget.history.imagePath!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.history.imagePath!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _fallbackIcon(widget.history.contentType),
                            )
                          : _fallbackIcon(widget.history.contentType),
                      if (_hovered)
                        Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Progress bar
                if (progress != null)
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: const Color(0xFF1E2128),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF5A45FF)),
                  ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.history.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentChannelCard extends StatefulWidget {
  final WatchHistory history;
  final VoidCallback onTap;

  const _RecentChannelCard({required this.history, required this.onTap});

  @override
  State<_RecentChannelCard> createState() => _RecentChannelCardState();
}

class _RecentChannelCardState extends State<_RecentChannelCard> {
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
          width: 200,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0E14),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    widget.history.imagePath != null &&
                        widget.history.imagePath!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.history.imagePath!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.tv,
                          color: Colors.white38,
                          size: 24,
                        ),
                      )
                    : const Icon(Icons.tv, color: Colors.white38, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.history.title,
                  style: TextStyle(
                    color: _hovered ? Colors.white : const Color(0xFFA0A5B5),
                    fontSize: 13,
                    fontWeight: _hovered ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final WatchHistory history;
  final VoidCallback onTap;

  const _HistoryCard({required this.history, required this.onTap});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF13161C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2128)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.history.imagePath != null &&
                              widget.history.imagePath!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.history.imagePath!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _fallbackIcon(widget.history.contentType),
                            )
                          : _fallbackIcon(widget.history.contentType),
                      if (_hovered)
                        Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    widget.history.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteChannelCard extends StatefulWidget {
  final Favorite favorite;

  const _FavoriteChannelCard({required this.favorite});

  @override
  State<_FavoriteChannelCard> createState() => _FavoriteChannelCardState();
}

class _FavoriteChannelCardState extends State<_FavoriteChannelCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Navigate to content
          navigateByContentType(
            context,
            ContentItem(
              widget.favorite.streamId,
              widget.favorite.name,
              widget.favorite.imagePath ?? '',
              widget.favorite.contentType,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 180,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0E14),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    widget.favorite.imagePath != null &&
                        widget.favorite.imagePath!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.favorite.imagePath!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.tv,
                          color: Colors.white38,
                          size: 20,
                        ),
                      )
                    : const Icon(Icons.tv, color: Colors.white38, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.favorite.name,
                  style: TextStyle(
                    color: _hovered ? Colors.white : const Color(0xFFA0A5B5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.favorite, color: Colors.red.shade400, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _fallbackIcon(ContentType type) {
  IconData icon;
  switch (type) {
    case ContentType.liveStream:
      icon = Icons.live_tv_rounded;
      break;
    case ContentType.vod:
      icon = Icons.movie_rounded;
      break;
    case ContentType.series:
      icon = Icons.tv_rounded;
      break;
  }
  return Container(
    color: const Color(0xFF0F1115),
    child: Center(child: Icon(icon, size: 32, color: const Color(0xFF262A35))),
  );
}
