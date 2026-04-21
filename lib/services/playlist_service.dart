import 'package:flutter/foundation.dart';
import '../models/playlist_model.dart';
import 'database_service.dart';
import 'sync_service.dart';

class PlaylistService {
  static Future<void> savePlaylist(Playlist playlist) async {
    await DatabaseService.savePlaylist(playlist);
    _pushPlaylistsToServer();
  }

  static Future<List<Playlist>> getPlaylists() async {
    return await DatabaseService.getPlaylists();
  }

  static Future<void> deletePlaylist(String id) async {
    await DatabaseService.deletePlaylist(id);
    _pushPlaylistsToServer();
  }

  static Future<void> updatePlaylist(Playlist playlist) async {
    await DatabaseService.updatePlaylist(playlist);
    _pushPlaylistsToServer();
  }

  static Future<Playlist?> getPlaylistById(String id) async {
    return await DatabaseService.getPlaylistById(id);
  }

  static Future<List<Playlist>> getXStreamPlaylists() async {
    return await DatabaseService.getPlaylistsByType(PlaylistType.xtream);
  }

  static Future<List<Playlist>> getM3UPlaylists() async {
    return await DatabaseService.getPlaylistsByType(PlaylistType.m3u);
  }

  /// Fire-and-forget push of all playlists to the sync server.
  static void _pushPlaylistsToServer() {
    () async {
      try {
        final allPlaylists = await getPlaylists();
        final jsonList = allPlaylists.map((p) => p.toJson()).toList();
        SyncService.instance.pushField('playlists', jsonList);
      } catch (e) {
        debugPrint('[PlaylistService] Auto-sync failed: $e');
      }
    }();
  }
}
