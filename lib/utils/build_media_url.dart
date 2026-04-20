import 'package:another_iptv_player/services/app_state.dart';

import '../models/content_type.dart';
import '../models/playlist_content_model.dart';

/// Strips trailing slash and `/player_api.php` from the raw playlist URL
/// so that stream paths (/movie/, /series/, /live/) resolve correctly.
String _normalizeStreamBaseUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return '';
  var base = rawUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  const suffix = '/player_api.php';
  if (base.toLowerCase().endsWith(suffix)) {
    base = base.substring(0, base.length - suffix.length);
  }
  return base;
}

String buildMediaUrl(ContentItem contentItem) {
  final playlist = AppState.currentPlaylist!;
  final baseUrl = _normalizeStreamBaseUrl(playlist.url);

  // Resolve extension: prefer the item's own field, then fall back to
  // the VodStream / SeriesStream extension, then default to 'mkv'.
  String _ext(String? direct, String? fallback) {
    final e = (direct ?? '').trim().isNotEmpty
        ? direct!.trim()
        : (fallback ?? '').trim();
    return e.isNotEmpty ? e : 'mkv';
  }

  switch (contentItem.contentType) {
    case ContentType.liveStream:
      return '$baseUrl/${playlist.username}/${playlist.password}/${contentItem.id}';

    case ContentType.vod:
      final ext = _ext(
        contentItem.containerExtension,
        contentItem.vodStream?.containerExtension,
      );
      return '$baseUrl/movie/${playlist.username}/${playlist.password}/${contentItem.id}.$ext';

    case ContentType.series:
      final ext = _ext(
        contentItem.containerExtension,
        null,
      );
      return '$baseUrl/series/${playlist.username}/${playlist.password}/${contentItem.id}.$ext';
  }
}
