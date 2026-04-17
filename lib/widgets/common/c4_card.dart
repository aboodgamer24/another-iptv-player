import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'c4_gradient_placeholder.dart';

class C4Card extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final List<Widget>? badges;
  final bool showProgress;
  final double? progress;

  const C4Card({
    super.key,
    this.imageUrl,
    required this.title,
    this.subtitle,
    this.onTap,
    this.width = 160,
    this.height = 240,
    this.badges,
    this.showProgress = false,
    this.progress,
  });

  @override
  State<C4Card> createState() => _C4CardState();
}

class _C4CardState extends State<C4Card> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVOD = widget.height > widget.width;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (_isFocused && event is KeyDownEvent) {
          if (event.logicalKey.debugName == 'Select' || event.logicalKey.debugName == 'Enter') {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
              border: Border.all(
                color: _isFocused ? theme.colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image or Placeholder
                if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: widget.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const C4GradientPlaceholder(),
                    errorWidget: (context, url, error) => const C4GradientPlaceholder(),
                  )
                else
                  const C4GradientPlaceholder(),

                // Scrim overlay for text readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.5, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Badges
                if (widget.badges != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(children: widget.badges!),
                  ),

                // Progress Bar
                if (widget.showProgress && widget.progress != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: widget.progress,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
