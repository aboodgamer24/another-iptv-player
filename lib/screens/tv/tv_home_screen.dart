import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/tv_utils.dart';
import 'tv_player_screen.dart';

const _kHomeRowMax = 30;

class TvHomeScreen extends StatefulWidget {
  final String playlistId;
  const TvHomeScreen({super.key, required this.playlistId});
  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  List<ContentItem>? _liveCache;
  List<ContentItem>? _moviesCache;
  List<ContentItem>? _seriesCache;
  String? _liveCatId;
  String? _moviesCatId;
  String? _seriesCatId;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<XtreamCodeHomeController>();

    if (ctrl.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('Loading…', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    // Refresh caches if categories changed
    final liveCatId  = ctrl.liveCategories?.firstOrNull?.category.categoryId;
    final movieCatId = ctrl.movieCategories.firstOrNull?.category.categoryId;
    final seriesCatId = ctrl.seriesCategories.firstOrNull?.category.categoryId;

    if (liveCatId != null && liveCatId != _liveCatId) {
      _liveCatId = liveCatId;
      final all = ctrl.getLiveChannelsByCategory(liveCatId);
      _liveCache = all.take(_kHomeRowMax).toList();
    }
    if (movieCatId != null && movieCatId != _moviesCatId) {
      _moviesCatId = movieCatId;
      final all = ctrl.getMoviesByCategory(movieCatId);
      _moviesCache = all.take(_kHomeRowMax).toList();
    }
    if (seriesCatId != null && seriesCatId != _seriesCatId) {
      _seriesCatId = seriesCatId;
      final all = ctrl.getSeriesByCategory(seriesCatId);
      _seriesCache = all.take(_kHomeRowMax).toList();
    }

    final featured = _liveCache?.firstOrNull ?? _moviesCache?.firstOrNull;

    return CustomScrollView(
      slivers: [
        if (featured != null)
          SliverToBoxAdapter(child: _TvHeroBanner(item: featured)),
        
        if (_liveCache != null && _liveCache!.isNotEmpty)
          SliverToBoxAdapter(
            child: _TvHomeRow(
              title: 'Live TV',
              items: _liveCache!,
              onSelect: _openPlayer,
            ),
          ),

        if (_moviesCache != null && _moviesCache!.isNotEmpty)
          SliverToBoxAdapter(
            child: _TvHomeRow(
              title: 'Recent Movies',
              items: _moviesCache!,
              onSelect: _openPlayer,
            ),
          ),

        if (_seriesCache != null && _seriesCache!.isNotEmpty)
          SliverToBoxAdapter(
            child: _TvHomeRow(
              title: 'Recent Series',
              items: _seriesCache!,
              onSelect: (item, idx, queue) {
                // Navigate to series detail screen if needed, or play first episode
                _openPlayer(item, idx, queue);
              },
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
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

class _TvHeroBanner extends StatelessWidget {
  final ContentItem item;
  const _TvHeroBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, ev) {
        if (ev is! KeyDownEvent) return KeyEventResult.ignored;
        if (ev.logicalKey == LogicalKeyboardKey.arrowLeft) {
          TvNavigation.requestRailFocus(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final f = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => TvPlayerScreen(
                contentItem: item,
                queue: [item],
                initialIndex: 0,
              ),
              transitionDuration: Duration.zero,
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 350,
            margin: const EdgeInsets.fromLTRB(32, 24, 32, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: f ? Border.all(color: Theme.of(ctx).colorScheme.primary, width: 4) : null,
              boxShadow: f ? [BoxShadow(color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 20)] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(item.imageUrl, fit: BoxFit.cover, cacheWidth: 1280),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 32, bottom: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Watch Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TvHomeRow extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final void Function(ContentItem, int, List<ContentItem>) onSelect;

  const _TvHomeRow({required this.title, required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
          child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              return _TvHomeCard(
                item: items[i],
                index: i,
                onTap: () => onSelect(items[i], i, items),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TvHomeCard extends StatelessWidget {
  final ContentItem item;
  final int index;
  final VoidCallback onTap;

  const _TvHomeCard({required this.item, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, ev) {
        if (ev is! KeyDownEvent) return KeyEventResult.ignored;
        if (ev.logicalKey == LogicalKeyboardKey.arrowLeft && index == 0) {
          TvNavigation.requestRailFocus(context);
          return KeyEventResult.handled;
        }
        if (ev.logicalKey == LogicalKeyboardKey.select || ev.logicalKey == LogicalKeyboardKey.enter) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final f = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 220,
            margin: const EdgeInsets.only(right: 16),
            transform: f ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: f ? Theme.of(ctx).colorScheme.primary : Colors.white12, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(item.imageUrl, fit: BoxFit.cover, cacheWidth: 400)
                  : Container(color: Colors.white10, child: const Icon(Icons.tv, color: Colors.white24)),
            ),
          ),
        );
      }),
    );
  }
}
