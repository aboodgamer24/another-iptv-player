import 'package:flutter/material.dart';

/// A sidebar with a draggable right edge for resizing.
/// Place it in a Row alongside your main content.
class ResizableSidebar extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;

  const ResizableSidebar({
    super.key,
    required this.child,
    this.initialWidth = 200.0,
    this.minWidth = 120.0,
    this.maxWidth = 400.0,
  });

  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  late double _width;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Row(
        children: [
          Expanded(child: widget.child),
          // 8px draggable splitter on the right edge
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _width = (_width + details.delta.dx).clamp(
                    widget.minWidth,
                    widget.maxWidth,
                  );
                });
              },
              child: Container(
                width: 8,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 1,
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
