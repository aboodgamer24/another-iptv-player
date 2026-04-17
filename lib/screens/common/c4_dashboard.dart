import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/watch_history_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../widgets/common/c4_card.dart';
import '../../l10n/localization_extension.dart';
import '../../models/content_type.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../models/playlist_content_model.dart';

class C4Dashboard extends StatefulWidget {
  final String playlistId;

  const C4Dashboard({super.key, required this.playlistId});

  @override
  State<C4Dashboard> createState() => _C4DashboardState();
}

class _C4DashboardState extends State<C4Dashboard> {
  late WatchHistoryController _historyController;
  late FavoritesController _favoritesController;

  @override
  void initState() {
    super.initState();
    _historyController = WatchHistoryController();
    _favoritesController = FavoritesController();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _historyController.loadWatchHistory(),
      _favoritesController.loadFavorites(),
    ]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xtreamController = context.watch<XtreamCodeHomeController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        children: [
          const SizedBox(height: 24),

          // Continue Watching
          if (_historyController.continueWatching.isNotEmpty) ...[
            _buildSectionHeader(context.loc.continue_watching, Icons.play_arrow_rounded),
            const SizedBox(height: 16),
            _buildContinueWatchingRow(),
            const SizedBox(height: 40),
          ],

          // Live TV Quick Access (Categories)
          if (xtreamController.liveCategories != null && xtreamController.liveCategories!.isNotEmpty) ...[
            _buildSectionHeader(context.loc.live_streams, Icons.live_tv_rounded),
            const SizedBox(height: 16),
            _buildXtreamCategoryRow(xtreamController.liveCategories!, ContentType.liveStream),
            const SizedBox(height: 40),
          ],

          // Recent Movies
          if (xtreamController.movieCategories.isNotEmpty) ...[
            _buildSectionHeader(context.loc.movies, Icons.movie_rounded),
            const SizedBox(height: 16),
            _buildXtreamCategoryRow(xtreamController.movieCategories, ContentType.vod),
            const SizedBox(height: 40),
          ],

          // Recent Series
          if (xtreamController.seriesCategories.isNotEmpty) ...[
            _buildSectionHeader(context.loc.series_plural, Icons.tv_rounded),
            const SizedBox(height: 16),
            _buildXtreamCategoryRow(xtreamController.seriesCategories, ContentType.series),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatchingRow() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _historyController.continueWatching.length,
        itemBuilder: (context, index) {
          final history = _historyController.continueWatching[index];
          double? progress;
          if (history.watchDuration != null && history.totalDuration != null && history.totalDuration!.inSeconds > 0) {
            progress = history.watchDuration!.inSeconds / history.totalDuration!.inSeconds;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: C4Card(
              title: history.title,
              imageUrl: history.imagePath,
              width: 260,
              height: 150,
              showProgress: progress != null,
              progress: progress,
              onTap: () => _historyController.playContent(context, history),
            ),
          );
        },
      ),
    );
  }

  Widget _buildXtreamCategoryRow(List<dynamic> categories, ContentType type) {
    return SizedBox(
      height: type == ContentType.liveStream ? 160 : 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final firstItem = category.contentItems.firstOrNull;

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: C4Card(
              title: category.category.categoryName,
              imageUrl: firstItem?.imageUrl,
              width: type == ContentType.liveStream ? 220 : 160,
              height: type == ContentType.liveStream ? 120 : 240,
              subtitle: '${category.contentItems.length} items',
              onTap: () {
                // Navigate to category detail
              },
            ),
          );
        },
      ),
    );
  }
}
