import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/playlist_content_model.dart';
import '../../services/tv_focus_service.dart';

class TvContentGrid extends StatefulWidget {
  final String sectionKey;
  final List<ContentItem> items;
  final void Function(ContentItem item, int index, List<ContentItem> queue)
  onSelect;
  final int crossAxisCount;

  const TvContentGrid({
    super.key,
    required this.sectionKey,
    required this.items,
    required this.onSelect,
    this.crossAxisCount = 5,
  });

  @override
  State<TvContentGrid> createState() => _TvContentGridState();
}

class _TvContentGridState extends State<TvContentGrid> {
  late ScrollController _scrollController;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusedIndex = TvFocusService.instance.getLastIndex(widget.sectionKey);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final row = (index / widget.crossAxisCount).floor();
    final cardHeight = 180.0; // approximate
    final target = row * cardHeight;
    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodes = TvFocusService.instance.getNodes(
      widget.sectionKey,
      widget.items.length,
    );

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2 / 3,
      ),
      itemCount: widget.items.length,
      itemBuilder: (ctx, i) {
        final item = widget.items[i];
        return Focus(
          focusNode: nodes[i],
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              setState(() => _focusedIndex = i);
              TvFocusService.instance.saveIndex(widget.sectionKey, i);
              _scrollToIndex(i);
            }
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.select) {
              widget.onSelect(item, i, widget.items);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () => widget.onSelect(item, i, widget.items),
            child: _TvContentCard(item: item, isFocused: _focusedIndex == i),
          ),
        );
      },
    );
  }
}

class _TvContentCard extends StatelessWidget {
  final ContentItem item;
  final bool isFocused;

  const _TvContentCard({required this.item, required this.isFocused});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isFocused ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: isFocused
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : Border.all(color: Colors.white12, width: 1),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              item.imagePath.isNotEmpty
                  ? Image.network(
                      item.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey,
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey,
                      child: const Icon(
                        Icons.movie,
                        color: Colors.white24,
                        size: 40,
                      ),
                    ),
              // Bottom gradient + title
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
