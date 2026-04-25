import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/watch_later_controller.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class MobileWatchLaterScreen extends StatefulWidget {
  const MobileWatchLaterScreen({super.key});

  @override
  State<MobileWatchLaterScreen> createState() => _MobileWatchLaterScreenState();
}

class _MobileWatchLaterScreenState extends State<MobileWatchLaterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchLaterController>().loadWatchLaterItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WatchLaterController>(
      builder: (context, controller, _) {
        if (controller.isLoading && controller.watchLaterItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.watchLaterItems.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.watchLaterItems.length,
          itemBuilder: (context, index) {
            final item = controller.watchLaterItems[index];
            final contentItem = ContentItem(
              item.streamId,
              item.title,
              item.imagePath ?? '',
              item.contentType,
            );

            return Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => controller.toggleWatchLater(contentItem),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: item.imagePath ?? '',
                    width: 80,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.movie, color: Colors.white24),
                  ),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  item.contentType == ContentType.vod
                      ? context.loc.movies
                      : context.loc.series_plural,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  onPressed: () => controller.toggleWatchLater(contentItem),
                ),
                onTap: () {
                  if (item.contentType == ContentType.series) {
                    navigateByContentType(context, contentItem);
                  } else {
                    controller.playContent(context, item);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            context.loc.watch_later_empty_message,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
