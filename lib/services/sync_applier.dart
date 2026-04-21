import 'package:flutter/foundation.dart';
import '../database/database.dart';
import '../models/content_type.dart';
import '../models/favorite.dart';
import '../models/playlist_model.dart';
import '../repositories/user_preferences.dart';
import 'database_service.dart';
import 'playlist_service.dart';
import 'service_locator.dart';
import 'sync_service.dart';

class SyncApplier {
  /// Pull from server and apply all data locally.
  /// Returns true if sync was successful.
  static Future<bool> pullAndApply() async {
    try {
      final data = await SyncService.instance.pullSync();
      if (data == null) {
        debugPrint('[SyncApplier] pullSync returned null');
        return false;
      }

      debugPrint('[SyncApplier] Server data: playlists=${(data['playlists'] as List?)?.length ?? 0}, favorites=${(data['favorites'] as List?)?.length ?? 0}, watch_later=${(data['watch_later'] as List?)?.length ?? 0}');

      // 1. Apply settings first (populates last_playlist_id, tmdb key, etc.)
      await _applySettings(data['settings']);

      // 2. Apply last playlist selection from settings
      final rawLastPlaylistId = data['settings']?['last_playlist_id'];
      if (rawLastPlaylistId is String && rawLastPlaylistId.isNotEmpty) {
        await UserPreferences.setLastPlaylist(rawLastPlaylistId);
        debugPrint('[SyncApplier] Set last_playlist_id from settings: $rawLastPlaylistId');
      }

      // 3. Restore playlists (will set fallback last_playlist_id if not set above)
      await _applyPlaylists(data['playlists']);

      // 4. Restore favorites
      await _applyFavorites(data['favorites']);

      // 5. Restore watch later
      await _applyWatchLater(data['watch_later']);

      debugPrint('[SyncApplier] ✅ Sync applied successfully');
      return true;
    } catch (e, stack) {
      debugPrint('[SyncApplier] pullAndApply error: $e\n$stack');
      return false;
    }
  }

  /// Apply playlists — only add ones that don't exist locally.
  /// Uses DatabaseService directly to avoid triggering auto-push during restore.
  static Future<void> _applyPlaylists(dynamic rawPlaylists) async {
    if (rawPlaylists == null || rawPlaylists is! List || rawPlaylists.isEmpty) {
      debugPrint('[SyncApplier] No playlists to restore');
      return;
    }

    String? firstRestoredId;

    for (final p in rawPlaylists) {
      try {
        final playlist = Playlist.fromJson(Map<String, dynamic>.from(p));
        final existing = await PlaylistService.getPlaylistById(playlist.id);
        if (existing == null) {
          // Write directly to DB — skip PlaylistService to avoid triggering
          // another pushField during bulk restore
          await DatabaseService.savePlaylist(playlist);
          debugPrint('[SyncApplier] Restored playlist: ${playlist.name} (${playlist.type})');
          firstRestoredId ??= playlist.id;
        } else {
          debugPrint('[SyncApplier] Playlist already exists locally: ${playlist.name}');
          firstRestoredId ??= existing.id;
        }
      } catch (e) {
        debugPrint('[SyncApplier] Failed to apply playlist: $e');
      }
    }

    // Set last_playlist_id to first restored playlist if not already set
    final currentLast = await UserPreferences.getLastPlaylist();
    if ((currentLast == null || currentLast.isEmpty) && firstRestoredId != null) {
      await UserPreferences.setLastPlaylist(firstRestoredId);
      debugPrint('[SyncApplier] Set last playlist fallback to: $firstRestoredId');
    }
  }

  /// Apply favorites — insert into Drift DB, skip duplicates.
  static Future<void> _applyFavorites(dynamic rawFavorites) async {
    if (rawFavorites == null || rawFavorites is! List || rawFavorites.isEmpty) {
      return;
    }

    final db = getIt<AppDatabase>();

    for (final f in rawFavorites) {
      try {
        final map = Map<String, dynamic>.from(f);
        final contentType = _parseContentType(map['contentType']);
        if (contentType == null) continue;

        final id = map['id'] as String? ?? '';
        final playlistId = map['playlistId'] as String? ?? '';
        final streamId = map['streamId'] as String? ?? '';
        final name = map['name'] as String? ?? '';
        if (id.isEmpty || streamId.isEmpty) continue;

        final favorite = Favorite(
          id: id,
          playlistId: playlistId,
          contentType: contentType,
          streamId: streamId,
          episodeId: map['episodeId'] as String?,
          name: name,
          imagePath: map['imagePath'] as String?,
          sortOrder: (map['sortOrder'] as int?) ?? 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Use insertOnConflictUpdate-style via try/catch to skip dupes
        try {
          await db.insertFavorite(favorite);
        } catch (_) {
          // Already exists — skip
        }
      } catch (e) {
        debugPrint('[SyncApplier] Failed to apply favorite: $e');
      }
    }
  }

  /// Apply watch later — insert into Drift DB, skip duplicates.
  static Future<void> _applyWatchLater(dynamic rawWatchLater) async {
    if (rawWatchLater == null ||
        rawWatchLater is! List ||
        rawWatchLater.isEmpty) {
      return;
    }

    final db = getIt<AppDatabase>();

    for (final w in rawWatchLater) {
      try {
        final map = Map<String, dynamic>.from(w);
        final contentType = _parseContentType(map['contentType']);
        if (contentType == null) continue;

        final id = map['id'] as String? ?? '';
        final playlistId = map['playlistId'] as String? ?? '';
        final streamId = map['streamId'] as String? ?? '';
        final title = map['title'] as String? ?? '';
        if (id.isEmpty || streamId.isEmpty) continue;

        final entry = WatchLaterData(
          id: id,
          playlistId: playlistId,
          contentType: contentType,
          streamId: streamId,
          title: title,
          imagePath: map['imagePath'] as String?,
          addedAt: DateTime.now(),
        );

        // insertOnConflictUpdate handles duplicates gracefully
        await db.insertWatchLater(entry);
      } catch (e) {
        debugPrint('[SyncApplier] Failed to apply watch later item: $e');
      }
    }
  }

  /// Apply settings snapshot from server.
  static Future<void> _applySettings(dynamic rawSettings) async {
    if (rawSettings == null || rawSettings is! Map) return;

    final settings = Map<String, dynamic>.from(rawSettings);
    await UserPreferences.applySyncedSettings(settings);
  }

  /// Parse a ContentType from its toString() representation.
  /// Supports both "ContentType.liveStream" and "liveStream" formats.
  static ContentType? _parseContentType(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    for (final ct in ContentType.values) {
      if (ct.toString() == str || ct.name == str) return ct;
    }
    return null;
  }
}
