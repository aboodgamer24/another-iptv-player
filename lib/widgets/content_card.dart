import 'package:c4tv_player/l10n/localization_extension.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:c4tv_player/models/playlist_content_model.dart';
import 'package:c4tv_player/models/content_type.dart';
import 'package:c4tv_player/utils/responsive_helper.dart';
import 'common/hover_scale_wrapper.dart';

class ContentCard extends StatefulWidget {
  final ContentItem content;
  final double width;
  final VoidCallback? onTap;
  final bool isSelected;

  const ContentCard({
    super.key,
    required this.content,
    required this.width,
    this.onTap,
    this.isSelected = false,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  final bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    bool isRecent = false;
    String? releaseDateStr;
    DateTime? releaseDate;

    if (widget.content.contentType == ContentType.series) {
      releaseDateStr = widget.content.seriesStream?.releaseDate;
    }

    if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
      try {
        releaseDate = DateTime.parse(releaseDateStr);
      } catch (e) {
        releaseDate = null;
      }
    }

    if (releaseDate != null) {
      final diff = DateTime.now().difference(releaseDate).inDays;
      isRecent = diff <= 15;
    }

    final bool isLiveStream =
        widget.content.contentType == ContentType.liveStream;
    final Widget? ratingBadge = isLiveStream
        ? null
        : _buildRatingBadge(context);
    final bool isDesktop = ResponsiveHelper.isDesktopOrTV(context);

    Widget cardWidget = Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
      color: widget.isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: widget.content.imagePath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.content.imagePath,
                            fit: _getFitForContentType(),
                            placeholder: (context, url) => Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildTitleCard(context),
                          )
                        : _buildTitleCard(context),
                  ),
                  if (ratingBadge != null) ratingBadge,
                  if (isRecent)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.loc.new_ep,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Hover play icon overlay (desktop only)
                  if (isDesktop && _isHovered)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Text(
                        widget.content.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Desktop: wrap with hover effects
    if (isDesktop) {
      return HoverScaleWrapper(hoverScale: 1.02, child: cardWidget);
    }

    return cardWidget;
  }

  BoxFit _getFitForContentType() {
    if (widget.content.contentType == ContentType.liveStream) {
      return BoxFit.contain;
    }
    return BoxFit.cover;
  }

  Widget _buildTitleCard(BuildContext context) {
    return Container(
      color: widget.isSelected
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            widget.content.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget? _buildRatingBadge(BuildContext context) {
    final dynamic rawRating = widget.content.contentType == ContentType.series
        ? widget.content.seriesStream?.rating
        : widget.content.vodStream?.rating;

    final double? rating = _parseRating(rawRating);
    if (rating == null || rating <= 0) {
      return null;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final formattedRating = rating % 1 == 0
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);

    return Positioned(
      top: 6,
      right: 6,
      child: Semantics(
        label: 'Rating $formattedRating',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.secondaryContainer.withValues(alpha: 0.93),
                colorScheme.secondary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.16),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.22),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 14,
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 3),
              Text(
                formattedRating,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: colorScheme.onSecondaryContainer,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _parseRating(dynamic rating) {
    if (rating == null) return null;
    if (rating is num) return rating.toDouble();
    if (rating is String && rating.isNotEmpty) {
      final normalized = rating.replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }
}
