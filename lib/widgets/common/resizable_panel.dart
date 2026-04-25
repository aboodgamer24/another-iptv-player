import 'package:flutter/material.dart';

/// A panel with a draggable left edge for resizing.
/// Place it in a Row after your main content.
class ResizablePanel extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;

  const ResizablePanel({
    super.key,
    required this.child,
    this.initialWidth = 320.0,
    this.minWidth = 180.0,
    this.maxWidth = 520.0,
  });

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
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
          // 8px draggable splitter on the left edge
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _width = (_width - details.delta.dx).clamp(
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
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
