import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import '../../utils/tv_utils.dart';
import 'tv_player_screen.dart';

class MockContentItem {
  final String title;
  final Color color;
  const MockContentItem({required this.title, required this.color});
}

class TvBrowseScreen extends StatefulWidget {
  final String title;
  final List<String> mockCategories;
  final List<MockContentItem> mockItems;

  const TvBrowseScreen({
    super.key,
    required this.title,
    required this.mockCategories,
    required this.mockItems,
  });

  @override
  State<TvBrowseScreen> createState() => _TvBrowseScreenState();
}

class _TvBrowseScreenState extends State<TvBrowseScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedItemIndex = -1;

  final List<FocusNode> _categoryNodes = [];
  final List<FocusNode> _itemNodes = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.mockCategories.length; i++) {
      _categoryNodes.add(FocusNode(debugLabel: 'browse-cat-$i'));
    }
    for (int i = 0; i < widget.mockItems.length; i++) {
      _itemNodes.add(FocusNode(debugLabel: 'browse-item-$i'));
    }
  }

  @override
  void dispose() {
    for (var node in _categoryNodes) {
      node.dispose();
    }
    for (var node in _itemNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _goToCategories() {
    _categoryNodes[_selectedCategoryIndex].requestFocus();
  }

  void _goToGrid() {
    _itemNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // ── PANEL A: CATEGORIES ────────────────────────────────────
          _buildSidebar(),

          // ── PANEL B: CONTENT GRID ──────────────────────────────────
          _buildGrid(),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
        width: 200,
        color: const Color(0xFF0D0D1A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.mockCategories.length,
                itemBuilder: (context, index) {
                  return _CategoryItem(
                    label: widget.mockCategories[index],
                    isSelected: _selectedCategoryIndex == index,
                    focusNode: _categoryNodes[index],
                    onFocused: () {
                      debugPrint('[Browse] Category $index focused');
                      setState(() => _selectedCategoryIndex = index);
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          debugPrint('[Browse] Category -> Right -> Grid');
                          _goToGrid();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          debugPrint('[Browse] Category -> Left -> Rail');
                          Actions.maybeInvoke(context, const MoveToRailIntent());
                          return KeyEventResult.handled;
                        }
                        // Loop up/down
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown && index == widget.mockCategories.length - 1) {
                          _categoryNodes[0].requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                          _categoryNodes[widget.mockCategories.length - 1].requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Expanded(
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GridView.builder(
            itemCount: widget.mockItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              return _ContentCard(
                item: widget.mockItems[index],
                focusNode: _itemNodes[index],
                onFocused: () {
                  debugPrint('[Browse] Item $index focused');
                  _selectedItemIndex = index;
                },
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    // Arrow left from column 0
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index % 4 == 0) {
                      debugPrint('[Browse] Grid Col 0 -> Left -> Sidebar');
                      _goToCategories();
                      return KeyEventResult.handled;
                    }
                    // Select / Enter
                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                      debugPrint('[Browse] Item $index selected -> Open Player');
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => TvPlayerScreen(
                            title: widget.mockItems[index].title,
                            streamUrl: null,
                          ),
                        ),
                      );
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _CategoryItem({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onFocused,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) {
        if (focused) onFocused();
        // ignore: invalid_use_of_protected_member
        (context as Element).markNeedsBuild();
      },
      onKeyEvent: onKeyEvent,
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          final primary = Theme.of(context).colorScheme.primary;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white10 : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected ? primary : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isFocused || isSelected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final MockContentItem item;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _ContentCard({
    required this.item,
    required this.focusNode,
    required this.onFocused,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) {
        if (focused) onFocused();
        // ignore: invalid_use_of_protected_member
        (context as Element).markNeedsBuild();
      },
      onKeyEvent: onKeyEvent,
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()..scale(isFocused ? 1.05 : 1.0),
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused ? Colors.white : Colors.white10,
                width: 2,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                const Expanded(
                  child: Center(
                    child: Icon(Icons.movie_outlined, color: Colors.white24, size: 48),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
