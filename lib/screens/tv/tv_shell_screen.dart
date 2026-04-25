import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  Widget build(BuildContext context) {
    final railWidth = _railExpanded ? kTvRailExpanded : kTvRailCollapsed;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // ── LEFT RAIL ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: railWidth,
            color: const Color(0xFF1A1A2E),
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
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _railScope.requestFocus();
                  _expandRail();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: widget.child,
            ),
          ),
        ],
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
                color: hasFocus || isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: hasFocus
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: hasFocus || isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white54,
                    size: 24,
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 14),
                    Expanded(
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
                      ),
                    ),
                  ],
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
