import 'dart:convert';
import 'package:another_iptv_player/models/m3u_item.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

import '../database/database.dart';

import 'service_locator.dart';

abstract class AppState {
  static Playlist? _currentPlaylist;
  static Playlist? get currentPlaylist => _currentPlaylist;
  static set currentPlaylist(Playlist? value) {
    _currentPlaylist = value;
    if (value != null) {
      UserPreferences.setCurrentPlaylistJson(jsonEncode(value.toJson()));
    }
  }

  static IptvRepository? xtreamCodeRepository;
  static M3uRepository? m3uRepository;
  static List<M3uItem>? m3uItems;
  static final AppDatabase database = getIt<AppDatabase>();
}
