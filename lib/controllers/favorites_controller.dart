import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/favorites_repository.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:another_iptv_player/services/sync_service.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:flutter/material.dart';

class FavoritesController extends ChangeNotifier {
  final FavoritesRepository _repository = FavoritesRepository();

  List<Favorite> _favorites = [];
  bool _isLoading = false;
  String? _error;

  List<Favorite> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Favorite> get liveStreamFavorites =>
      _favorites.where((f) => f.contentType == ContentType.liveStream).toList();

  List<Favorite> get movieFavorites =>
      _favorites.where((f) => f.contentType == ContentType.vod).toList();

  List<Favorite> get seriesFavorites =>
      _favorites.where((f) => f.contentType == ContentType.series).toList();

  int get totalFavoriteCount => _favorites.length;
  int get liveStreamFavoriteCount => liveStreamFavorites.length;
  int get movieFavoriteCount => movieFavorites.length;
  int get seriesFavoriteCount => seriesFavorites.length;

  Future<void> loadFavorites() async {
    debugPrint('[FavoritesController] loadFavorites başladı');
    try {
      _setLoading(true);
      _setError(null);

      _favorites.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());

      _favorites = await _repository.getAllFavorites();
      debugPrint('[FavoritesController] ${_favorites.length} favori yüklendi');
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } catch (e) {
      debugPrint('[FavoritesController] Hata: $e');
      _setError('Favoriler yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addFavorite(ContentItem contentItem) async {
    try {
      _setError(null);

      await _repository.addFavorite(contentItem);
      await loadFavorites();
      _syncFavoritesToServer();

      return true;
    } catch (e) {
      _setError('Favori eklenirken hata oluştu: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(
    String streamId,
    ContentType contentType, {
    String? episodeId,
  }) async {
    try {
      _setError(null);

      await _repository.removeFavorite(
        streamId,
        contentType,
        episodeId: episodeId,
      );
      await loadFavorites();
      _syncFavoritesToServer();

      return true;
    } catch (e) {
      _setError('Favori kaldırılırken hata oluştu: \$e');
      return false;
    }
  }

  Future<bool> toggleFavorite(ContentItem contentItem) async {
    try {
      _setError(null);

      final result = await _repository.toggleFavorite(contentItem);
      await loadFavorites();
      _syncFavoritesToServer();

      return result;
    } catch (e) {
      _setError('Favori işlemi sırasında hata oluştu: \$e');
      return false;
    }
  }

  Future<bool> isFavorite(
    String streamId,
    ContentType contentType, {
    String? episodeId,
  }) async {
    try {
      return await _repository.isFavorite(
        streamId,
        contentType,
        episodeId: episodeId,
      );
    } catch (e) {
      _setError('Favori kontrolü sırasında hata oluştu: $e');
      return false;
    }
  }

  Future<List<Favorite>> getFavoritesByContentType(
    ContentType contentType,
  ) async {
    try {
      return await _repository.getFavoritesByContentType(contentType);
    } catch (e) {
      _setError('Favoriler getirilirken hata oluştu: $e');
      return [];
    }
  }

  Future<int> getFavoriteCount() async {
    try {
      return await _repository.getFavoriteCount();
    } catch (e) {
      _setError('Favori sayısı getirilirken hata oluştu: $e');
      return 0;
    }
  }

  Future<int> getFavoriteCountByContentType(ContentType contentType) async {
    try {
      return await _repository.getFavoriteCountByContentType(contentType);
    } catch (e) {
      _setError('Favori sayısı getirilirken hata oluştu: $e');
      return 0;
    }
  }

  Future<bool> updateFavorite(Favorite favorite) async {
    try {
      _setError(null);

      await _repository.updateFavorite(favorite);
      await loadFavorites();

      return true;
    } catch (e) {
      _setError('Favori güncellenirken hata oluştu: $e');
      return false;
    }
  }

  /// Persists a new live-TV sort order.
  /// [orderedIds] is the list of Favorite.id values in the new display order.
  Future<void> reorderLiveFavorites(List<String> orderedIds) async {
    try {
      await _repository.reorderLiveFavorites(orderedIds);
      await loadFavorites();
      _syncFavoritesToServer();
    } catch (e) {
      _setError('Sıralama kaydedilirken hata oluştu: \$e');
    }
  }

  Future<bool> clearAllFavorites() async {
    try {
      _setError(null);

      await _repository.clearAllFavorites();
      _favorites.clear();
      notifyListeners();
      _syncFavoritesToServer();

      return true;
    } catch (e) {
      _setError('Favoriler temizlenirken hata oluştu: \$e');
      return false;
    }
  }

  Future<void> playFavorite(BuildContext context, Favorite favorite) async {
    try {
      final contentItem = await resolveContentItem(favorite);
      if (context.mounted) {
        await navigateByContentType(context, contentItem);
      }
    } catch (e) {
      debugPrint('[FavoritesController] playFavorite error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not play: $e')));
      }
    }
  }

  /// Builds a complete ContentItem with liveStream/m3uItem properly set,
  /// so navigateByContentType routes to the correct screen.
  Future<ContentItem> resolveContentItem(Favorite fav) async {
    if (fav.contentType == ContentType.liveStream) {
      if (isXtreamCode) {
        // Look up the live channel from the local database
        try {
          final liveStream = await AppState.xtreamCodeRepository
              ?.findLiveStreamById(fav.streamId);
          if (liveStream != null) {
            return ContentItem(
              liveStream.streamId,
              liveStream.name,
              liveStream.streamIcon,
              ContentType.liveStream,
              liveStream: liveStream,
            );
          }
        } catch (e) {
          debugPrint('[FavoritesController] xtream lookup failed: $e');
        }
      } else if (isM3u) {
        try {
          final m3uItem = await AppState.m3uRepository?.getM3uItemByUrl(
            url: fav.streamId,
          );
          if (m3uItem != null) {
            return ContentItem(
              m3uItem.url,
              m3uItem.name ?? fav.name,
              m3uItem.tvgLogo ?? fav.imagePath ?? '',
              ContentType.liveStream,
              m3uItem: m3uItem,
            );
          }
        } catch (e) {
          debugPrint('[FavoritesController] m3u lookup failed: $e');
        }
      }
    }

    // For VOD/Series or if the lookup above failed, use the stored data.
    // navigateByContentType handles these correctly already.
    return ContentItem(
      fav.streamId,
      fav.name,
      fav.imagePath ?? '',
      fav.contentType,
    );
  }

  List<Favorite> searchFavorites(String query) {
    if (query.isEmpty) return _favorites;

    return _favorites
        .where(
          (favorite) =>
              favorite.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  List<Favorite> filterFavoritesByContentType(ContentType contentType) {
    return _favorites
        .where((favorite) => favorite.contentType == contentType)
        .toList();
  }

  void clearError() {
    _setError(null);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  void _setError(String? error) {
    _error = error;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  /// Fire-and-forget push of the current favorites list to the sync server.
  void _syncFavoritesToServer() {
    final data = _favorites
        .map(
          (f) => {
            'id': f.id,
            'streamId': f.streamId,
            'name': f.name,
            'imagePath': f.imagePath,
            'contentType': f.contentType.toString(),
            'episodeId': f.episodeId,
            'sortOrder': f.sortOrder,
          },
        )
        .toList();
    SyncService.instance.pushField('favorites', data);
  }
}
