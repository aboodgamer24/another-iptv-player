import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/home_rails_controller.dart';
import '../../widgets/common/hover_scale_wrapper.dart';
import '../../l10n/localization_extension.dart';
import '../../widgets/section_title_widget.dart';
import '../../models/home_rail_config.dart';

class HomeCustomizationSection extends StatelessWidget {
  const HomeCustomizationSection({super.key});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<HomeRailsController>();
    final rails = controller.rails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitleWidget(title: context.loc.home_customization),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.loc.home_customization_subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        const SizedBox(height: 16),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rails.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            final updated = List<HomeRailConfig>.from(rails);
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            controller.updateRails(updated);
          },
          itemBuilder: (context, index) {
            final rail = rails[index];
            return HoverScaleWrapper(
              key: ValueKey(rail.id),
              hoverScale: 1.02,
              child: ListTile(
                leading: const Icon(Icons.drag_handle_rounded),
                title: Text(_getRailLabel(context, rail.id)),
                trailing: Switch(
                  value: rail.visible,
                  onChanged: (val) => controller.toggleRail(rail.id, val),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
