import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/playlist_content_model.dart';
import 'tv_player_screen.dart';

class TvHomeScreen extends StatelessWidget {
  final String playlistId;
  const TvHomeScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<XtreamCodeHomeController>(context);
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final featured = controller.liveCategories?.isNotEmpty == true
        ? controller
              .getLiveChannelsByCategory(
                controller.liveCategories!.first.category.categoryId,
              )
              .firstOrNull
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured != null) _TvHeroBanner(item: featured),
          const SizedBox(height: 24),
          _TvHomeRow(
            title: 'Live TV',
            items: controller.liveCategories?.isNotEmpty == true
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

class _TvHeroBanner extends StatefulWidget {
  final ContentItem item;
  const _TvHeroBanner({required this.item});

  @override
  State<_TvHeroBanner> createState() => _TvHeroBannerState();
}

class _TvHeroBannerState extends State<_TvHeroBanner> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _activate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvPlayerScreen(
          contentItem: widget.item,
          queue: [widget.item],
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _activate(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _focusNode,
        builder: (context, _) {
          final hasFocus = _focusNode.hasFocus;
          return GestureDetector(
            onTap: () => _activate(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 340,
              decoration: BoxDecoration(
                border: hasFocus
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.item.imagePath.isNotEmpty)
                    Image.network(
                      widget.item.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.black45),
                    ),
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
                          widget.item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: hasFocus
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: hasFocus
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.5),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : [],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Watch Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
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
        },
      ),
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
                      (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                    onSelect(item, i, items);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (ctx) {
                    final hasFocus = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: () => onSelect(item, i, items),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 12),
                        width: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: hasFocus
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                )
                              : Border.all(color: Colors.white12, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: item.imagePath.isNotEmpty
                              ? Image.network(
                                  item.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(
                                      Icons.tv,
                                      color: Colors.white24,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.white10,
                                  child: const Icon(
                                    Icons.tv,
                                    color: Colors.white24,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
