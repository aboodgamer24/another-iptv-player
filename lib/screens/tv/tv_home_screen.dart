import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/playlist_content_model.dart';
import 'tv_player_screen.dart';

// Max items shown per home row — prevents building thousands of nodes
const _kHomeRowMax = 30;

class TvHomeScreen extends StatefulWidget {
  final String playlistId;
  const TvHomeScreen({super.key, required this.playlistId});
  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  // Cache the lists so getLive/getMovies are not called on every rebuild
  List<ContentItem>? _liveCache;
  List<ContentItem>? _moviesCache;
  String? _liveCatId;
  String? _moviesCatId;

  @override
  Widget build(BuildContext context) {
    // Use .watch only for the loading flag — avoid rebuilding on every
    // notifyListeners() by reading the controller once and caching results.
    final ctrl = context.watch<XtreamCodeHomeController>();

    if (ctrl.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('Loading…',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    // Compute live row — only when category id changes
    final liveCatId  = ctrl.liveCategories?.firstOrNull?.category.categoryId;
    final movieCatId = ctrl.movieCategories.firstOrNull?.category.categoryId;

    if (liveCatId != null && liveCatId != _liveCatId) {
      _liveCatId   = liveCatId;
      final all    = ctrl.getLiveChannelsByCategory(liveCatId);
      _liveCache   = all.length > _kHomeRowMax ? all.sublist(0, _kHomeRowMax) : all;
    }
    if (movieCatId != null && movieCatId != _moviesCatId) {
      _moviesCatId = movieCatId;
      final all    = ctrl.getMoviesByCategory(movieCatId);
      _moviesCache = all.length > _kHomeRowMax ? all.sublist(0, _kHomeRowMax) : all;
    }

    final featured = _liveCache?.firstOrNull;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured != null) _TvHeroBanner(item: featured),
          const SizedBox(height: 24),
          if (_liveCache != null && _liveCache!.isNotEmpty)
            _TvHomeRow(
              title: 'Live TV',
              items: _liveCache!,
              onSelect: _openPlayer,
            ),
          if (_moviesCache != null && _moviesCache!.isNotEmpty)
            _TvHomeRow(
              title: 'Movies',
              items: _moviesCache!,
              onSelect: _openPlayer,
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openPlayer(ContentItem item, int idx, List<ContentItem> queue) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            TvPlayerScreen(contentItem: item, queue: queue, initialIndex: idx),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

// ── Hero banner ──────────────────────────────────────────────────────────────
class _TvHeroBanner extends StatefulWidget {
  final ContentItem item;
  const _TvHeroBanner({required this.item});
  @override
  State<_TvHeroBanner> createState() => _TvHeroBannerState();
}

class _TvHeroBannerState extends State<_TvHeroBanner> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _open() => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => TvPlayerScreen(
        contentItem: widget.item,
        queue: [widget.item],
        initialIndex: 0,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, ev) {
        if (ev is KeyDownEvent &&
            (ev.logicalKey == LogicalKeyboardKey.select  ||
             ev.logicalKey == LogicalKeyboardKey.enter   ||
             ev.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _open();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _focus,
        builder: (ctx, _) {
          final f = _focus.hasFocus;
          return GestureDetector(
            onTap: _open,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 300,
              decoration: BoxDecoration(
                border: f
                    ? Border.all(
                        color: Theme.of(ctx).colorScheme.primary, width: 3)
                    : null,
              ),
              child: Stack(fit: StackFit.expand, children: [
                if (widget.item.imagePath.isNotEmpty)
                  Image.network(
                    widget.item.imagePath,
                    fit: BoxFit.cover,
                    // Limit decode size — we don't need 4K hero image
                    cacheWidth: 1280,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.black45)),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned(
                  left: 48, bottom: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 32,
                          fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 11),
                        decoration: BoxDecoration(
                          color: f
                              ? Theme.of(ctx).colorScheme.primaryContainer
                              : Theme.of(ctx).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Watch Now',
                              style: TextStyle(color: Colors.white, fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Horizontal row ────────────────────────────────────────────────────────────
class _TvHomeRow extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final void Function(ContentItem, int, List<ContentItem>) onSelect;

  const _TvHomeRow({
    required this.title,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
          child: Text(title,
            style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            // addRepaintBoundaries: true (default) isolates each card paint
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Focus(
                onKeyEvent: (_, ev) {
                  if (ev is KeyDownEvent &&
                      (ev.logicalKey == LogicalKeyboardKey.select  ||
                       ev.logicalKey == LogicalKeyboardKey.enter   ||
                       ev.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                    onSelect(item, i, items);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(builder: (ctx) {
                  final f = Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: () => onSelect(item, i, items),
                    child: RepaintBoundary(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        margin: const EdgeInsets.only(right: 12),
                        width: 190,
                        // scale-up on focus instead of border for perf
                        transform: f
                            ? Matrix4.diagonal3Values(1.06, 1.06, 1.0)
                            : Matrix4.identity(),
                        transformAlignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: f
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.white12,
                            width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: item.imagePath.isNotEmpty
                              ? Image.network(
                                  item.imagePath,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300, // decode at display size
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: Colors.white10,
                                        child: const Icon(Icons.tv,
                                          color: Colors.white24)))
                              : Container(color: Colors.white10,
                                  child: const Icon(Icons.tv,
                                    color: Colors.white24)),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
