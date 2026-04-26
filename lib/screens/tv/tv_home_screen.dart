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

    final hasData = (_liveCache != null && _liveCache!.isNotEmpty) ||
                    (_moviesCache != null && _moviesCache!.isNotEmpty) ||
                    (_seriesCache != null && _seriesCache!.isNotEmpty);

    if (ctrl.isLoading && !hasData) {
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

    // Refresh caches if categories changed or if we had no data before
    final liveCatId  = ctrl.liveCategories?.firstOrNull?.category.categoryId;
    final movieCatId = ctrl.movieCategories.firstOrNull?.category.categoryId;
    final seriesCatId = ctrl.seriesCategories.firstOrNull?.category.categoryId;

    if (liveCatId != null && (liveCatId != _liveCatId || _liveCache == null || _liveCache!.isEmpty)) {
      _liveCatId = liveCatId;
      final all = ctrl.getLiveChannelsByCategory(liveCatId);
      _liveCache = all.take(_kHomeRowMax).toList();
    }
    if (movieCatId != null && (movieCatId != _moviesCatId || _moviesCache == null || _moviesCache!.isEmpty)) {
      _moviesCatId = movieCatId;
      final all = ctrl.getMoviesByCategory(movieCatId);
      _moviesCache = all.take(_kHomeRowMax).toList();
    }
    if (seriesCatId != null && (seriesCatId != _seriesCatId || _seriesCache == null || _seriesCache!.isEmpty)) {
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
    final primary = Theme.of(context).colorScheme.primary;
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
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: f ? 1.02 : 1.0,
            child: Container(
              height: 380,
              margin: const EdgeInsets.fromLTRB(32, 24, 32, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: f ? primary : Colors.white10, width: 2),
                boxShadow: f ? [BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 25)] : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(item.imageUrl, fit: BoxFit.cover, cacheWidth: 1280),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.black.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 40, bottom: 40, right: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('FEATURED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                          const SizedBox(height: 12),
                          Text(item.name, 
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _TvHeroButton(
                                label: 'Watch Now',
                                icon: Icons.play_arrow_rounded,
                                color: primary,
                                isFocused: f,
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
          ),
        );
      }),
    );
  }
}

class _TvHeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isFocused;

  const _TvHeroButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isFocused ? Colors.white : Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isFocused ? Colors.black : Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: isFocused ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          )),
        ],
      ),
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
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
          child: Text(title, style: const TextStyle(
            color: Colors.white, 
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          )),
        ),
        SizedBox(
          height: 180,
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
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      onKeyEvent: (_, ev) {
        if (ev is! KeyDownEvent) return KeyEventResult.ignored;
        if (ev.logicalKey == LogicalKeyboardKey.arrowLeft && index == 0) {
          TvNavigation.requestRailFocus(context);
          return KeyEventResult.handled;
        }
        if (ev.logicalKey == LogicalKeyboardKey.select || 
            ev.logicalKey == LogicalKeyboardKey.enter ||
            ev.logicalKey == LogicalKeyboardKey.gameButtonA) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final f = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: f ? 1.06 : 1.0,
            curve: Curves.easeOut,
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: f ? primary : Colors.transparent, width: 2.5),
                boxShadow: f ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 15)] : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl.isNotEmpty)
                    Image.network(item.imageUrl, fit: BoxFit.cover, cacheWidth: 500)
                  else
                    Container(color: Colors.white.withValues(alpha: 0.05), child: const Icon(Icons.tv, color: Colors.white12, size: 40)),
                  
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        item.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
