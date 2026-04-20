import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'c4_gradient_placeholder.dart';

class C4Card extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final List<Widget>? badges;
  final bool showProgress;
  final double? progress;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;

  // New action properties
  final bool? isFavorite;
  final Future<void> Function()? onToggleFavorite;
  final bool? isInWatchLater;
  final Future<void> Function()? onToggleWatchLater;
  final ContentType? contentType;

  const C4Card({
    super.key,
    this.imageUrl,
    required this.title,
    this.subtitle,
    this.onTap,
    this.width,
    this.height,
    this.badges,
    this.showProgress = false,
    this.progress,
    this.onFocusChanged,
    this.focusNode,
    this.isFavorite,
    this.onToggleFavorite,
    this.isInWatchLater,
    this.onToggleWatchLater,
    this.contentType,
  });

  @override
  State<C4Card> createState() => _C4CardState();
}

class _C4CardState extends State<C4Card> with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _isHovered = false;

  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _labelSlideAnim;
  late Animation<double> _labelFadeAnim;
  late Animation<double> _overlayFadeAnim;
  late Animation<double> _innerShadowAnim;

  bool get _isActive => _isFocused || _isHovered;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _labelSlideAnim = Tween<double>(begin: 6.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _labelFadeAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _overlayFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _innerShadowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _activate() {
    _controller.forward();
  }

  void _deactivate() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        focused ? _activate() : (!_isHovered ? _deactivate() : null);
        widget.onFocusChanged?.call(focused);
      },
      onKeyEvent: (node, event) {
        if (_isFocused && event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _activate();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          if (!_isFocused) _deactivate();
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      // Base shadow always present
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      // Glow shadow that fades in on hover/focus
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.45 * _glowAnim.value,
                        ),
                        blurRadius: 20 * _glowAnim.value,
                        spreadRadius: 2 * _glowAnim.value,
                      ),
                    ],
                    border: Border.all(
                      color: primaryColor.withValues(
                        alpha: _glowAnim.value * 0.9,
                      ),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image with subtle zoom
                      Transform.scale(
                        scale: 1.0 + 0.04 * _controller.value,
                        child: _buildImage(),
                      ),

                      // Scrim - darkens slightly more on hover for text contrast
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(
                                  alpha: 0.1 + 0.15 * _controller.value,
                                ),
                                Colors.black.withValues(
                                  alpha: 0.75 + 0.1 * _controller.value,
                                ),
                              ],
                              stops: const [0.45, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Shine sweep overlay on hover
                      Positioned.fill(
                        child: Opacity(
                          opacity: _overlayFadeAnim.value * 0.08,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: const [
                                  Colors.white,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Inner vignette shadow — fills in on hover
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.0,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(
                                  alpha: 0.55 * _innerShadowAnim.value,
                                ),
                              ],
                              stops: const [0.45, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Title + subtitle slide up on hover
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: Offset(0, _labelSlideAnim.value),
                              child: Opacity(
                                opacity: _labelFadeAnim.value,
                                child: Text(
                                  widget.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Transform.translate(
                                offset: Offset(
                                  0,
                                  _labelSlideAnim.value * 1.3,
                                ),
                                child: Opacity(
                                  opacity: _labelFadeAnim.value * 0.85,
                                  child: Text(
                                    widget.subtitle!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Badges
                      // Content type badge — top left
                      if (widget.contentType != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _contentTypeBadgeColor(widget.contentType!).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _contentTypeIcon(widget.contentType!),
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _contentTypeLabel(widget.contentType!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                      if (widget.badges != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.badges!,
                          ),
                        ),

                      // Action buttons (keep existing _CircleIconButton logic)
                      if (widget.onToggleFavorite != null || widget.onToggleWatchLater != null)
                        Positioned(
                          top: 8,
                          right: widget.badges != null ? 48.0 : 8.0,
                          child: AnimatedOpacity(
                            opacity: _isActive ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.onToggleWatchLater != null)
                                  _CircleIconButton(
                                    icon: widget.isInWatchLater == true ? Icons.schedule_rounded : Icons.schedule_outlined,
                                    onPressed: () async {
                                      final was = widget.isInWatchLater == true;
                                      await widget.onToggleWatchLater!();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: Text(was ? context.loc.removed_from_watch_later : context.loc.added_to_watch_later),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          width: 250,
                                        ));
                                      }
                                    },
                                    active: widget.isInWatchLater == true,
                                    activeColor: theme.colorScheme.secondary,
                                  ),
                                if (widget.onToggleFavorite != null) ...[
                                  const SizedBox(width: 6),
                                  _CircleIconButton(
                                    icon: widget.isFavorite == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    onPressed: () async {
                                      final was = widget.isFavorite == true;
                                      await widget.onToggleFavorite!();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: Text(was ? context.loc.removed_from_favorites : context.loc.added_to_favorites),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          width: 200,
                                        ));
                                      }
                                    },
                                    active: widget.isFavorite == true,
                                    activeColor: Colors.redAccent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Progress bar (keep existing)
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const C4GradientPlaceholder(),
        errorWidget: (context, url, error) => const C4GradientPlaceholder(),
      );
    }
    return const C4GradientPlaceholder();
  }

  Color _contentTypeBadgeColor(ContentType type) {
    switch (type) {
      case ContentType.liveStream: return const Color(0xFFE53935);
      case ContentType.vod:        return const Color(0xFF1565C0);
      case ContentType.series:     return const Color(0xFF2E7D32);
    }
  }

  IconData _contentTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.liveStream: return Icons.circle;
      case ContentType.vod:        return Icons.movie_rounded;
      case ContentType.series:     return Icons.tv_rounded;
    }
  }

  String _contentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.liveStream: return 'LIVE';
      case ContentType.vod:        return 'MOVIE';
      case ContentType.series:     return 'SHOW';
    }
  }
}

class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool active;
  final Color activeColor;

  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.active = false,
    required this.activeColor,
  });

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _isHovered = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          if (_isLoading) return;
          setState(() => _isLoading = true);
          try {
            await widget.onPressed();
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _isLoading
                ? Colors.black.withValues(alpha: 0.3)
                : (_isHovered
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.4)),
            shape: BoxShape.circle,
          ),
          child: _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.active ? widget.activeColor : Colors.white,
                    ),
                  ),
                )
              : Icon(
                  widget.icon,
                  size: 18,
                  color: _isHovered
                      ? (widget.active ? widget.activeColor : Colors.black87)
                      : (widget.active ? widget.activeColor : Colors.white),
                ),
        ),
      ),
    );
  }
}
