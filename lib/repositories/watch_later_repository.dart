import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:uuid/uuid.dart';

class WatchLaterRepository {
  final _database = getIt<AppDatabase>();
  final _uuid = Uuid();

  WatchLaterRepository();

  Future<void> addWatchLater(ContentItem contentItem) async {
    final playlistId = AppState.currentPlaylist!.id;

    if (contentItem.contentType == ContentType.liveStream) {
      return; // DO NOT support Watch Later for Live TV
    }

    final entry = WatchLaterData(
      id: _uuid.v4(),
      playlistId: playlistId,
      contentType: contentItem.contentType,
      streamId: contentItem.id,
      title: contentItem.name,
      imagePath: contentItem.imagePath,
      addedAt: DateTime.now(),
    );

    await _database.insertWatchLater(entry);
  }

  Future<void> removeWatchLater(
    String streamId,
    ContentType contentType,
  ) async {
    final playlistId = AppState.currentPlaylist!.id;
    await _database.deleteWatchLater(playlistId, streamId, contentType);
  }

  Future<bool> isWatchLater(String streamId, ContentType contentType) async {
    final playlistId = AppState.currentPlaylist!.id;
    final items = await _database.getWatchLaterItems(playlistId);
    return items.any(
      (e) => e.streamId == streamId && e.contentType == contentType,
    );
  }

  Future<List<WatchLaterData>> getAllWatchLaterItems() async {
    if (AppState.currentPlaylist == null) return [];
    final playlistId = AppState.currentPlaylist!.id;
    return await _database.getWatchLaterItems(playlistId);
  }

  Future<bool> toggleWatchLater(ContentItem contentItem) async {
    final isCurrentlyIn = await isWatchLater(
      contentItem.id,
      contentItem.contentType,
    );
    if (isCurrentlyIn) {
      await removeWatchLater(contentItem.id, contentItem.contentType);
      return false;
    } else {
      await addWatchLater(contentItem);
      return true;
    }
  }
}
