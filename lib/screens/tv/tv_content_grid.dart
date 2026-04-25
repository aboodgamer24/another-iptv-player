import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/playlist_content_model.dart';

class TvContentGrid extends StatefulWidget {
  final String sectionKey;
  final List<ContentItem> items;
  final void Function(ContentItem item, int index, List<ContentItem> queue)
      onSelect;
  final int crossAxisCount;
  final VoidCallback? onEdgeLeft;

  const TvContentGrid({
    super.key,
    required this.sectionKey,
    required this.items,
    required this.onSelect,
    this.crossAxisCount = 5,
    this.onEdgeLeft,
  });

  @override
  State<TvContentGrid> createState() => _TvContentGridState();
}

class _TvContentGridState extends State<TvContentGrid> {
  late ScrollController _scrollController;
  int _focusedIndex = 0;
  final Map<int, FocusNode> _focusNodePool = {};

  @override
  void initState() {
    super.initState();
    _focusedIndex = 0;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    for (final node in _focusNodePool.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  FocusNode _getFocusNode(int index) {
    if (!_focusNodePool.containsKey(index)) {
      _focusNodePool[index] = FocusNode();
    }
    return _focusNodePool[index]!;
  }

  void _ensureVisible(BuildContext context) {
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            _focusedIndex % widget.crossAxisCount == 0) {
          widget.onEdgeLeft?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(32),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2 / 3,
        ),
        itemCount: widget.items.length,
        itemBuilder: (ctx, i) {
          final item = widget.items[i];
          final node = _getFocusNode(i);
          return Focus(
            focusNode: node,
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                setState(() => _focusedIndex = i);
                _ensureVisible(node.context!);
              }
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
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
      ),
    );
  }
}

class _TvContentCard extends StatelessWidget {
  final ContentItem item;
  final bool isFocused;

  const _TvContentCard({required this.item, required this.isFocused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isFocused
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
            : Border.all(color: Colors.transparent, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image
            item.imagePath.isNotEmpty
                ? Image.network(
                    item.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white10,
                      child: const Icon(
                        Icons.movie,
                        color: Colors.white24,
                        size: 40,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.white10,
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
    );
  }
}
