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
  final bool panelOpen;     // side panel visible
  final int  panelTab;      // 0=tracks, 1=info, 2=channels(live only)

  const _TvPlayerUiState({
    required this.osdVisible,
    required this.title,
    required this.channelIndex,
    required this.channelTotal,
    required this.position,
    required this.duration,
    required this.isBuffering,
    required this.isLive,
    this.panelOpen = false,
    this.panelTab = 0,
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
    bool? panelOpen,
    int? panelTab,
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
      panelOpen: panelOpen ?? this.panelOpen,
      panelTab: panelTab ?? this.panelTab,
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

  List<AudioTrack>    _audioTracks    = [];
  List<SubtitleTrack> _subtitleTracks = [];
  List<VideoTrack>    _videoTracks    = [];
  AudioTrack?         _currentAudio;
  SubtitleTrack?      _currentSubtitle;
  VideoTrack?         _currentVideo;

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
        // Use nv12 — the default — but pair it with mediacodec-copy zero-copy below
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
      // ── ZERO-COPY HARDWARE DECODE ──────────────────────────────────────────
      // mediacodec-copy passes the decoded buffer directly to the GL surface.
      // This eliminates the CPU YUV→RGB blit that kills 4K performance.
      await native.setProperty('hwdec', 'mediacodec-copy');
      await native.setProperty('hwdec-codecs', 'all');

      // ── DISABLE ALL SOFTWARE VIDEO PROCESSING ─────────────────────────────
      await native.setProperty('interpolation', 'no');
      await native.setProperty('scale', 'bilinear');
      await native.setProperty('cscale', 'bilinear');
      await native.setProperty('dscale', 'bilinear');
      await native.setProperty('scale-antiring', '0.0');
      await native.setProperty('sigmoid-upscaling', 'no');
      await native.setProperty('linear-upscaling', 'no');
      await native.setProperty('correct-downscaling', 'no');
      await native.setProperty('deinterlace', 'no');

      // ── GPU RENDERER — opengl-hq is default but heavy; force plain opengl ──
      await native.setProperty('vo', 'gpu');
      await native.setProperty('gpu-api', 'opengl');
      // Disable dither — expensive at 4K, visually invisible on most TVs
      await native.setProperty('dither', 'no');
      // No tone mapping — let the TV handle HDR natively via surface metadata
      await native.setProperty('tone-mapping', 'clip');
      await native.setProperty('hdr-compute-peak', 'no');

      if (_currentItem.contentType == ContentType.liveStream) {
        // ── LIVE: minimum latency, no readahead ────────────────────────────
        await native.setProperty('video-sync', 'audio');
        await native.setProperty('framedrop', 'decoder+vo');
        await native.setProperty('cache', 'yes');
        await native.setProperty('demuxer-max-bytes', '8MiB');
        await native.setProperty('demuxer-max-back-bytes', '2MiB');
        await native.setProperty('demuxer-readahead-secs', '0.3');
        await native.setProperty('cache-secs', '1');
        await native.setProperty('demuxer-cache-wait', 'no');
        await native.setProperty('initial-audio-sync', 'no');
        await native.setProperty('vd-lavc-skiploopfilter', 'nonref');
        // Skip B-frame decoding on very weak hardware live streams
        await native.setProperty('vd-lavc-skipframe', 'nonref');
      } else {
        // ── VOD / SERIES: balanced quality + seek performance ─────────────
        await native.setProperty('video-sync', 'audio');
        await native.setProperty('framedrop', 'decoder');
        await native.setProperty('cache', 'yes');
        await native.setProperty('demuxer-max-bytes', '32MiB');
        await native.setProperty('demuxer-max-back-bytes', '8MiB');
        // CRITICAL: was 3.0 — 0 means "don't pre-read before first frame"
        // This eliminates the 2-second freeze on 4K file open
        await native.setProperty('demuxer-readahead-secs', '0');
        await native.setProperty('cache-secs', '10');
        await native.setProperty('demuxer-cache-wait', 'no');
        await native.setProperty('initial-audio-sync', 'yes');
        await native.setProperty('audio-buffer', '0.2');
        // After first frame appears, MPV will build cache in background.
        // Set readahead to 5 AFTER open via a delayed call.
        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted) {
            try {
              await native.setProperty('demuxer-readahead-secs', '5.0');
            } catch (_) {}
          }
        });
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

    _player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      setState(() {
        _audioTracks    = tracks.audio;
        _subtitleTracks = tracks.subtitle;
        _videoTracks    = tracks.video;
      });
    });
    _player.stream.track.listen((track) {
      if (!mounted) return;
      setState(() {
        _currentAudio    = track.audio;
        _currentSubtitle = track.subtitle;
        _currentVideo    = track.video;
      });
    });

    _pushUi(_uiState.copyWith(
      title: _currentItem.name,
      channelIndex: _currentIndex,
      channelTotal: widget.queue.length,
      isLive: _currentItem.contentType == ContentType.liveStream,
      isBuffering: false,
    ));
  }

  Future<void> _switchChannel(int targetIndex) async {
    final newIndex = targetIndex.clamp(0, widget.queue.length - 1);
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

    // MENU key = toggle side panel
    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f1 ||
        // Android TV "Options" / "Menu" button keycode 82
        event.logicalKey.keyId == 0x00100000052) {
      _pushUi(_uiState.copyWith(
        panelOpen: !_uiState.panelOpen,
        osdVisible: true,
      ));
      _osdHideTimer?.cancel();
      if (!_uiState.panelOpen) {
        // Reset hide timer only when closing panel
        _osdHideTimer = Timer(const Duration(seconds: 4), () {
          _pushUi(_uiState.copyWith(osdVisible: false));
        });
      }
      return;
    }

    // Escape while panel is open → close panel first, don't pop
    if ((key == LogicalKeyboardKey.escape ||
         key == LogicalKeyboardKey.goBack ||
         key == LogicalKeyboardKey.browserBack) &&
        _uiState.panelOpen) {
      _pushUi(_uiState.copyWith(panelOpen: false));
      return;
    }

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
        _switchChannel(_currentIndex - 1);
        return;
      }
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.channelDown) {
        _switchChannel(_currentIndex + 1);
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

                        // Side panel
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          top: 0,
                          bottom: 0,
                          right: ui.panelOpen ? 0 : -380,
                          width: 380,
                          child: _buildSidePanel(ui),
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
              const SizedBox(width: 12),
              // Subtitle quick-toggle
              IconButton(
                icon: Icon(
                  _currentSubtitle != null && _currentSubtitle!.id != 'no'
                      ? Icons.subtitles_rounded
                      : Icons.subtitles_off_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
                onPressed: () {
                  // Cycle to next subtitle track
                  final tracks = [SubtitleTrack.no(), ..._subtitleTracks
                      .where((t) => t.id != 'no')];
                  final currentIdx = tracks.indexWhere(
                    (t) => t.id == (_currentSubtitle?.id ?? 'no'));
                  final nextIdx = (currentIdx + 1) % tracks.length;
                  _player.setSubtitleTrack(tracks[nextIdx]);
                },
                tooltip: 'Subtitles',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
              // Hamburger — opens side panel
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white70, size: 22),
                onPressed: () {
                  _pushUi(_uiState.copyWith(panelOpen: true, osdVisible: true));
                  _osdHideTimer?.cancel();
                },
                tooltip: 'More options',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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

  Widget _buildSidePanel(_TvPlayerUiState ui) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF0101020),
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(_currentItem.name,
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => _pushUi(_uiState.copyWith(panelOpen: false)),
                ),
              ],
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _PanelTab(label: 'Tracks', index: 0, current: ui.panelTab,
                  onTap: (t) => _pushUi(_uiState.copyWith(panelTab: t))),
                _PanelTab(label: 'Info', index: 1, current: ui.panelTab,
                  onTap: (t) => _pushUi(_uiState.copyWith(panelTab: t))),
                if (_currentItem.contentType == ContentType.liveStream)
                  _PanelTab(label: 'Channels', index: 2, current: ui.panelTab,
                    onTap: (t) => _pushUi(_uiState.copyWith(panelTab: t))),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Panel body
          Expanded(
            child: switch (ui.panelTab) {
              0 => _buildTracksTab(),
              1 => _buildInfoTab(),
              2 => _buildChannelsTab(),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTracksTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_audioTracks.isNotEmpty) ...[
          _SectionLabel('Audio'),
          ..._audioTracks.map((t) => _TrackTile(
            label: t.language ?? t.title ?? 'Track ${t.id}',
            selected: _currentAudio?.id == t.id,
            onTap: () => _player.setAudioTrack(t),
          )),
          const SizedBox(height: 12),
        ],
        if (_subtitleTracks.isNotEmpty) ...[
          _SectionLabel('Subtitles'),
          _TrackTile(
            label: 'Off',
            selected: _currentSubtitle == null || _currentSubtitle!.id == 'no',
            onTap: () => _player.setSubtitleTrack(SubtitleTrack.no()),
          ),
          ..._subtitleTracks
              .where((t) => t.id != 'no')
              .map((t) => _TrackTile(
                label: t.language ?? t.title ?? 'Track ${t.id}',
                selected: _currentSubtitle?.id == t.id,
                onTap: () => _player.setSubtitleTrack(t),
              )),
          const SizedBox(height: 12),
        ],
        if (_videoTracks.length > 1) ...[
          _SectionLabel('Video'),
          ..._videoTracks.map((t) => _TrackTile(
            label: t.title ?? 'Track ${t.id}',
            selected: _currentVideo?.id == t.id,
            onTap: () => _player.setVideoTrack(t),
          )),
        ],
      ],
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentItem.imagePath.isNotEmpty)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _currentItem.imagePath,
                  width: 160, height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(_currentItem.name,
            style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          if (_currentItem.contentType == ContentType.liveStream) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('LIVE',
                style: TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
          if (_currentItem.m3uItem?.groupTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _InfoRow(label: 'Category', value: _currentItem.m3uItem!.groupTitle!),
          ] else if (_currentItem.liveStream?.categoryId.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _InfoRow(label: 'Category ID', value: _currentItem.liveStream!.categoryId),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelsTab() {
    final channels = widget.queue;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (ctx, i) {
        final ch = channels[i];
        final isCurrent = i == _currentIndex;
        return ListTile(
          dense: true,
          selected: isCurrent,
          selectedColor: Colors.white,
          selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          leading: ch.imagePath.isNotEmpty
              ? Image.network(ch.imagePath, width: 32, height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.live_tv, size: 20, color: Colors.white38))
              : const Icon(Icons.live_tv, size: 20, color: Colors.white38),
          title: Text(ch.name,
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.white60,
              fontSize: 13, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            _switchChannel(i);
            _pushUi(_uiState.copyWith(panelOpen: false));
          },
        );
      },
    );
  }
}

class _PanelTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;
  const _PanelTab({
    required this.label, required this.index,
    required this.current, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary : Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38, fontSize: 10, letterSpacing: 1.2,
        fontWeight: FontWeight.bold)),
  );
}

class _TrackTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TrackTile({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label,
      style: TextStyle(
        color: selected ? Colors.white : Colors.white60,
        fontSize: 13)),
    trailing: selected
        ? Icon(Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary, size: 18)
        : null,
    onTap: onTap,
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80,
          child: Text('$label:',
            style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(
          child: Text(value,
            style: const TextStyle(color: Colors.white70, fontSize: 12))),
      ],
    ),
  );
}
