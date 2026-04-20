import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/watch_later_controller.dart';
import '../models/content_type.dart';
import '../models/playlist_content_model.dart';
import '../widgets/common/c4_content_rail.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';

class WatchLaterScreen extends StatefulWidget {
  const WatchLaterScreen({super.key});

  @override
  State<WatchLaterScreen> createState() => _WatchLaterScreenState();
}

class _WatchLaterScreenState extends State<WatchLaterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchLaterController>().loadWatchLaterItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WatchLaterController>();
    final items = controller.watchLaterItems;

    final movieItems = items
        .where((i) => i.contentType == ContentType.vod)
        .map((i) => ContentItem(i.streamId, i.title, i.imagePath ?? '', i.contentType))
        .toList();
    final seriesItems = items
        .where((i) => i.contentType == ContentType.series)
        .map((i) => ContentItem(i.streamId, i.title, i.imagePath ?? '', i.contentType))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent, // Parent provides background
      body: controller.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.only(top: 24, bottom: 64),
                  children: [
                    if (movieItems.isNotEmpty)
                      C4ContentRail(
                        title: context.loc.movies,
                        items: movieItems,
                        isPortrait: true,
                        onItemTap: (ctx, item) => _playItem(ctx, item),
                      ),
                    if (seriesItems.isNotEmpty)
                      C4ContentRail(
                        title: context.loc.series_plural,
                        items: seriesItems,
                        isPortrait: true,
                        onItemTap: (ctx, item) => _playItem(ctx, item),
                      ),
                  ],
                ),
    );
  }

  void _playItem(BuildContext context, ContentItem item) {
    if (item.contentType == ContentType.series) {
      navigateByContentType(context, item);
      return;
    }
    final controller = context.read<WatchLaterController>();
    final data = controller.watchLaterItems.firstWhere(
      (i) => i.streamId == item.id && i.contentType == item.contentType,
    );
    controller.playContent(context, data);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            context.loc.watch_later_empty_message,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            context.loc.watch_later_empty_description,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
