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

class TvMoviesScreen extends StatelessWidget {
  const TvMoviesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isXtream = AppState.currentPlaylist?.type == PlaylistType.xtream;

    if (isXtream) {
      final controller = context.watch<XtreamCodeHomeController>();
      if (controller.isLoading && controller.movieCategories.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return TvBrowseScreen(
        title: context.loc.movies,
        categories: controller.movieCategories,
        contentType: ContentType.vod,
        onLoadCategory: (cat) => controller.loadItemsForCategory(cat, ContentType.vod),
        onPlayItem: (ctx, item) => navigateByContentType(ctx, item),
      );
    } else {
      final controller = context.watch<M3UHomeController>();
      if (controller.isLoading && (controller.vodCategories == null || controller.vodCategories!.isEmpty)) {
        return const Center(child: CircularProgressIndicator());
      }
      return TvBrowseScreen(
        title: context.loc.movies,
        categories: controller.vodCategories ?? [],
        contentType: ContentType.vod,
        onLoadCategory: null, // M3U does not lazy load via loadItemsForCategory currently
        onPlayItem: (ctx, item) => navigateByContentType(ctx, item),
      );
    }
  }
}
