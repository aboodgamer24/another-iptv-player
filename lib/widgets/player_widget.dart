import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:another_iptv_player/utils/subtitle_configuration.dart';
import 'package:another_iptv_player/widgets/video_widget.dart';
import 'package:another_iptv_player/widgets/player/c4_player_overlay.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/content_type.dart';
import '../../services/player_state.dart';
import '../utils/player_error_handler.dart';
import '../services/fullscreen_notifier.dart';
import '../utils/responsive_helper.dart';
import '../services/upscale_service.dart';
import '../utils/platform_utils.dart';

class PlayerWidget extends StatefulWidget {
  final ContentItem contentItem;
  final double? aspectRatio;
  final bool showControls;
  final bool showInfo;
  final VoidCallback? onFullscreen;
  final List<ContentItem>? queue;
  final bool isInline;
  final bool showPersistentSidebar;

  const PlayerWidget({
    super.key,
    required this.contentItem,
    this.aspectRatio,
    this.showControls = true,
    this.showInfo = false,
    this.onFullscreen,
    this.queue,
    this.isInline = false,
    this.showPersistentSidebar = false,
  });

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget>
    with WidgetsBindingObserver {
  late StreamSubscription videoTrackSubscription;
  late StreamSubscription audioTrackSubscription;
  late StreamSubscription subtitleTrackSubscription;
  late StreamSubscription contentItemIndexChangedSubscription;
  late StreamSubscription _connectivitySubscription;
  late StreamSubscription _lowLatencySubscription;

  late Player _player;
  VideoController? _videoController;
  late WatchHistoryService watchHistoryService;
  List<ContentItem>? _queue;
  late ContentItem contentItem;
  final PlayerErrorHandler _errorHandler = PlayerErrorHandler();
  final _overlayKey = GlobalKey<C4PlayerOverlayState>();

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool _wasDisconnected = false;
  bool _isFirstCheck = true;
  int _currentItemIndex = 0;
  bool _showChannelList = false;
  bool _isSwitchingChannel = false;
  Timer? _watchHistoryTimer;
  Duration? _pendingWatchDuration;
  Duration? _pendingTotalDuration;
  Duration _lastSavedPosition = Duration.zero;
  DateTime _lastSeekTime = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    contentItem = widget.contentItem;
    _queue = widget.queue;

    // --- INSERTION 1: INITIAL CONTENT SET ---
    PlayerState.currentContent = widget.contentItem;
    PlayerState.queue = _queue;
    PlayerState.currentIndex = 0;
    // ----------------------------------------

    PlayerState.title = widget.contentItem.name;
    _player = Player(
      configuration: PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    PlayerState.activePlayer = _player;
    watchHistoryService = WatchHistoryService();

    super.initState();

    // Android: auto-enter fullscreen as soon as player mounts
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enterAndroidFullscreen();
      });
    }
    videoTrackSubscription = EventBus()
        .on<VideoTrack>('video_track_changed')
        .listen((VideoTrack data) async {
          PlayerState.pendingTrackRestorePosition = _player.state.position;
          PlayerState.pendingTrackRestoreTime = DateTime.now();
          await _player.setVideoTrack(data);
          await UserPreferences.setVideoTrack(data.id);
        });

    audioTrackSubscription = EventBus()
        .on<AudioTrack>('audio_track_changed')
        .listen((AudioTrack data) async {
          PlayerState.pendingTrackRestorePosition = _player.state.position;
          PlayerState.pendingTrackRestoreTime = DateTime.now();
          await _player.setAudioTrack(data);
          await UserPreferences.setAudioTrack(data.language ?? 'null');
        });

    subtitleTrackSubscription = EventBus()
        .on<SubtitleTrack>('subtitle_track_changed')
        .listen((SubtitleTrack data) async {
          PlayerState.pendingTrackRestorePosition = _player.state.position;
          PlayerState.pendingTrackRestoreTime = DateTime.now();
          await _player.setSubtitleTrack(data);
          await UserPreferences.setSubtitleTrack(data.language ?? 'null');
        });

    _initializePlayer();

    _lowLatencySubscription = EventBus().on<bool>('low_latency_changed').listen(
      (bool enabled) async {
        if (enabled) {
          await _applyLowLatencyProperties();
        } else {
          await _applyUserPreferenceProperties();
        }
      },
    );
  }

  @override
  void dispose() {
    // Cancel timer and save watch history one last time before disposing
    _watchHistoryTimer?.cancel();
    if (_pendingWatchDuration != null) {
      // Use unawaited to save without blocking dispose
      _saveWatchHistory().catchError((e) {
        // Ignore errors during dispose
      });
    }

    PlayerState.activePlayer = null;
    _player.dispose();
    videoTrackSubscription.cancel();
    audioTrackSubscription.cancel();
    subtitleTrackSubscription.cancel();
    contentItemIndexChangedSubscription.cancel();
    _connectivitySubscription.cancel();
    _lowLatencySubscription.cancel();
    _errorHandler.reset();

    // Android: restore portrait + system UI when player closes
    if (Platform.isAndroid && !PlatformUtils.isTV) {
      fullscreenNotifier.value = false;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    super.dispose();
  }

  void _enterAndroidFullscreen() {
    if (!mounted) return;
    // Set the global fullscreen notifier so the shell hides AppBar + BottomNav
    fullscreenNotifier.value = true;
    // Force landscape + hide system UI for true immersive fullscreen
    // On Android TV the system is always landscape — don't force rotate
    if (!PlatformUtils.isTV) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Apply critical MPV properties that must be set BEFORE media opens.
  /// Call this once after creating the Player, before any player.open() call.
  Future<void> _applyPreOpenMpvProperties() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    try {
      if (Platform.isAndroid) {
        // --- Properties common to ALL content types ---
        await native.setProperty('hwdec', 'mediacodec-copy');
        await native.setProperty('hwdec-codecs', 'all');
        await native.setProperty('interpolation', 'no');
        await native.setProperty('scale', 'bilinear');
        await native.setProperty('cscale', 'bilinear');
        await native.setProperty('dscale', 'bilinear');
        await native.setProperty('scale-antiring', '0.0');
        await native.setProperty('sigmoid-upscaling', 'no');
        await native.setProperty('linear-upscaling', 'no');
        await native.setProperty('correct-downscaling', 'no');
        await native.setProperty('deinterlace', 'no');

        if (contentItem.contentType == ContentType.liveStream) {
          // --- LIVE STREAM: low-latency, small cache, aggressive framedrop ---
          await native.setProperty('video-sync', 'audio');
          await native.setProperty('framedrop', 'decoder+vo');
          await native.setProperty('cache', 'yes');
          await native.setProperty('demuxer-max-bytes', '32MiB');
          await native.setProperty('demuxer-max-back-bytes', '4MiB');
          await native.setProperty('demuxer-readahead-secs', '0.5');
          await native.setProperty('cache-secs', '2');
          await native.setProperty('demuxer-cache-wait', 'no');
          await native.setProperty('initial-audio-sync', 'no');
        } else {
          // --- VOD / SERIES: seekable, larger cache, no framedrop ---
          // video-sync=display-resample works better for fixed-fps VOD files
          await native.setProperty('video-sync', 'display-resample');
          // Never drop frames on VOD — buffer more instead
          await native.setProperty('framedrop', 'no');
          // Large demuxer cache so MPV can build a full seek index
          await native.setProperty('cache', 'yes');
          await native.setProperty('demuxer-max-bytes', '64MiB');
          await native.setProperty('demuxer-max-back-bytes', '32MiB');
          await native.setProperty('demuxer-readahead-secs', '5.0');
          await native.setProperty('cache-secs', '30');
          // 'yes' stalls HLS VOD indefinitely. Use 'no' and let MPV seek
          // on-demand — the large cache (64MiB) handles it gracefully.
          await native.setProperty('demuxer-cache-wait', 'no');
          await native.setProperty('initial-audio-sync', 'yes');
          // Smooth A/V sync for VOD
          await native.setProperty('audio-buffer', '0.2');
        }
      } else {
        // --- Desktop: same split ---
        await native.setProperty('hwdec', 'auto');
        await native.setProperty('hwdec-codecs', 'all');
        await native.setProperty('interpolation', 'no');
        await native.setProperty('tscale', 'oversample');
        await native.setProperty('deinterlace', 'no');

        if (contentItem.contentType == ContentType.liveStream) {
          await native.setProperty('video-sync', 'audio');
          await native.setProperty('framedrop', 'no');
          await native.setProperty('demuxer-max-bytes', '50MiB');
          await native.setProperty('demuxer-max-back-bytes', '10MiB');
          await native.setProperty('cache-secs', '5');
        } else {
          // VOD/series on desktop
          await native.setProperty('video-sync', 'display-resample');
          await native.setProperty('framedrop', 'no');
          await native.setProperty('demuxer-max-bytes', '150MiB');
          await native.setProperty('demuxer-max-back-bytes', '50MiB');
          await native.setProperty('cache-secs', '60');
          await native.setProperty('audio-buffer', '0.2');
        }
      }
    } catch (e) {
      debugPrint('[Player] Pre-open MPV properties failed: $e');
    }
  }

  /// Apply user-preference-based properties AFTER media is open.
  Future<void> _applyUserPreferenceProperties() async {
    if (!Platform.isAndroid) {
      final preset = await UserPreferences.getUpscalePreset();
      await applyUpscalePreset(_player, preset);
    }
    final enhancementEnabled = await UserPreferences.getStreamEnhancement();
    await applyStreamEnhancement(_player, enhancementEnabled);
  }

  Future<void> _applyLowLatencyProperties() async {
    // Low latency is meaningless and harmful for VOD/series — skip
    if (contentItem.contentType != ContentType.liveStream) return;

    final native = _player.platform;
    if (native is! NativePlayer) return;
    try {
      await native.setProperty('demuxer-readahead-secs', '0.1');
      await native.setProperty('cache-secs', '1');
      await native.setProperty('demuxer-cache-wait', 'no');
      await native.setProperty('vd-lavc-skiploopfilter', 'nonref');
      await native.setProperty('vd-lavc-skipframe', 'nonref');
    } catch (e) {
      debugPrint('[Player] Low-latency properties failed: $e');
    }
  }

  Future<void> _saveWatchHistory() async {
    if (_pendingWatchDuration == null || !mounted) return;

    try {
      await watchHistoryService.saveWatchHistory(
        WatchHistory(
          playlistId: AppState.currentPlaylist!.id,
          contentType: contentItem.contentType,
          streamId: isXtreamCode
              ? contentItem.id
              : contentItem.m3uItem?.id ?? contentItem.id,
          lastWatched: DateTime.now(),
          title: contentItem.name,
          imagePath: contentItem.imagePath,
          totalDuration: _pendingTotalDuration,
          watchDuration: _pendingWatchDuration,
          seriesId: contentItem.seriesStream?.seriesId,
        ),
      );
      _pendingWatchDuration = null;
      _pendingTotalDuration = null;
    } catch (e) {
      // Silently handle database errors to prevent crashes
      // The next save attempt will retry
      debugPrint('Error saving watch history: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    try {
      PlayerState.subtitleConfiguration = await getSubtitleConfiguration();

      PlayerState.backgroundPlay = await UserPreferences.getBackgroundPlay();
      _videoController = VideoController(
        _player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      await _applyPreOpenMpvProperties();

      var watchHistory = await watchHistoryService.getWatchHistory(
        AppState.currentPlaylist!.id,
        isXtreamCode
            ? contentItem.id
            : contentItem.m3uItem?.id ?? contentItem.id,
      );

      if (_queue != null) {
        List<Media> medias = [];
        for (int i = 0; i < _queue!.length; i++) {
          final item = _queue![i];
          final itemWatchHistory = await watchHistoryService.getWatchHistory(
            AppState.currentPlaylist!.id,
            isXtreamCode ? item.id : item.m3uItem?.id ?? item.id,
          );
          final startMs = itemWatchHistory?.watchDuration?.inMilliseconds ?? 0;
          medias.add(Media(item.url, start: Duration(milliseconds: startMs)));

          if (item.id == contentItem.id) {
            _currentItemIndex = i;
            contentItem = item;
            EventBus().emit('player_content_item', item);
            EventBus().emit('player_content_item_index', i);
          }
        }

        if (contentItem.contentType != ContentType.liveStream) {
          _overlayKey.currentState?.resetContentState(newUrl: contentItem.url);
          await _player.open(
            Media(
              contentItem.url,
              start: watchHistory?.watchDuration ?? Duration.zero,
            ),
            play: true,
          );
          await _applyUserPreferenceProperties();
          if (await UserPreferences.getLowLatencyMode()) {
            await _applyLowLatencyProperties();
          }
          if (mounted) setState(() => isLoading = false);
        } else {
          _overlayKey.currentState?.resetContentState(newUrl: contentItem.url);
          await _player.open(Media(contentItem.url));
          await _applyUserPreferenceProperties();
          if (await UserPreferences.getLowLatencyMode()) {
            await _applyLowLatencyProperties();
          }
          if (mounted) setState(() => isLoading = false);
        }
      } else {
        _overlayKey.currentState?.resetContentState(newUrl: contentItem.url);
        await _player.open(
          Media(
            contentItem.url,
            start: watchHistory?.watchDuration ?? Duration(),
          ),
          play: true,
        );
        await _applyUserPreferenceProperties();
        if (await UserPreferences.getLowLatencyMode()) {
          await _applyLowLatencyProperties();
        }
        if (mounted) setState(() => isLoading = false);
      }

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) async {
        bool hasConnection = results.any(
          (connectivity) =>
              connectivity == ConnectivityResult.mobile ||
              connectivity == ConnectivityResult.wifi ||
              connectivity == ConnectivityResult.ethernet,
        );

        if (_isFirstCheck) {
          final currentConnectivity = await Connectivity().checkConnectivity();
          hasConnection = currentConnectivity.any(
            (connectivity) =>
                connectivity == ConnectivityResult.mobile ||
                connectivity == ConnectivityResult.wifi ||
                connectivity == ConnectivityResult.ethernet,
          );
          _isFirstCheck = false;
        }

        if (hasConnection) {
          if (_wasDisconnected &&
              contentItem.contentType == ContentType.liveStream &&
              contentItem.url.isNotEmpty) {
            try {
              if (!mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Online",
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                ),
              );

              _overlayKey.currentState?.resetContentState(
                newUrl: contentItem.url,
              );
              await _player.open(Media(contentItem.url));
              await _applyUserPreferenceProperties();
              if (await UserPreferences.getLowLatencyMode()) {
                await _applyLowLatencyProperties();
              }
              if (mounted) setState(() => isLoading = false);
            } catch (e) {
              debugPrint('Error opening media: $e');
            }
          }
          _wasDisconnected = false;
        } else {
          _wasDisconnected = true;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "No Connection",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      _player.stream.tracks.listen((event) async {
        if (!mounted) return;

        PlayerState.videos = event.video;
        PlayerState.audios = event.audio;
        PlayerState.subtitles = event.subtitle;

        EventBus().emit('player_tracks', event);

        await _player.setVideoTrack(
          VideoTrack(await UserPreferences.getVideoTrack(), null, null),
        );

        var selectedAudioLanguage = await UserPreferences.getAudioTrack();
        var possibleAudioTrack = event.audio.firstWhere(
          (x) => x.language == selectedAudioLanguage,
          orElse: AudioTrack.auto,
        );

        await _player.setAudioTrack(possibleAudioTrack);

        var selectedSubtitleLanguage = await UserPreferences.getSubtitleTrack();
        var possibleSubtitleLanguage = event.subtitle.firstWhere(
          (x) => x.language == selectedSubtitleLanguage,
          orElse: SubtitleTrack.auto,
        );

        await _player.setSubtitleTrack(possibleSubtitleLanguage);
      });

      _player.stream.track.listen((event) async {
        if (!mounted) return;

        PlayerState.selectedVideo = _player.state.track.video;
        PlayerState.selectedAudio = _player.state.track.audio;
        PlayerState.selectedSubtitle = _player.state.track.subtitle;

        // Track değişikliğini bildir
        EventBus().emit('player_track_changed', null);

        var volume = await UserPreferences.getVolume();
        await _player.setVolume(volume);
      });

      _player.stream.volume.listen((event) async {
        await UserPreferences.setVolume(event);
      });

      _player.stream.position.listen((position) {
        _pendingWatchDuration = position;
        _pendingTotalDuration = _player.state.duration;

        if (PlayerState.pendingTrackRestorePosition != null &&
            PlayerState.pendingTrackRestoreTime != null) {
          final timeSinceGuard = DateTime.now().difference(
            PlayerState.pendingTrackRestoreTime!,
          );
          if (timeSinceGuard.inSeconds < 5) {
            if (position < const Duration(seconds: 1) &&
                PlayerState.pendingTrackRestorePosition!.inSeconds > 2) {
              final restorePos = PlayerState.pendingTrackRestorePosition!;
              _player.seek(restorePos);
              // We intentionally do NOT null out the guard yet in case MPV drops it again during the seek
            } else if (position > const Duration(seconds: 1)) {
              // If it successfully passed 1s (or successfully restored), we can clear the guard
              if (timeSinceGuard.inMilliseconds > 500) {
                PlayerState.pendingTrackRestorePosition = null;
                PlayerState.pendingTrackRestoreTime = null;
              }
            }
          } else {
            // Expire guard after 5 seconds
            PlayerState.pendingTrackRestorePosition = null;
            PlayerState.pendingTrackRestoreTime = null;
          }
        }

        // Detect manual seek jumps (> 5 seconds)
        if ((position - _lastPosition).abs() > const Duration(seconds: 5)) {
          _lastSeekTime = DateTime.now();
        }
        _lastPosition = position;

        // Only reschedule a save if position moved more than 5 seconds
        // since the last save trigger — avoids timer churn during pause/seek.
        if ((position - _lastSavedPosition).abs() >
            const Duration(seconds: 5)) {
          _watchHistoryTimer?.cancel();
          _watchHistoryTimer = Timer(const Duration(seconds: 5), () {
            _lastSavedPosition = position;
            _saveWatchHistory();
          });
        }
      });

      _player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        // For live streams, never hide the video widget on buffer events.
        // Doing so causes the video to go black while audio continues playing.
        if (contentItem.contentType == ContentType.liveStream) return;
        if (buffering != isLoading) {
          setState(() => isLoading = buffering);
        }
      });

      _player.stream.playing.listen((playing) async {
        if (!mounted) return;
        // Properties are applied pre-open; no re-application needed on play events.
      });

      _player.stream.error.listen((error) async {
        if (error.contains('Failed to open')) {
          _errorHandler.handleError(
            error,
            () async {
              if (_isSwitchingChannel) return;

              // Guard against transient errors during/immediately after a seek
              final timeSinceSeek = DateTime.now().difference(_lastSeekTime);
              if (timeSinceSeek.inSeconds < 3) {
                debugPrint('Ignoring player error due to recent seek: $error');
                return;
              }

              if (contentItem.contentType == ContentType.liveStream) {
                _overlayKey.currentState?.resetContentState(
                  newUrl: contentItem.url,
                );
                await _player.open(Media(contentItem.url));
                await _applyUserPreferenceProperties();
                if (await UserPreferences.getLowLatencyMode()) {
                  await _applyLowLatencyProperties();
                }
                if (mounted) setState(() => isLoading = false);
              }
            },
            (errorMessage) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          );
        }
      });

      _player.stream.playlist.listen((playlist) {
        if (!mounted) return;

        // While we are manually switching episodes/channels via
        // player_content_item_index_changed, the internal playlist index is
        // still 0 (media_kit hasn't moved yet). Trusting it here would
        // overwrite the contentItem we just set, causing the player to restart
        // from episode 0. Skip the update entirely while a switch is in flight.
        if (_isSwitchingChannel) return;

        _currentItemIndex = playlist.index;
        contentItem = _queue?[playlist.index] ?? widget.contentItem;

        // --- INSERTION 2: QUEUE CHANGE SETTER ---
        PlayerState.currentContent = contentItem;
        PlayerState.currentIndex = _currentItemIndex;
        // ----------------------------------------

        PlayerState.title = contentItem.name;
        EventBus().emit('player_content_item', contentItem);
        EventBus().emit('player_content_item_index', playlist.index);
      });

      _player.stream.completed.listen((completed) async {
        if (!completed) return; // false = stopped, not finished — ignore
        if (_isSwitchingChannel) return;

        // Guard against transient completion events during/immediately after a seek
        final timeSinceSeek = DateTime.now().difference(_lastSeekTime);
        if (timeSinceSeek.inSeconds < 3) {
          debugPrint('Ignoring player completion due to recent seek');
          return;
        }

        // Only auto-restart live streams on true completion.
        // VOD/Series completion is handled by the Playlist — do nothing.
        if (contentItem.contentType == ContentType.liveStream) {
          if (!mounted) return;
          _overlayKey.currentState?.resetContentState(newUrl: contentItem.url);
          await _player.open(Media(contentItem.url));
          await _applyUserPreferenceProperties();
          if (await UserPreferences.getLowLatencyMode()) {
            await _applyLowLatencyProperties();
          }
          if (mounted) setState(() => isLoading = false);
        }
      });

      contentItemIndexChangedSubscription = EventBus()
          .on<int>('player_content_item_index_changed')
          .listen((int index) async {
            if (contentItem.contentType == ContentType.liveStream) {
              // Guard against concurrent open() calls — rapid taps can
              // overlap and crash the native D3D/ANGLE video pipeline.
              if (_isSwitchingChannel) return;
              _isSwitchingChannel = true;

              try {
                if (_queue == null || index < 0 || index >= _queue!.length) {
                  return;
                }

                final item = _queue![index];
                contentItem = item;

                PlayerState.currentContent = contentItem;
                PlayerState.currentIndex = index;
                PlayerState.title = item.name;
                _currentItemIndex = index;

                _errorHandler.reset();

                _overlayKey.currentState?.resetContentState(newUrl: item.url);
                await _player.open(Media(item.url));
                await _applyUserPreferenceProperties();
                if (await UserPreferences.getLowLatencyMode()) {
                  await _applyLowLatencyProperties();
                }
                if (mounted) setState(() => isLoading = false);
                EventBus().emit('player_content_item', item);
                EventBus().emit('player_content_item_index', index);
                _errorHandler.reset();

                if (mounted) setState(() {});
              } finally {
                _isSwitchingChannel = false;
              }
            } else {
              if (_queue == null || index >= _queue!.length) return;
              if (_isSwitchingChannel) return;
              _isSwitchingChannel = true;
              try {
                final item = _queue![index];
                contentItem = item;
                _currentItemIndex = index;
                PlayerState.currentContent = item;
                PlayerState.currentIndex = index;
                PlayerState.title = item.name;
                // Look up resume position from watch history and open directly.
                final itemHistory = await watchHistoryService.getWatchHistory(
                  AppState.currentPlaylist!.id,
                  isXtreamCode ? item.id : item.m3uItem?.id ?? item.id,
                );
                final startMs = itemHistory?.watchDuration?.inMilliseconds ?? 0;
                _overlayKey.currentState?.resetContentState(newUrl: item.url);
                await _player.open(
                  Media(item.url, start: Duration(milliseconds: startMs)),
                  play: true,
                );
                await _applyUserPreferenceProperties();
                if (await UserPreferences.getLowLatencyMode()) {
                  await _applyLowLatencyProperties();
                }
                if (mounted) setState(() => isLoading = false);
                EventBus().emit('player_content_item', item);
                EventBus().emit('player_content_item_index', index);
                _errorHandler.reset();
                if (mounted) setState(() {});
              } finally {
                _isSwitchingChannel = false;
              }
            }
          });

      EventBus().on<List<ContentItem>>('player_queue_changed').listen((
        newQueue,
      ) {
        if (!mounted) return;
        _queue = newQueue;
        PlayerState.queue = newQueue;
        _currentItemIndex = 0; // will be corrected by index-changed event
      });

      // Kanal listesi göster/gizle event'i
      EventBus().on<bool>('toggle_channel_list').listen((bool show) {
        if (mounted) {
          setState(() {
            _showChannelList = show;
            PlayerState.showChannelList = show;
          });
        }
      });

      // Video bilgisi göster/gizle event'i
      EventBus().on<bool>('toggle_video_info').listen((bool show) {
        if (mounted) {
          setState(() {
            PlayerState.showVideoInfo = show;
          });
        }
      });

      // Video ayarları göster/gizle event'i
      EventBus().on<bool>('toggle_video_settings').listen((bool show) {
        if (mounted) {
          setState(() {
            PlayerState.showVideoSettings = show;
          });
        }
      });

      if (mounted) {
        setState(() {
          // isLoading is now handled inside each open() call
        });
      }
    } catch (e, st) {
      debugPrint('_initializePlayer error: $e\n$st');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Failed to initialize player: $e';
        });
      }
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        await _player.dispose();
        break;
      default:
        break;
    }
  }

  void _changeChannel(int direction) {
    if (_queue == null || _queue!.length <= 1) return;

    final newIndex = _currentItemIndex + direction;
    if (newIndex < 0 || newIndex >= _queue!.length) return;

    EventBus().emit('player_content_item_index_changed', newIndex);
  }

  Widget _buildChannelListOverlay(BuildContext context) {
    // For series, use the dedicated episode panel
    if (contentItem.contentType == ContentType.series) {
      return _buildSeriesEpisodePanel(context);
    }
    final items = _queue!;
    final isMobilePhone = MediaQuery.sizeOf(context).shortestSide < 600;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = isMobilePhone
        ? (screenWidth * 0.55).clamp(200.0, 240.0)
        : (screenWidth / 3).clamp(200.0, 400.0);

    // Mevcut index'i bul
    final int selectedIndex = _currentItemIndex;

    String overlayTitle = 'Kanal Seç';
    if (contentItem.contentType == ContentType.vod) {
      overlayTitle = 'Filmler';
    } else if (contentItem.contentType == ContentType.series) {
      overlayTitle = 'Bölümler';
    }

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showChannelList = false;
          });
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {}, // Panel içine tıklanınca kapanmasın
              child: Container(
                width: panelWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[800]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              overlayTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '${selectedIndex + 1} / ${items.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _showChannelList = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Channel list
                    Expanded(
                      child: ListView.builder(
                        cacheExtent: 500,
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = index == selectedIndex;

                          return _buildChannelListItem(
                            context,
                            item,
                            index,
                            isSelected,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelListItem(
    BuildContext context,
    ContentItem item,
    int index,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        EventBus().emit('player_content_item_index_changed', index);
        // Panel kapanmasın, sadece kanal değişsin
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Row(
          children: [
            // Thumbnail
            if (item.imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  item.imagePath,
                  width: 50,
                  height: 35,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 35,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: 20,
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 50,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.video_library,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            const SizedBox(width: 10),
            // Title and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getContentTypeIcon(item.contentType),
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _getContentTypeDisplayNameForItem(item.contentType),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesEpisodePanel(BuildContext context) {
    final items = _queue ?? [];
    // Group by season
    final Map<int, List<ContentItem>> bySeason = {};
    for (final ep in items) {
      final s = ep.season ?? 1;
      bySeason.putIfAbsent(s, () => []).add(ep);
    }
    final seasons = bySeason.keys.toList()..sort();
    // Find current episode's season for initial tab
    final currentSeason = contentItem.season ?? seasons.first;
    int initialTab = seasons
        .indexOf(currentSeason)
        .clamp(0, seasons.length - 1);
    final isMobilePhone = MediaQuery.sizeOf(context).shortestSide < 600;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = isMobilePhone
        ? (screenWidth * 0.55).clamp(200.0, 240.0)
        : (screenWidth / 3).clamp(200.0, 380.0);
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showChannelList = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {}, // prevent dismiss on panel tap
              child: SizedBox(
                width: panelWidth,
                height: double.infinity,
                child: DefaultTabController(
                  length: seasons.length,
                  initialIndex: initialTab,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.95),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tv_rounded,
                                size: 16,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Episodes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    setState(() => _showChannelList = false),
                              ),
                            ],
                          ),
                        ),
                        // Season tabs
                        if (seasons.length > 1)
                          Container(
                            color: Colors.grey,
                            child: TabBar(
                              isScrollable: true,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.white54,
                              indicatorColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              tabs: seasons
                                  .map((s) => Tab(text: 'S$s'))
                                  .toList(),
                            ),
                          ),
                        // Episode list per season tab
                        Expanded(
                          child: TabBarView(
                            children: seasons.map((season) {
                              final eps = bySeason[season]!;
                              return ListView.builder(
                                cacheExtent: 500,
                                padding: const EdgeInsets.all(8),
                                itemCount: eps.length,
                                itemBuilder: (context, idx) {
                                  final ep = eps[idx];
                                  // Find the TRUE index in the full queue
                                  final queueIndex = items.indexWhere(
                                    (q) => q.id == ep.id,
                                  );
                                  final isSelected = ep.id == contentItem.id;
                                  return InkWell(
                                    onTap: () {
                                      if (queueIndex != -1) {
                                        EventBus().emit(
                                          'player_content_item_index_changed',
                                          queueIndex,
                                        );
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.25)
                                            : Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                width: 1.5,
                                              )
                                            : Border.all(
                                                color: Colors.grey,
                                                width: 1,
                                              ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (ep.imagePath.isNotEmpty)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Image.network(
                                                ep.imagePath,
                                                width: 60,
                                                height: 36,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      width: 60,
                                                      height: 36,
                                                      color: Colors.grey,
                                                      child: const Icon(
                                                        Icons.tv,
                                                        size: 18,
                                                        color: Colors.white38,
                                                      ),
                                                    ),
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 60,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: Colors.grey,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.tv,
                                                size: 18,
                                                color: Colors.white38,
                                              ),
                                            ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              ep.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.white70,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getContentTypeIcon(ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return Icons.live_tv;
      case ContentType.vod:
        return Icons.movie;
      case ContentType.series:
        return Icons.tv;
    }
  }

  String _getContentTypeDisplayNameForItem(ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return 'Canlı Yayın';
      case ContentType.vod:
        return 'Film';
      case ContentType.series:
        return 'Dizi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isLandscape = screenSize.width > screenSize.height;

    // Series ve LiveStream için tam ekran modu
    final isSeries = widget.contentItem.contentType == ContentType.series;
    final isLiveStream =
        widget.contentItem.contentType == ContentType.liveStream;
    final isVod = widget.contentItem.contentType == ContentType.vod;
    final isFullScreen = isSeries || isLiveStream || isVod;

    double calculateAspectRatio() {
      if (widget.aspectRatio != null) return widget.aspectRatio!;

      if (isTablet) {
        return isLandscape ? 21 / 9 : 16 / 9;
      }
      return 16 / 9;
    }

    double? calculateMaxHeight() {
      if (isTablet) {
        if (isLandscape) {
          return screenSize.height * 0.6;
        } else {
          return screenSize.height * 0.4;
        }
      }
      return null;
    }

    Widget playerWidget;

    if (isFullScreen) {
      // Series ve LiveStream için tam ekran
      playerWidget = SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            if (_videoController != null) _buildPlayerContent(),
            if (isLoading || _videoController == null)
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      );
    } else {
      // Diğer içerikler için aspect ratio kullan
      playerWidget = AspectRatio(
        aspectRatio: calculateAspectRatio(),
        child: Stack(
          children: [
            if (_videoController != null) _buildPlayerContent(),
            if (isLoading || _videoController == null)
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      );

      if (isTablet) {
        final maxHeight = calculateMaxHeight();
        if (maxHeight != null) {
          playerWidget = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: playerWidget,
          );
        }
      }
    }

    return Container(
      color: Colors.black,
      child: isFullScreen ? playerWidget : Column(children: [playerWidget]),
    );
  }

  Widget _buildPlayerContent() {
    if (_videoController == null) return const SizedBox.shrink();
    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    final isLiveStream =
        widget.contentItem.contentType == ContentType.liveStream;
    final isDesktop = ResponsiveHelper.isDesktopOrTV(context);
    final usePersistentSidebar =
        widget.showPersistentSidebar && isLiveStream && isDesktop;

    final Widget videoStack = Stack(
      children: [
        getVideo(
          context,
          _videoController!,
          PlayerState.subtitleConfiguration,
          onFullscreenOverride: widget.onFullscreen,
          isInline: widget.isInline,
          contentType: widget.contentItem.contentType,
          overlayKey: _overlayKey,
        ),
        if (!usePersistentSidebar &&
            _showChannelList &&
            _queue != null &&
            _queue!.length > 1)
          RepaintBoundary(child: _buildChannelListOverlay(context)),
      ],
    );

    final Widget playerCore = GestureDetector(
      onVerticalDragEnd: (details) {
        if (_queue == null || _queue!.length <= 1) return;
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -500) {
          _changeChannel(1);
        } else if (details.primaryVelocity != null &&
            details.primaryVelocity! > 500) {
          _changeChannel(-1);
        }
      },
      child: videoStack,
    );

    if (usePersistentSidebar && _queue != null && _queue!.length > 1) {
      return ValueListenableBuilder<bool>(
        valueListenable: fullscreenNotifier,
        builder: (context, isFullscreen, _) {
          if (isFullscreen) return playerCore;
          return Row(
            children: [
              Expanded(child: playerCore),
              Container(width: 1, color: Colors.grey.shade900),
              RepaintBoundary(
                child: SizedBox(
                  width: 300,
                  child: _buildPersistentChannelList(),
                ),
              ),
            ],
          );
        },
      );
    }

    return playerCore;
  }

  Widget _buildPersistentChannelList() {
    final items = _queue!;
    final theme = Theme.of(context);

    final int selectedIndex = _currentItemIndex;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.live_tv_rounded,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Channels  ${selectedIndex + 1}/${items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              cacheExtent: 500,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return InkWell(
                  onTap: () => EventBus().emit(
                    'player_content_item_index_changed',
                    index,
                  ),
                  child: Container(
                    height: 56,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item.imagePath.isNotEmpty
                                ? Image.network(
                                    item.imagePath,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.live_tv,
                                      size: 18,
                                      color: Colors.white24,
                                    ),
                                  )
                                : const Icon(
                                    Icons.live_tv,
                                    size: 18,
                                    color: Colors.white24,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.play_arrow_rounded,
                              color: theme.colorScheme.primary,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
