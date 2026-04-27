import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/category_view_model.dart';
import '../../models/playlist_content_model.dart';
import '../../models/content_type.dart';
import '../../utils/tv_utils.dart';
import '../../l10n/localization_extension.dart';

class TvBrowseScreen extends StatefulWidget {
  final String title;
  final List<CategoryViewModel> categories;
  final ContentType contentType;
  final Future<void> Function(CategoryViewModel)? onLoadCategory;
  final Function(BuildContext, ContentItem) onPlayItem;

  const TvBrowseScreen({
    super.key,
    required this.title,
    required this.categories,
    required this.contentType,
    this.onLoadCategory,
    required this.onPlayItem,
  });

  @override
  State<TvBrowseScreen> createState() => _TvBrowseScreenState();
}

class _TvBrowseScreenState extends State<TvBrowseScreen> {
  int _selectedCategoryIndex = 0;
  bool _isLoadingCategory = false;

  final List<FocusNode> _categoryNodes = [];
  List<FocusNode> _itemNodes = [];

  // Used for "All" option
  List<ContentItem> _allItems = [];

  @override
  void initState() {
    super.initState();
    _rebuildCategoryNodes();
    _loadCategoryData();
  }

  @override
  void didUpdateWidget(TvBrowseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _rebuildCategoryNodes();
      // Ensure index is valid
      if (_selectedCategoryIndex > widget.categories.length) {
        _selectedCategoryIndex = 0;
      }
      _loadCategoryData();
    }
  }

  void _rebuildCategoryNodes() {
    for (var node in _categoryNodes) {
      node.dispose();
    }
    _categoryNodes.clear();
    // +1 for "All"
    for (int i = 0; i < widget.categories.length + 1; i++) {
      _categoryNodes.add(FocusNode(debugLabel: 'browse-cat-$i'));
    }
  }

  Future<void> _loadCategoryData() async {
    if (widget.categories.isEmpty) return;

    if (_selectedCategoryIndex == 0) {
      // "All" category: we just gather what we already have loaded locally
      setState(() {
        _allItems = widget.categories.expand((c) => c.contentItems).toList();
        _isLoadingCategory = false;
      });
      return;
    }

    final cat = widget.categories[_selectedCategoryIndex - 1];
    if (cat.contentItems.isEmpty && widget.onLoadCategory != null) {
      setState(() => _isLoadingCategory = true);
      await widget.onLoadCategory!(cat);
      if (mounted) {
        setState(() => _isLoadingCategory = false);
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingCategory = false);
      }
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
    if (_itemNodes.isNotEmpty) {
      _itemNodes[0].requestFocus();
    }
  }

  void _onCategorySelected(int index) {
    if (_selectedCategoryIndex == index) return;
    setState(() => _selectedCategoryIndex = index);
    _loadCategoryData();
  }

  List<ContentItem> get _currentItems {
    if (_selectedCategoryIndex == 0) return _allItems;
    if (widget.categories.isEmpty) return [];
    final idx = _selectedCategoryIndex - 1;
    if (idx < 0 || idx >= widget.categories.length) return [];
    return widget.categories[idx].contentItems;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentItems = _currentItems;

    // Update item nodes
    if (_itemNodes.length != currentItems.length) {
      for (var n in _itemNodes) {
        n.dispose();
      }
      _itemNodes = List.generate(
        currentItems.length,
        (i) => FocusNode(debugLabel: 'browse-item-$i'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // ── PANEL A: CATEGORIES ────────────────────────────────────
          _buildSidebar(),

          // ── PANEL B: CONTENT GRID ──────────────────────────────────
          _buildGrid(currentItems),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
        width: 250,
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
                itemCount: widget.categories.length + 1,
                itemBuilder: (context, index) {
                  final label = index == 0
                      ? context.loc.all
                      : widget.categories[index - 1].category.categoryName;

                  return _CategoryItem(
                    label: label,
                    isSelected: _selectedCategoryIndex == index,
                    focusNode: _categoryNodes[index],
                    onFocused: () {
                      _onCategorySelected(index);
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _goToGrid();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                            event.logicalKey == LogicalKeyboardKey.goBack) {
                          Actions.maybeInvoke(context, const MoveToRailIntent());
                          return KeyEventResult.handled;
                        }
                        // Loop up/down
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown && index == widget.categories.length) {
                          _categoryNodes[0].requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                          _categoryNodes[widget.categories.length].requestFocus();
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

  Widget _buildGrid(List<ContentItem> items) {
    if (_isLoadingCategory) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (items.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                context.loc.not_found_in_category,
                style: const TextStyle(fontSize: 18, color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GridView.builder(
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ContentCard(
                title: item.name,
                imageUrl: item.imageUrl,
                focusNode: _itemNodes[index],
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.select) {
                      widget.onPlayItem(context, item);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index % 5 == 0) {
                      _goToCategories();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.goBack) {
                      _goToCategories();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                onSelect: () => widget.onPlayItem(context, item),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  final String title;
  final String? imageUrl;
  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final VoidCallback onSelect;

  const _ContentCard({
    required this.title,
    this.imageUrl,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) {
        // ignore: invalid_use_of_protected_member
        (context as Element).markNeedsBuild();
      },
      onKeyEvent: onKeyEvent,
      child: FocusableControlBuilder(
        onPressed: onSelect,
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          final primary = Theme.of(context).colorScheme.primary;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: isFocused
              ? (Matrix4.identity()..scale(1.05, 1.05, 1.0))
              : Matrix4.identity(),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused ? Colors.white : Colors.white10,
                width: 2,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                          child: Icon(Icons.movie_outlined, size: 48, color: Colors.white24)),
                      errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.movie_outlined, size: 48, color: Colors.white24)),
                    )
                  else
                    const Center(
                        child: Icon(Icons.movie_outlined, size: 48, color: Colors.white24)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
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
