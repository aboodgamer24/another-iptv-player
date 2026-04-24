import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/navigate_by_content_type.dart';

class C4DashboardHero extends StatelessWidget {
  final ContentItem item;
  final VoidCallback? onPlay;
  final VoidCallback? onInfo;

  const C4DashboardHero({
    super.key,
    required this.item,
    this.onPlay,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height * 0.45,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Backdrop
          if (item.imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              fadeInDuration: const Duration(milliseconds: 300),
              placeholder: (context, url) => const ColoredBox(
                color: Color(0xFF13161C),
              ),
              errorWidget: (context, url, error) => const DecoratedBox(
                decoration: BoxDecoration(color: Colors.black45),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(color: Colors.black45),
            ),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.8],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                if (item.vodStream?.genre != null || item.seriesStream?.genre != null)
                  Text(
                    item.vodStream?.genre ?? item.seriesStream?.genre ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: onPlay ?? () => navigateByContentType(context, item),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: onInfo ?? () => navigateByContentType(context, item),
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('More Info'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroShimmer extends StatefulWidget {
  const _HeroShimmer();

  @override
  State<_HeroShimmer> createState() => _HeroShimmerState();
}

class _HeroShimmerState extends State<_HeroShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFF1A1D24),
                Color(0xFF262A35),
                Color(0xFF1A1D24),
              ],
            ),
          ),
        );
      },
    );
  }
}
