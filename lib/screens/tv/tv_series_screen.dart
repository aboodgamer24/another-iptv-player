import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../models/playlist_model.dart';
import '../../models/content_type.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/m3u_home_controller.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';
import 'tv_browse_screen.dart';

class TvSeriesScreen extends StatelessWidget {
  const TvSeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isXtream = AppState.currentPlaylist?.type == PlaylistType.xtream;

    if (isXtream) {
      final controller = context.watch<XtreamCodeHomeController>();
      if (controller.isLoading && controller.seriesCategories.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return TvBrowseScreen(
        title: context.loc.series_plural,
        categories: controller.seriesCategories,
        contentType: ContentType.series,
        onLoadCategory: (cat) => controller.loadItemsForCategory(cat, ContentType.series),
        onPlayItem: (ctx, item) => navigateByContentType(ctx, item),
      );
    } else {
      final controller = context.watch<M3UHomeController>();
      if (controller.isLoading && (controller.seriesCategories == null || controller.seriesCategories!.isEmpty)) {
        return const Center(child: CircularProgressIndicator());
      }
      return TvBrowseScreen(
        title: context.loc.series_plural,
        categories: controller.seriesCategories ?? [],
        contentType: ContentType.series,
        onLoadCategory: null,
        onPlayItem: (ctx, item) => navigateByContentType(ctx, item),
      );
    }
  }
}
