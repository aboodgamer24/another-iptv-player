import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import '../../utils/tv_utils.dart';

const double kTvRailExpanded  = 220.0;
const double kTvRailCollapsed = 72.0;

class TvNavItem {
  final IconData icon;
  final String   label;
  const TvNavItem({required this.icon, required this.label});
}

class TvShellScreen extends StatefulWidget {
  final int               selectedIndex;
  final ValueChanged<int> onItemSelected;
  final Widget            child;
  final List<TvNavItem>   items;

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

class _TvShellScreenState extends State<TvShellScreen> {
  bool _railExpanded = false;

  final FocusScopeNode _railScope = FocusScopeNode(
    debugLabel: 'tv-rail',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final FocusScopeNode _contentScope = FocusScopeNode(
    debugLabel: 'tv-content',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  final List<FocusNode> _railNodes = [];

  @override
  void initState() {
    super.initState();
    _railNodes.addAll(
      List.generate(widget.items.length, (i) => FocusNode(debugLabel: 'rail-$i')),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _railNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _railScope.dispose();
    _contentScope.dispose();
    for (final n in _railNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _goToRail() {
    setState(() => _railExpanded = true);
    final idx = widget.selectedIndex.clamp(0, _railNodes.length - 1);
    _railNodes[idx].requestFocus();
  }

  void _goToContent() {
    setState(() => _railExpanded = false);
    _contentScope.requestFocus();
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TvExitDialog(
        onCancel: () => Navigator.of(ctx).pop(),
        onExit:   () { Navigator.of(ctx).pop(); SystemNavigator.pop(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        debugPrint('[TvShell] Back pressed. didPop: $didPop');
        if (didPop) return;
        if (Navigator.of(context).canPop()) { 
          debugPrint('[TvShell] Navigator popping');
          Navigator.of(context).pop(); 
          // After popping, ensure focus returns to something visible in the shell
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _goToRail();
          });
          return; 
        }
        if (_railExpanded) { 
          debugPrint('[TvShell] Collapsing rail');
          _goToContent(); 
          return; 
        }
        if (widget.selectedIndex != 0) { 
          debugPrint('[TvShell] Resetting to index 0');
          widget.onItemSelected(0); 
          return; 
        }
        debugPrint('[TvShell] Showing exit dialog');
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [

            // ── RAIL ──────────────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _railExpanded ? kTvRailExpanded : kTvRailCollapsed,
              color: const Color(0xFF0D0D1A),
              child: FocusScope(
                node: _railScope,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: KeyboardListener(
                    focusNode: FocusNode(skipTraversal: true),
                    onKeyEvent: (e) {
                      if (e is KeyDownEvent &&
                          e.logicalKey == LogicalKeyboardKey.arrowRight) {
                        debugPrint('[TvShell] Rail: ArrowRight -> Go to content');
                        _goToContent();
                      }
                    },
                    child: Column(
                      children: [
                        SizedBox(
                          height: 72,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: _railExpanded
                                  ? const Text('C4·TV',
                                      key: ValueKey('e'),
                                      style: TextStyle(color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2))
                                  : const Icon(Icons.tv,
                                      key: ValueKey('c'),
                                      color: Colors.white70, size: 28),
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: widget.items.length,
                            itemBuilder: (ctx, i) => FocusTraversalOrder(
                              order: NumericFocusOrder(i.toDouble()),
                              child: _TvRailTile(
                                focusNode: _railNodes[i],
                                icon: widget.items[i].icon,
                                label: widget.items[i].label,
                                isSelected: widget.selectedIndex == i,
                                expanded: _railExpanded,
                                onExpand: () => setState(() => _railExpanded = true),
                                onTap: () {
                                  widget.onItemSelected(i);
                                  _goToContent();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── CONTENT ───────────────────────────────────────────────────
            Expanded(
              child: FocusScope(
                node: _contentScope,
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: KeyboardListener(
                    focusNode: FocusNode(skipTraversal: true),
                    onKeyEvent: (e) {
                      if (e is KeyDownEvent &&
                          e.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        debugPrint('[TvShell] Content: ArrowLeft check');
                        final moved = FocusScope.of(context)
                            .focusInDirection(TraversalDirection.left);
                        if (!moved) {
                          debugPrint('[TvShell] Content: No left focusable -> Go to rail');
                          _goToRail();
                        }
                      }
                    },
                    child: Actions(
                      actions: {
                        MoveToRailIntent: CallbackAction<MoveToRailIntent>(
                          onInvoke: (_) { _goToRail(); return null; },
                        ),
                      },
                      child: KeyedSubtree(
                        key: ValueKey(widget.selectedIndex),
                        child: widget.child,
                      ),
                    ),
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

// ── Rail tile ────────────────────────────────────────────────────────────────
class _TvRailTile extends StatelessWidget {
  final FocusNode    focusNode;
  final IconData     icon;
  final String       label;
  final bool         isSelected;
  final bool         expanded;
  final VoidCallback onExpand;
  final VoidCallback onTap;

  const _TvRailTile({
    required this.focusNode, required this.icon, required this.label,
    required this.isSelected, required this.expanded,
    required this.onExpand, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) { if (focused) onExpand(); },
      child: FocusableControlBuilder(
        onPressed: onTap,
        builder: (ctx, s) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: s.isFocused || focusNode.hasFocus
                ? Colors.white.withValues(alpha: 0.12)
                : isSelected ? primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: s.isFocused || focusNode.hasFocus ? primary : Colors.transparent, width: 2),
          ),
          child: !expanded
              ? Center(
                  child: Icon(icon,
                      color: s.isFocused || focusNode.hasFocus || isSelected ? Colors.white : Colors.white54,
                      size: 24),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(icon,
                          color: s.isFocused || focusNode.hasFocus || isSelected ? Colors.white : Colors.white54,
                          size: 24),
                      const SizedBox(width: 14),
                      Text(label,
                          style: TextStyle(
                            color: s.isFocused || focusNode.hasFocus || isSelected ? Colors.white : Colors.white60,
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Exit dialog ──────────────────────────────────────────────────────────────
class _TvExitDialog extends StatelessWidget {
  final VoidCallback onCancel, onExit;
  const _TvExitDialog({required this.onCancel, required this.onExit});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF1A1A2E),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12)),
    title: const Text('Exit App?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    content: const Text('Are you sure you want to exit?',
        style: TextStyle(color: Colors.white70)),
    actions: [
      _Btn(label: 'Cancel', onTap: onCancel, autofocus: true),
      _Btn(label: 'Exit',   onTap: onExit,   isDestructive: true),
    ],
  );
}

class _Btn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  final bool isDestructive, autofocus;
  const _Btn({required this.label, required this.onTap,
      this.isDestructive = false, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final error   = Theme.of(context).colorScheme.error;
    return FocusableControlBuilder(
      autoFocus: autofocus, onPressed: onTap,
      builder: (ctx, s) {
        final accent = isDestructive ? error : primary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: s.isFocused ? accent.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: s.isFocused ? accent : Colors.transparent, width: 2)),
          child: Text(label,
              style: TextStyle(
                color: s.isFocused ? Colors.white
                    : (isDestructive ? error : Colors.white54),
                fontWeight: s.isFocused ? FontWeight.bold : FontWeight.normal,
              )),
        );
      },
    );
  }
}
