import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/watch_later_repository.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/screens/m3u/m3u_player_screen.dart';
import 'package:another_iptv_player/screens/series/episode_screen.dart';
import 'package:another_iptv_player/services/sync_service.dart';
import 'package:flutter/material.dart';

class WatchLaterController extends ChangeNotifier {
  final WatchLaterRepository _repository = WatchLaterRepository();
  final _database = getIt<AppDatabase>();

  List<WatchLaterData> _watchLaterItems = [];
  bool _isLoading = false;
  String? _error;

  List<WatchLaterData> get watchLaterItems => _watchLaterItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  WatchLaterController();

  Future<void> loadWatchLaterItems() async {
    try {
      _setLoading(true);
      _setError(null);

      _watchLaterItems = await _repository.getAllWatchLaterItems();
      notifyListeners();
    } catch (e) {
      _setError('Error loading watch later items: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addToWatchLater(ContentItem contentItem) async {
    if (contentItem.contentType == ContentType.liveStream) {
      _setError('Live TV cannot be added to watch later');
      return false;
    }
    try {
      _setError(null);
      await _repository.addWatchLater(contentItem);
      await loadWatchLaterItems();
      _syncWatchLaterToServer();
      return true;
    } catch (e) {
      _setError('Error adding to watch later: \$e');
      return false;
    }
  }

  Future<bool> removeFromWatchLater(String streamId, ContentType contentType) async {
    try {
      _setError(null);
      await _repository.removeWatchLater(streamId, contentType);
      await loadWatchLaterItems();
      _syncWatchLaterToServer();
      return true;
    } catch (e) {
      _setError('Error removing from watch later: \$e');
      return false;
    }
  }

  Future<bool> toggleWatchLater(ContentItem contentItem) async {
    if (contentItem.contentType == ContentType.liveStream) {
      return false;
    }

    try {
      _setError(null);
      
      final isCurrentlyIn = _watchLaterItems.any(
        (i) => i.streamId == contentItem.id && i.contentType == contentItem.contentType,
      );

      // Optimistic Update
      if (isCurrentlyIn) {
        _watchLaterItems.removeWhere(
          (i) => i.streamId == contentItem.id && i.contentType == contentItem.contentType,
        );
      } else {
        // Temporary entry for optimistic UI
        _watchLaterItems.insert(0, WatchLaterData(
          id: 'temp_${contentItem.id}',
          playlistId: AppState.currentPlaylist?.id ?? '',
          contentType: contentItem.contentType,
          streamId: contentItem.id,
          title: contentItem.name,
          imagePath: contentItem.imagePath,
          addedAt: DateTime.now(),
        ));
      }
      notifyListeners();

      final result = await _repository.toggleWatchLater(contentItem);
      
      // Sync with repository state
      await loadWatchLaterItems();
      _syncWatchLaterToServer();
      return result;
    } catch (e) {
      _setError('Error toggling watch later: $e');
      // Revert optimistic update on failure
      await loadWatchLaterItems();
      return false;
    }
  }

  Future<bool> isWatchLater(String streamId, ContentType contentType) async {
    return await _repository.isWatchLater(streamId, contentType);
  }

  Future<void> playContent(BuildContext context, WatchLaterData item) async {
    try {
      _setError(null);
      switch (item.contentType) {
        case ContentType.vod:
          await _playMovie(context, item);
          break;
        case ContentType.series:
          await _playSeries(context, item);
          break;
        default:
          break;
      }
    } catch (e) {
      _setError('Video oynatılırken hata oluştu: $e');
    }
  }

  Future<void> _playMovie(BuildContext context, WatchLaterData item) async {
    final playlistType = getPlaylistType();
    final isXtreamCode = playlistType == PlaylistType.xtream;
    final isM3u = playlistType == PlaylistType.m3u;

    if (isXtreamCode) {
      final movie = await _database.findMovieById(
        item.streamId,
        AppState.currentPlaylist!.id,
      );

      if (!context.mounted) return;
      navigateByContentType(
        context,
        ContentItem(
          item.streamId,
          item.title,
          item.imagePath ?? '',
          item.contentType,
          containerExtension: movie?.containerExtension,
          vodStream: movie,
        ),
      );
    } else if (isM3u) {
      var movie = await _database.getM3uItemsByIdAndPlaylist(
        AppState.currentPlaylist!.id,
        item.streamId,
      );

      if (!context.mounted) return;
      navigateByContentType(
        context,
        ContentItem(
          movie!.url,
          item.title,
          item.imagePath ?? '',
          item.contentType,
          m3uItem: movie,
        ),
      );
    }
  }

  Future<void> _playSeries(BuildContext context, WatchLaterData item) async {
    final playlistType = getPlaylistType();
    final isXtreamCode = playlistType == PlaylistType.xtream;
    final isM3u = playlistType == PlaylistType.m3u;

    if (isXtreamCode) {
      // Fetch series info directly from repository to ensure latest data
      final seriesResponse = await AppState.xtreamCodeRepository!.getSeriesInfo(
        item.streamId,
      );

      if (seriesResponse == null) {
        _setError('Series info not found');
        return;
      }

      final seriesStream = await _database.findSeriesById(
        item.streamId,
        AppState.currentPlaylist!.id,
      );

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EpisodeScreen(
            seriesInfo: seriesResponse.seriesInfo,
            seasons: seriesResponse.seasons,
            episodes: seriesResponse.episodes,
            contentItem: ContentItem(
              item.streamId,
              item.title,
              item.imagePath ?? "",
              ContentType.series,
              seriesStream: seriesStream,
            ),
          ),
        ),
      );
    } else if (isM3u) {
      var m3uItem = await _database.getM3uItemsByIdAndPlaylist(
        AppState.currentPlaylist!.id,
        item.streamId,
      );

      if (m3uItem == null) {
        _setError('Series not found');
        return;
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => M3uPlayerScreen(
            contentItem: ContentItem(
              m3uItem.id,
              m3uItem.name ?? '',
              m3uItem.tvgLogo ?? '',
              m3uItem.contentType,
              m3uItem: m3uItem,
            ),
          ),
        ),
      );
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Fire-and-forget push of the current watch later list to the sync server.
  void _syncWatchLaterToServer() {
    final data = _watchLaterItems.map((i) => {
      'id': i.id,
      'streamId': i.streamId,
      'title': i.title,
      'imagePath': i.imagePath,
      'contentType': i.contentType.toString(),
      'playlistId': i.playlistId,
    }).toList();
    SyncService.instance.pushField('watch_later', data);
  }
}
