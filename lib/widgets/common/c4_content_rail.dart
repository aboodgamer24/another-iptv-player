import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/watch_later_controller.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/navigate_by_content_type.dart';
import 'c4_card.dart';

class C4ContentRail extends StatefulWidget {
  final String title;
  final List<ContentItem> items;
  final bool isPortrait;
  final void Function(BuildContext, ContentItem)? onItemTap;

  const C4ContentRail({
    super.key,
    required this.title,
    required this.items,
    this.isPortrait = true,
    this.onItemTap,
  });

  @override
  State<C4ContentRail> createState() => _C4ContentRailState();
}

class _C4ContentRailState extends State<C4ContentRail> {
  late ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  double _currentCardWidth = 160.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollButtons);
    
    // Initial check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    
    final canScrollLeft = offset > 10.0; // Small threshold
    final canScrollRight = offset < (max - 10.0);

    if (canScrollLeft != _canScrollLeft || canScrollRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canScrollLeft;
          _canScrollRight = canScrollRight;
        });
      }
    }
  }

  void _scrollLeft() {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset - _currentCardWidth * 3).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + _currentCardWidth * 3).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final favoritesController = context.watch<FavoritesController>();
    final watchLaterController = context.watch<WatchLaterController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width < 600 ? 16.0 : (width < 900 ? 24.0 : 48.0);
        const cardGap = 16.0;

        // Decide how many cards should be visible at once on desktop.
        int targetCount;
        if (width >= 1600) {
          targetCount = widget.isPortrait ? 8 : 6;
        } else if (width >= 1200) {
          targetCount = widget.isPortrait ? 6 : 5;
        } else if (width >= 900) {
          targetCount = widget.isPortrait ? 5 : 4;
        } else {
          targetCount = widget.isPortrait ? 3 : 2;
        }

        // Compute cardWidth based on available space.
        final totalGaps = (targetCount - 1) * cardGap;
        final available = width - (horizontalPadding * 2) - totalGaps;
        final cardWidth = available / targetCount;
        _currentCardWidth = cardWidth;

        // Maintain approximate aspect ratio (C4-TV style)
        final cardHeight = widget.isPortrait
            ? cardWidth * 1.5
            : cardWidth * 0.6;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              child: Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: width < 600 ? 18 : 22,
                ),
              ),
            ),
            SizedBox(
              height: cardHeight + 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.items.length,
                      clipBehavior: Clip.none,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == widget.items.length - 1 ? 0 : cardGap,
                          ),
                          child: Center(
                            child: C4Card(
                              title: item.name,
                              imageUrl: item.imageUrl,
                              width: cardWidth,
                              height: cardHeight,
                              isFavorite: favoritesController.favorites.any(
                                (f) => f.streamId == item.id && f.contentType == item.contentType,
                              ),
                              onToggleFavorite: () => favoritesController.toggleFavorite(item),
                              isInWatchLater: watchLaterController.watchLaterItems.any(
                                (w) => w.streamId == item.id && w.contentType == item.contentType,
                              ),
                              onToggleWatchLater: item.contentType == ContentType.liveStream 
                                ? null 
                                : () => watchLaterController.toggleWatchLater(item),
                              onTap: () {
                                if (widget.onItemTap != null) {
                                  widget.onItemTap!(context, item);
                                } else {
                                  navigateByContentType(context, item);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Left Arrow
                  if (_canScrollLeft)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 40, // Match card center minus padding
                      child: Center(
                        child: _RailArrowButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: _scrollLeft,
                        ),
                      ),
                    ),
                    
                  // Right Arrow
                  if (_canScrollRight)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 40, // Match card center minus padding
                      child: Center(
                        child: _RailArrowButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: _scrollRight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _RailArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RailArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_RailArrowButton> createState() => _RailArrowButtonState();
}

class _RailArrowButtonState extends State<_RailArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isHovered 
                ? Colors.white.withValues(alpha: 0.9) 
                : Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: _isHovered ? Colors.black : Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
