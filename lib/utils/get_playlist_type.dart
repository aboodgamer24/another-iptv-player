import 'package:c4tv_player/models/playlist_model.dart';
import 'package:c4tv_player/services/app_state.dart';

PlaylistType getPlaylistType() {
  return AppState.currentPlaylist!.type;
}

bool get isXtreamCode {
  return getPlaylistType() == PlaylistType.xtream;
}

bool get isM3u {
  return getPlaylistType() == PlaylistType.m3u;
}
