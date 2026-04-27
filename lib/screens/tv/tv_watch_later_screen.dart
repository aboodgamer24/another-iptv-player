import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import '../../controllers/watch_later_controller.dart';
import '../../database/database.dart';
import '../../models/content_type.dart';
import '../../utils/tv_utils.dart';

class TvWatchLaterScreen extends StatefulWidget {
  const TvWatchLaterScreen({super.key});

  @override
  State<TvWatchLaterScreen> createState() => _TvWatchLaterScreenState();
}

class _TvWatchLaterScreenState extends State<TvWatchLaterScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['All', 'Movies', 'Series'];
  final List<FocusNode> _categoryNodes = [];
  List<FocusNode> _itemNodes = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _categories.length; i++) {
      _categoryNodes.add(FocusNode(debugLabel: 'wl-cat-$i'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchLaterController>().loadWatchLaterItems();
    });
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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<WatchLaterController>();

    if (ctrl.isLoading && ctrl.watchLaterItems.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final movieItems = ctrl.watchLaterItems.where((w) => w.contentType == ContentType.vod).toList();
    final seriesItems = ctrl.watchLaterItems.where((w) => w.contentType == ContentType.series).toList();

    List<WatchLaterData> currentItems = [];
    if (_selectedCategoryIndex == 0) {
      currentItems = ctrl.watchLaterItems;
    } else if (_selectedCategoryIndex == 1) {
      currentItems = movieItems;
    } else if (_selectedCategoryIndex == 2) {
      currentItems = seriesItems;
    }

    if (_itemNodes.length != currentItems.length) {
      for (var n in _itemNodes) {
        n.dispose();
      }
      _itemNodes = List.generate(
        currentItems.length,
        (i) => FocusNode(debugLabel: 'wl-item-$i'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // ── PANEL A: CATEGORIES ────────────────────────────────────
          _buildSidebar(),

          // ── PANEL B: CONTENT GRID ──────────────────────────────────
          _buildGrid(currentItems, ctrl),
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
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Watch Later',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  return _CategoryItem(
                    label: _categories[index],
                    isSelected: _selectedCategoryIndex == index,
                    focusNode: _categoryNodes[index],
                    onFocused: () {
                      if (_selectedCategoryIndex != index) {
                        setState(() => _selectedCategoryIndex = index);
                      }
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
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown && index == _categories.length - 1) {
                          _categoryNodes[0].requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                          _categoryNodes[_categories.length - 1].requestFocus();
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

  Widget _buildGrid(List<WatchLaterData> items, WatchLaterController ctrl) {
    return Expanded(
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: items.isEmpty
            ? _buildEmpty()
            : Padding(
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
                    final wl = items[index];
                    return _ContentCard(
                      title: wl.title,
                      imageUrl: wl.imagePath,
                      focusNode: _itemNodes[index],
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
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
                      onSelect: () {
                        // The user said: "in watch later and favorite are playing the windows/phone player version."
                        // WatchLater uses `ctrl.playContent(context, wl)` which internally calls `navigateByContentType`.
                        // We will fix `navigateByContentType` in a moment.
                        ctrl.playContent(context, wl);
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 72, color: Color.fromRGBO(255, 255, 255, 0.2)),
          SizedBox(height: 16),
          Text('Watch Later is Empty', style: TextStyle(fontSize: 20, color: Colors.white60)),
        ],
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
                    const Center(child: Icon(Icons.movie_outlined, size: 48, color: Colors.white24)),
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
