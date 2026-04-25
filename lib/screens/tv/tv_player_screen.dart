import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../models/watch_history.dart';
import '../../services/app_state.dart';
import '../../services/watch_history_service.dart';
import '../../utils/get_playlist_type.dart';

class TvPlayerScreen extends StatefulWidget {
  final ContentItem contentItem;
  final List<ContentItem> queue;
  final int initialIndex;

  const TvPlayerScreen({
    super.key,
    required this.contentItem,
    required this.queue,
    required this.initialIndex,
  });

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerUiState {
  final bool osdVisible;
  final String title;
  final int channelIndex;
  final int channelTotal;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final bool isLive;

  const _TvPlayerUiState({
    required this.osdVisible,
    required this.title,
    required this.channelIndex,
    required this.channelTotal,
    required this.position,
    required this.duration,
    required this.isBuffering,
    required this.isLive,
  });

  _TvPlayerUiState copyWith({
    bool? osdVisible,
    String? title,
    int? channelIndex,
    int? channelTotal,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    bool? isLive,
  }) {
    return _TvPlayerUiState(
      osdVisible: osdVisible ?? this.osdVisible,
      title: title ?? this.title,
      channelIndex: channelIndex ?? this.channelIndex,
      channelTotal: channelTotal ?? this.channelTotal,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      isLive: isLive ?? this.isLive,
    );
  }
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  late Player _player;
  VideoController? _videoController;
  late WatchHistoryService _watchHistoryService;

  late int _currentIndex;
  late ContentItem _currentItem;

  final FocusNode _keyFocus = FocusNode();
  Timer? _osdHideTimer;
  Timer? _watchHistoryTimer;
  Duration _lastSavedPosition = Duration.zero;

  // StreamController drives ONLY the OSD overlay — video surface never rebuilds
  final _uiStream = StreamController<_TvPlayerUiState>.broadcast();
  _TvPlayerUiState _uiState = const _TvPlayerUiState(
    osdVisible: false,
    title: '',
    channelIndex: 0,
    channelTotal: 1,
    position: Duration.zero,
    duration: Duration.zero,
    isBuffering: true,
    isLive: false,
  );

  void _pushUi(_TvPlayerUiState next) {
    _uiState = next;
    if (!_uiStream.isClosed) _uiStream.add(next);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentItem = widget.contentItem;
    _watchHistoryService = WatchHistoryService();

    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
        bufferSize: 32 * 1024 * 1024, // 32MB — lighter than desktop 64MB
      ),
    );

    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _initPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyFocus.requestFocus();
        // TV is always landscape — just hide system UI
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  @override
  void dispose() {
    _osdHideTimer?.cancel();
    _watchHistoryTimer?.cancel();
    _uiStream.close();
    _keyFocus.dispose();
    _player.dispose();
    // Restore system UI when leaving player
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _applyMpvProperties() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    try {
      // Android TV MPV properties — optimized for weak hardware
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

      if (_currentItem.contentType == ContentType.liveStream) {
        await native.setProperty('video-sync', 'audio');
        await native.setProperty('framedrop', 'decoder+vo');
        await native.setProperty('cache', 'yes');
        await native.setProperty('demuxer-max-bytes', '16MiB'); // TV: half of phone
        await native.setProperty('demuxer-max-back-bytes', '2MiB');
        await native.setProperty('demuxer-readahead-secs', '0.5');
        await native.setProperty('cache-secs', '2');
        await native.setProperty('demuxer-cache-wait', 'no');
        await native.setProperty('initial-audio-sync', 'no');
        // TV-specific: skip loop filter on live to reduce CPU load
        await native.setProperty('vd-lavc-skiploopfilter', 'nonref');
      } else {
        await native.setProperty('video-sync', 'audio'); // audio sync is lighter than display-resample on TV
        await native.setProperty('framedrop', 'decoder');
        await native.setProperty('cache', 'yes');
        await native.setProperty('demuxer-max-bytes', '32MiB');
        await native.setProperty('demuxer-max-back-bytes', '8MiB');
        await native.setProperty('demuxer-readahead-secs', '3.0');
        await native.setProperty('cache-secs', '15');
        await native.setProperty('demuxer-cache-wait', 'no');
        await native.setProperty('initial-audio-sync', 'yes');
        await native.setProperty('audio-buffer', '0.2');
      }
    } catch (e) {
      debugPrint('[TvPlayer] MPV properties error: $e');
    }
  }

  Future<void> _initPlayer() async {
    await _applyMpvProperties();

    // Subscribe to buffering — only push when value actually changes
    bool lastBuffering = true;
    _player.stream.buffering.listen((buffering) {
      if (buffering != lastBuffering) {
        lastBuffering = buffering;
        _pushUi(_uiState.copyWith(isBuffering: buffering));
      }
    });

    // Subscribe to position — only update OSD if it's visible, batched
    Timer? posDebounce;
    _player.stream.position.listen((pos) {
      final dur = _player.state.duration;
      // Watch history save (only every 5s of movement)
      if ((pos - _lastSavedPosition).abs() > const Duration(seconds: 5)) {
        _watchHistoryTimer?.cancel();
        _watchHistoryTimer = Timer(const Duration(seconds: 5), () {
          _lastSavedPosition = pos;
          _saveWatchHistory(pos, dur);
        });
      }
      // OSD position update — only if OSD is currently visible
      if (_uiState.osdVisible) {
        posDebounce?.cancel();
        posDebounce = Timer(const Duration(milliseconds: 300), () {
          _pushUi(_uiState.copyWith(position: pos, duration: dur));
        });
      }
    });

    // Open media
    final watchHistory = await _watchHistoryService.getWatchHistory(
      AppState.currentPlaylist!.id,
      isXtreamCode
          ? _currentItem.id
          : _currentItem.m3uItem?.id ?? _currentItem.id,
    );

    await _player.open(
      Media(
        _currentItem.url,
        start: _currentItem.contentType != ContentType.liveStream
            ? (watchHistory?.watchDuration ?? Duration.zero)
            : Duration.zero,
      ),
      play: true,
    );

    _pushUi(_uiState.copyWith(
      title: _currentItem.name,
      channelIndex: _currentIndex,
      channelTotal: widget.queue.length,
      isLive: _currentItem.contentType == ContentType.liveStream,
      isBuffering: false,
    ));
  }

  Future<void> _switchChannel(int direction) async {
    final newIndex = (_currentIndex + direction)
        .clamp(0, widget.queue.length - 1);
    if (newIndex == _currentIndex) return;
    _currentIndex = newIndex;
    _currentItem = widget.queue[newIndex];
    _pushUi(_uiState.copyWith(
      title: _currentItem.name,
      channelIndex: newIndex,
      isBuffering: true,
    ));
    await _player.open(Media(_currentItem.url), play: true);
  }

  Future<void> _saveWatchHistory(Duration pos, Duration dur) async {
    if (!mounted) return;
    try {
      await _watchHistoryService.saveWatchHistory(
        WatchHistory(
          playlistId: AppState.currentPlaylist!.id,
          contentType: _currentItem.contentType,
          streamId: isXtreamCode
              ? _currentItem.id
              : _currentItem.m3uItem?.id ?? _currentItem.id,
          lastWatched: DateTime.now(),
          title: _currentItem.name,
          imagePath: _currentItem.imagePath,
          totalDuration: dur,
          watchDuration: pos,
          seriesId: _currentItem.seriesStream?.seriesId,
        ),
      );
    } catch (e) {
      debugPrint('[TvPlayer] Watch history save error: $e');
    }
  }

  void _showOsd() {
    _osdHideTimer?.cancel();
    _pushUi(_uiState.copyWith(osdVisible: true));
    _osdHideTimer = Timer(const Duration(seconds: 4), () {
      _pushUi(_uiState.copyWith(osdVisible: false));
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    _showOsd();

    final key = event.logicalKey;

    // Back / Escape — pop player
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).maybePop();
      return;
    }

    // Live TV: up/down = channel change
    if (_currentItem.contentType == ContentType.liveStream) {
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.channelUp) {
        _switchChannel(-1);
        return;
      }
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.channelDown) {
        _switchChannel(1);
        return;
      }
    }

    // VOD/Series: left/right = seek ±10s
    if (_currentItem.contentType != ContentType.liveStream) {
      if (key == LogicalKeyboardKey.arrowRight) {
        final target = _player.state.position + const Duration(seconds: 10);
        _player.seek(target);
        return;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        final target = _player.state.position - const Duration(seconds: 10);
        _player.seek(target < Duration.zero ? Duration.zero : target);
        return;
      }
    }

    // OK/Enter/Select = play-pause
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _player.playOrPause();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: KeyboardListener(
          autofocus: true,
          focusNode: _keyFocus,
          onKeyEvent: _handleKey,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── VIDEO SURFACE — never rebuilds ──
                if (_videoController != null)
                  Video(
                    controller: _videoController!,
                    controls: NoVideoControls,
                    fill: Colors.black,
                  ),

                // ── OSD — only this subtree rebuilds ──
                StreamBuilder<_TvPlayerUiState>(
                  initialData: _uiState,
                  stream: _uiStream.stream,
                  builder: (context, snap) {
                    final ui = snap.data ?? _uiState;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Buffering indicator
                        if (ui.isBuffering)
                          const Center(
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 3,
                              ),
                            ),
                          ),

                        // OSD bar
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          bottom: ui.osdVisible ? 0 : -120,
                          left: 0,
                          right: 0,
                          child: _buildOsd(ui),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOsd(_TvPlayerUiState ui) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Text(
                  ui.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ui.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                )
              else
                Text(
                  '${_formatDuration(ui.position)}  /  ${_formatDuration(ui.duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              if (ui.isLive && ui.channelTotal > 1) ...[
                const SizedBox(width: 12),
                Text(
                  '${ui.channelIndex + 1} / ${ui.channelTotal}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),

          // VOD progress bar — LinearProgressIndicator is cheaper than Slider
          if (!ui.isLive && ui.duration.inSeconds > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ui.position.inMilliseconds /
                    ui.duration.inMilliseconds.clamp(1, double.infinity),
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
          ],

          // Key hints
          const SizedBox(height: 10),
          DefaultTextStyle(
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                const Text('Back'),
                const SizedBox(width: 20),
                if (ui.isLive) ...[
                  const Icon(Icons.keyboard_arrow_up,
                      color: Colors.white38, size: 14),
                  const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Text('Change channel'),
                ] else ...[
                  const Icon(Icons.keyboard_arrow_left,
                      color: Colors.white38, size: 14),
                  const Icon(Icons.keyboard_arrow_right,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Text('Seek ±10s'),
                  const SizedBox(width: 20),
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Text('Play/Pause'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
