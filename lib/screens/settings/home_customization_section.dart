import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../controllers/home_rails_controller.dart';
import '../../l10n/localization_extension.dart';
import '../../models/home_rail_config.dart';

class HomeCustomizationSection extends StatefulWidget {
  const HomeCustomizationSection({super.key});

  @override
  State<HomeCustomizationSection> createState() =>
      _HomeCustomizationSectionState();
}

class _HomeCustomizationSectionState extends State<HomeCustomizationSection> {
  // Track which item is being dragged for visual feedback
  int? _draggingIndex;

  String _getRailLabel(BuildContext context, String id) {
    switch (id) {
      case 'continue_watching':
        return context.loc.rail_continue_watching;
      case 'recommended':
        return context.loc.rail_recommended;
      case 'favorites_live':
        return context.loc.rail_favorites_live;
      case 'favorites_movies':
        return context.loc.rail_favorites_movies;
      case 'favorites_series':
        return context.loc.rail_favorites_series;
      case 'watch_later':
        return context.loc.rail_watch_later;
      case 'live_history':
        return context.loc.rail_live_history;
      case 'trending_movies':
        return context.loc.rail_trending_movies;
      case 'trending_series':
        return context.loc.rail_trending_series;
      default:
        return id;
    }
  }

  String _getRailIcon(String id) {
    switch (id) {
      case 'continue_watching':  return 'play_circle_outline';
      case 'recommended':        return 'thumb_up_alt_outlined';
      case 'favorites_live':     return 'live_tv';
      case 'favorites_movies':   return 'movie_outlined';
      case 'favorites_series':   return 'video_library_outlined';
      case 'watch_later':        return 'watch_later_outlined';
      case 'live_history':       return 'history';
      case 'trending_movies':    return 'trending_up';
      case 'trending_series':    return 'auto_graph';
      default:                   return 'widgets_outlined';
    }
  }

  IconData _getIcon(String name) {
    const map = <String, IconData>{
      'play_circle_outline':    Icons.play_circle_outline,
      'thumb_up_alt_outlined':  Icons.thumb_up_alt_outlined,
      'live_tv':                Icons.live_tv,
      'movie_outlined':         Icons.movie_outlined,
      'video_library_outlined': Icons.video_library_outlined,
      'watch_later_outlined':   Icons.watch_later_outlined,
      'history':                Icons.history,
      'trending_up':            Icons.trending_up,
      'auto_graph':             Icons.auto_graph,
      'widgets_outlined':       Icons.widgets_outlined,
    };
    return map[name] ?? Icons.widgets_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<HomeRailsController>();
    final rails = controller.rails;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtitle hint
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              Icon(Icons.drag_indicator,
                  size: 14, color: colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                context.loc.home_customization_subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        // Drag-and-drop list inside a Card
        Card(
          clipBehavior: Clip.antiAlias,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false, // disable default long-press handle
            itemCount: rails.length,
            // Animated drag feedback — elevated card while dragging
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevation = Tween<double>(begin: 0, end: 8)
                      .animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ))
                      .value;
                  return Material(
                    elevation: elevation,
                    borderRadius: BorderRadius.circular(12),
                    shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                    child: child,
                  );
                },
                child: child,
              );
            },
            onReorderStart: (index) {
              HapticFeedback.lightImpact();
              setState(() => _draggingIndex = index);
            },
            onReorderEnd: (_) => setState(() => _draggingIndex = null),
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final updated = List<HomeRailConfig>.from(rails);
              final item = updated.removeAt(oldIndex);
              updated.insert(newIndex, item);
              controller.updateRails(updated);
            },
            itemBuilder: (context, index) {
              final rail = rails[index];
              final isDragging = _draggingIndex == index;
              final iconName = _getRailIcon(rail.id);

              return AnimatedContainer(
                key: ValueKey(rail.id),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isDragging
                      ? colorScheme.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: rail.visible
                              ? colorScheme.primary.withValues(alpha: 0.12)
                              : colorScheme.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIcon(iconName),
                          size: 18,
                          color: rail.visible
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                      title: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                          color: rail.visible
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        child: Text(_getRailLabel(context, rail.id)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: rail.visible,
                            onChanged: (val) =>
                                controller.toggleRail(rail.id, val),
                          ),
                          const SizedBox(width: 4),
                          // Drag handle
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.35),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    if (index < rails.length - 1)
                      Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.08),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
