import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'c4tv_logo.dart';
import 'hover_scale_wrapper.dart';

class C4RailItem {
  final IconData icon;
  final String label;
  final String route;

  const C4RailItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class C4Rail extends StatefulWidget {
  final List<C4RailItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final Widget? trailing;

  const C4Rail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.trailing,
  });

  @override
  State<C4Rail> createState() => _C4RailState();
}

class _C4RailState extends State<C4Rail> {
  int _focusedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerTheme.color ?? Colors.white10,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          // ── C4TV logo at top of sidebar ──────────────────────────────
          C4tvLogo(size: 38),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              itemCount: widget.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = widget.selectedIndex == index;
                final isFocused = _focusedIndex == index;

                return Focus(
                  onFocusChange: (focused) {
                    if (focused) setState(() => _focusedIndex = index);
                  },
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey.debugName == 'Select' ||
                          event.logicalKey.debugName == 'Enter') {
                        widget.onItemSelected(index);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: GestureDetector(
                    onTap: () => widget.onItemSelected(index),
                    child: HoverScaleWrapper(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                )
                              : isFocused
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.05,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFocused
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected || isFocused
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelected || isFocused
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.trailing != null) ...[
            widget.trailing!,
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
