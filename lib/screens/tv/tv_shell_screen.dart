import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/tv_utils.dart';

/// TV sidebar width constants
const double kTvRailExpanded = 220.0;
const double kTvRailCollapsed = 72.0;

class TvShellScreen extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final Widget child;
  final List<TvNavItem> items;

  const TvShellScreen({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.child,
    required this.items,
  });

  @override
  State<TvShellScreen> createState() => _TvShellScreenState();
}

class _TvShellScreenState extends State<TvShellScreen>
    with SingleTickerProviderStateMixin {
  bool _railExpanded = false;
  late final FocusScopeNode _railScope;
  late final FocusScopeNode _contentScope;
  final List<FocusNode> _itemFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _railScope = FocusScopeNode();
    _contentScope = FocusScopeNode();
    _itemFocusNodes.addAll(
      List.generate(widget.items.length, (_) => FocusNode()),
    );
    // Auto-focus first nav item on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _itemFocusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _railScope.dispose();
    _contentScope.dispose();
    for (final n in _itemFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _expandRail() => setState(() => _railExpanded = true);
  void _collapseRail() => setState(() => _railExpanded = false);

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12, width: 1),
        ),
        title: const Text('Exit App?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('Are you sure you want to exit?',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          _TvDialogButton(
            label: 'Cancel',
            onTap: () => Navigator.of(ctx).pop(),
            isDestructive: false,
            autofocus: true,
          ),
          _TvDialogButton(
            label: 'Exit',
            onTap: () {
              Navigator.of(ctx).pop();
              SystemNavigator.pop();
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final railWidth = _railExpanded ? kTvRailExpanded : kTvRailCollapsed;

    return PopScope(
      canPop: false, // intercept ALL back presses
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If there are routes above the shell, let them handle back instead
        // (this guards against the shell intercepting player back presses)
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
          return;
        }

        if (_railExpanded) {
          _collapseRail();
          return;
        }
        if (widget.selectedIndex != 0) {
          widget.onItemSelected(0);
          return;
        }
        _showExitDialog(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            // ── LEFT RAIL ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: railWidth,
              color: const Color(0xFF0D0D1A),
              child: FocusScope(
                node: _railScope,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    _collapseRail();
                    _contentScope.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Column(
                  children: [
                    // App logo area
                    SizedBox(
                      height: 72,
                      child: Center(
                        child: _railExpanded
                            ? const Text(
                                'C4·TV',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              )
                            : const Icon(
                                Icons.tv,
                                color: Colors.white70,
                                size: 28,
                              ),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 8),
                    // Nav items
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: widget.items.length,
                        itemBuilder: (ctx, i) {
                          final item = widget.items[i];
                          final isSelected = widget.selectedIndex == i;
                          return _TvNavTile(
                            focusNode: _itemFocusNodes[i],
                            icon: item.icon,
                            label: item.label,
                            isSelected: isSelected,
                            expanded: _railExpanded,
                            onTap: () {
                              widget.onItemSelected(i);
                              _collapseRail();
                              _contentScope.requestFocus();
                            },
                            onFocusChange: (hasFocus) {
                              if (hasFocus && !_railExpanded) _expandRail();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── CONTENT ──
            Expanded(
              child: FocusScope(
                node: _contentScope,
                onKeyEvent: (node, event) {
                  // No longer catching global arrowLeft here to prevent accidental jumps.
                  // Content screens now explicitly handle edge navigation.
                  return KeyEventResult.ignored;
                },
                child: Actions(
                  actions: {
                    MoveToRailIntent: CallbackAction<MoveToRailIntent>(
                      onInvoke: (_) {
                        _railScope.requestFocus();
                        _expandRail();
                        return null;
                      },
                    ),
                  },
                  child: KeyedSubtree(
                    key: ValueKey(widget.selectedIndex),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvNavTile extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool expanded;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChange;

  const _TvNavTile({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.expanded,
    required this.onTap,
    required this.onFocusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final hasFocus = Focus.of(ctx).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: hasFocus
                    ? Colors.white.withValues(alpha: 0.12)
                    : (isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFocus ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isSelected)
                    Positioned(
                      left: -12, top: 0, bottom: 0,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          icon,
                          color: hasFocus || isSelected
                              ? Colors.white
                              : Colors.white54,
                          size: 24,
                        ),
                        if (expanded) ...[
                          const SizedBox(width: 14),
                          Flexible(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: hasFocus || isSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
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

class TvNavItem {
  final IconData icon;
  final String label;
  const TvNavItem({required this.icon, required this.label});
}

class _TvDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool autofocus;

  const _TvDialogButton({
    required this.label,
    required this.onTap,
    required this.isDestructive,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final error = Theme.of(context).colorScheme.error;
    
    return Focus(
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: f ? (isDestructive ? error : Colors.white12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: f ? (isDestructive ? error : primary) : Colors.transparent, width: 2),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: f ? Colors.white : (isDestructive ? error : Colors.white54),
                fontWeight: f || isDestructive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }
}
