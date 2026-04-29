import 'package:c4tv_player/utils/get_playlist_type.dart';
import 'package:flutter/material.dart';
import 'package:c4tv_player/database/database.dart';
import 'package:c4tv_player/models/content_type.dart';
import 'package:c4tv_player/models/playlist_content_model.dart';
import 'package:c4tv_player/models/watch_history.dart';
import 'package:c4tv_player/services/app_state.dart';
import 'package:c4tv_player/services/watch_history_service.dart';
import 'package:c4tv_player/services/sync_service.dart';
import 'package:c4tv_player/utils/navigate_by_content_type.dart';
import '../services/service_locator.dart';

class WatchHistoryController extends ChangeNotifier {
  late WatchHistoryService _historyService;
  final _database = getIt<AppDatabase>();

  List<WatchHistory> _continueWatching = [];
  List<WatchHistory> _recentlyWatched = [];
  List<WatchHistory> _liveHistory = [];
  List<WatchHistory> _movieHistory = [];
  List<WatchHistory> _seriesHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Getters
  List<WatchHistory> get continueWatching => _continueWatching;

  List<WatchHistory> get recentlyWatched => _recentlyWatched;

  List<WatchHistory> get liveHistory => _liveHistory;

  List<WatchHistory> get movieHistory => _movieHistory;

  List<WatchHistory> get seriesHistory => _seriesHistory;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  WatchHistoryController() {
    _historyService = WatchHistoryService();
  }

  bool get isAllEmpty =>
      _continueWatching.isEmpty &&
      _recentlyWatched.isEmpty &&
      _liveHistory.isEmpty &&
      _movieHistory.isEmpty &&
      _seriesHistory.isEmpty;

  Future<void> loadWatchHistory() async {
    debugPrint('[WatchHistoryController] loadWatchHistory başladı');

    _isLoading = true;
    _errorMessage = null;
    _continueWatching.clear();
    _recentlyWatched.clear();
    _liveHistory.clear();
    _movieHistory.clear();
    _seriesHistory.clear();

    // Single notify for loading state
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());

    if (AppState.currentPlaylist == null) {
      debugPrint('[WatchHistoryController] Aktif playlist bulunamadı');
      _errorMessage = 'Aktif playlist bulunamadı';
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }

    final playlistId = AppState.currentPlaylist!.id;
    debugPrint('[WatchHistoryController] Playlist ID: $playlistId');

    try {
      final futures = await Future.wait([
        _historyService.getContinueWatching(playlistId),
        _historyService.getRecentlyWatched(limit: 20, playlistId),
        _historyService.getWatchHistoryByContentType(
          ContentType.liveStream,
          playlistId,
        ),
        _historyService.getWatchHistoryByContentType(
          ContentType.vod,
          playlistId,
        ),
        _historyService.getWatchHistoryByContentType(
          ContentType.series,
          playlistId,
        ),
      ]);

      _continueWatching = futures[0];
      _recentlyWatched = futures[1];
      _liveHistory = futures[2];
      _movieHistory = futures[3];
      _seriesHistory = futures[4];

      _isLoading = false;
      _errorMessage = null;

      // Single final notify — all data is ready
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      _syncContinueWatchingToServer();
    } catch (e) {
      _errorMessage = 'İzleme geçmişi yüklenirken hata oluştu: $e';
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  Future<void> playContent(BuildContext context, WatchHistory history) async {
    try {
      switch (history.contentType) {
        case ContentType.liveStream:
          await _playLiveStream(context, history);
          break;
        case ContentType.vod:
          await _playMovie(context, history);
          break;
        case ContentType.series:
          await _playSeries(context, history);
          break;
      }
    } catch (e) {
      _errorMessage = 'Video oynatılırken hata oluştu: $e';
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  Future<void> removeHistory(WatchHistory history) async {
    try {
      await _historyService.deleteWatchHistory(
        history.playlistId,
        history.streamId,
      );
      await loadWatchHistory();
    } catch (e) {
      _errorMessage = 'Hata oluştu: $e';
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _historyService.clearAllHistory();
      await loadWatchHistory();
    } catch (e) {
      _errorMessage = 'Hata oluştu: $e';
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  Future<void> _playLiveStream(
    BuildContext context,
    WatchHistory history,
  ) async {
    if (isXtreamCode) {
      final liveStream = await _database.findLiveStreamById(
        history.streamId,
        AppState.currentPlaylist!.id,
      );
      final contentItem = ContentItem(
        history.streamId,
        history.title,
        history.imagePath ?? '',
        history.contentType,
        liveStream: liveStream,
      );
      if (!context.mounted) return;
      navigateByContentType(context, contentItem);
    } else if (isM3u) {
      final liveStream = await _database.getM3uItemsByIdAndPlaylist(
        AppState.currentPlaylist!.id,
        history.streamId,
      );
      final contentItem = ContentItem(
        liveStream!.url,
        history.title,
        history.imagePath ?? '',
        history.contentType,
        m3uItem: liveStream,
      );
      if (!context.mounted) return;
      navigateByContentType(context, contentItem);
    }
  }

  Future<void> _playMovie(BuildContext context, WatchHistory history) async {
    if (isXtreamCode) {
      final movie = await _database.findMovieById(
        history.streamId,
        AppState.currentPlaylist!.id,
      );

      if (!context.mounted) return;
      navigateByContentType(
        context,
        ContentItem(
          history.streamId,
          history.title,
          history.imagePath ?? '',
          history.contentType,
          containerExtension: movie!.containerExtension,
          vodStream: movie,
        ),
      );
    } else if (isM3u) {
      var movie = await _database.getM3uItemsByIdAndPlaylist(
        AppState.currentPlaylist!.id,
        history.streamId,
      );

      if (!context.mounted) return;
      navigateByContentType(
        context,
        ContentItem(
          movie!.url,
          history.title,
          history.imagePath ?? '',
          history.contentType,
          m3uItem: movie,
        ),
      );
    }
  }

  Future<void> _playSeries(BuildContext context, WatchHistory history) async {
    if (isXtreamCode) {
      final episode = await _database.findEpisodesById(
        history.streamId,
        AppState.currentPlaylist!.id,
      );

      if (!context.mounted) return;
      navigateByContentType(
        context,
        ContentItem(
          episode!.episodeId.toString(),
          history.title,
          history.imagePath ?? "",
          ContentType.series,
          containerExtension: episode.containerExtension,
          season: episode.season,
        ),
      );
    } else if (isM3u) {
      var m3uItem = await _database.getM3uItemsByIdAndPlaylist(
        AppState.currentPlaylist!.id,
        history.streamId,
      );

      if (!context.mounted) return;
      navigateByContentType(
        context,
        ContentItem(
          m3uItem!.id,
          m3uItem.name ?? '',
          m3uItem.tvgLogo ?? '',
          m3uItem.contentType,
          m3uItem: m3uItem,
        ),
      );
    }
  }

  /// Fire-and-forget push of the continue_watching list to the sync server.
  void _syncContinueWatchingToServer() {
    final data = _continueWatching
        .map(
          (WatchHistory h) => {
            'streamId': h.streamId,
            'title': h.title,
            'imagePath': h.imagePath,
            'contentType': h.contentType.toString(),
            'playlistId': h.playlistId,
            'lastWatched': h.lastWatched.toIso8601String(),
            'watchDuration': h.watchDuration?.inMilliseconds,
            'totalDuration': h.totalDuration?.inMilliseconds,
          },
        )
        .toList();
    SyncService.instance.pushField('continue_watching', data);
  }
}
