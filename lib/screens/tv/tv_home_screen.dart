import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/playlist_content_model.dart';
import 'tv_player_screen.dart';
import 'package:flutter/services.dart';

class TvHomeScreen extends StatelessWidget {
  final String playlistId;
  const TvHomeScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<XtreamCodeHomeController>(context);
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Pick a random featured item from live channels
    final featured = controller.liveCategories?.isNotEmpty == true
        ? controller.getLiveChannelsByCategory(
            controller.liveCategories!.first.category.categoryId,
          ).firstOrNull
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          if (featured != null) _TvHeroBanner(item: featured),
          const SizedBox(height: 24),
          // Rows
          _TvHomeRow(
            title: 'Live TV',
            items: controller.liveCategories != null && controller.liveCategories!.isNotEmpty
                ? controller.getLiveChannelsByCategory(
                    controller.liveCategories!.first.category.categoryId,
                  )
                : [],
            onSelect: (item, idx, queue) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TvPlayerScreen(
                  contentItem: item,
                  queue: queue,
                  initialIndex: idx,
                ),
              ),
            ),
          ),
          _TvHomeRow(
            title: 'Movies',
            items: controller.movieCategories.isNotEmpty
                ? controller.getMoviesByCategory(
                    controller.movieCategories.first.category.categoryId,
                  )
                : [],
            onSelect: (item, idx, queue) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TvPlayerScreen(
                  contentItem: item,
                  queue: queue,
                  initialIndex: idx,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
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
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TvPlayerScreen(
                contentItem: item,
                queue: [item],
                initialIndex: 0,
              ),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 340,
            decoration: BoxDecoration(
              border: hasFocus
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.imagePath.isNotEmpty)
                  Image.network(item.imagePath, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.black45)),
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
                  left: 48,
                  bottom: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Watch Now',
                                style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  const _TvHomeRow({
    required this.title,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.select) {
                    onSelect(item, i, items);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(builder: (ctx) {
                  final hasFocus = Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: () => onSelect(item, i, items),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                        transform: hasFocus
                            ? (Matrix4.diagonal3Values(1.07, 1.07, 1.0))
                            : Matrix4.identity(),
                      margin: const EdgeInsets.only(right: 12),
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: hasFocus
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : Border.all(color: Colors.white12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: item.imagePath.isNotEmpty
                            ? Image.network(item.imagePath, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey, child: const Icon(Icons.tv, color: Colors.white24)))
                            : Container(
                                color: Colors.grey,
                                child: const Icon(Icons.tv, color: Colors.white24),
                              ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
