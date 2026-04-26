import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/tv_utils.dart';

class TvContentGrid extends StatefulWidget {
  final String sectionKey;
  final List<ContentItem> items;
  final void Function(ContentItem item, int index, List<ContentItem> queue) onSelect;
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
  int _focusedIndex = 0;
  final Map<int, FocusNode> _nodes = {};
  final ScrollController _scroll = ScrollController();

  FocusNode _node(int i) => _nodes.putIfAbsent(i, () => FocusNode());

  @override
  void didUpdateWidget(TvContentGrid old) {
    super.didUpdateWidget(old);
    if (old.sectionKey != widget.sectionKey) {
      setState(() => _focusedIndex = 0);
      for (final n in _nodes.values) {
        n.dispose();
      }
      _nodes.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node(0).requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      // ReadingOrderTraversalPolicy keeps traversal INSIDE the group
      // and does NOT bubble out when hitting the edge — we handle edges manually
      policy: ReadingOrderTraversalPolicy(),
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(32),
        primary: false,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2 / 3,
        ),
        itemCount: widget.items.length,
        itemBuilder: (ctx, i) {
          final item = widget.items[i];
          final node = _node(i);
          final col  = i % widget.crossAxisCount;

          return Focus(
            focusNode: node,
            onFocusChange: (has) {
              if (has) {
                if (_focusedIndex != i) setState(() => _focusedIndex = i);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (node.context != null && mounted) {
                    Scrollable.ensureVisible(node.context!,
                      alignment: 0.35,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut);
                  }
                });
              }
            },
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;

              // OK / Enter / Select / A  →  open item
              if (event.logicalKey == LogicalKeyboardKey.select  ||
                  event.logicalKey == LogicalKeyboardKey.enter   ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                widget.onSelect(item, i, widget.items);
                return KeyEventResult.handled;
              }

              // LEFT on the leftmost column  →  exit to category panel or rail
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft && col == 0) {
                if (widget.onEdgeLeft != null) {
                  widget.onEdgeLeft!.call();
                } else {
                  TvNavigation.requestRailFocus(context);
                }
                return KeyEventResult.handled; // ← CRITICAL: consume the event
              }

              // All other directions: let Flutter traverse within the grid
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: () => widget.onSelect(item, i, widget.items),
              child: RepaintBoundary(
                child: _TvContentCard(
                  item: item,
                  isFocused: _focusedIndex == i,
                ),
              ),
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
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: isFocused ? 1.06 : 1.0,
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFocused ? primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.imagePath.isNotEmpty
                ? Image.network(
                    item.imagePath,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (_, __, ___) => _Placeholder(),
                  )
                : _Placeholder(),
            
            // Selected/Playing indicator if applicable (could be passed as prop if needed)
            // For now just layout
            
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
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
                    color: Colors.white70,
                    fontSize: 12,
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

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white10,
    child: const Icon(Icons.movie, color: Colors.white12, size: 40),
  );
}
