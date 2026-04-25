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

// ─────────────────────────────────────────────────
// UI state — drives only the overlay, never the video
// ─────────────────────────────────────────────────
class _UiState {
  final bool osdVisible;
  final bool panelOpen;
  final int  panelTab;
  final bool isBuffering;
  final bool isLive;
  final String title;
  final int channelIndex;
  final int channelTotal;
  final Duration position;
  final Duration duration;

  const _UiState({
    this.osdVisible   = false,
    this.panelOpen    = false,
    this.panelTab     = 0,
    this.isBuffering  = true,
    this.isLive       = false,
    this.title        = '',
    this.channelIndex = 0,
    this.channelTotal = 1,
    this.position     = Duration.zero,
    this.duration     = Duration.zero,
  });

  _UiState copyWith({
    bool?     osdVisible,
    bool?     panelOpen,
    int?      panelTab,
    bool?     isBuffering,
    bool?     isLive,
    String?   title,
    int?      channelIndex,
    int?      channelTotal,
    Duration? position,
    Duration? duration,
  }) => _UiState(
    osdVisible   : osdVisible   ?? this.osdVisible,
    panelOpen    : panelOpen    ?? this.panelOpen,
    panelTab     : panelTab     ?? this.panelTab,
    isBuffering  : isBuffering  ?? this.isBuffering,
    isLive       : isLive       ?? this.isLive,
    title        : title        ?? this.title,
    channelIndex : channelIndex ?? this.channelIndex,
    channelTotal : channelTotal ?? this.channelTotal,
    position     : position     ?? this.position,
    duration     : duration     ?? this.duration,
  );
}

// ─────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────
class TvPlayerScreen extends StatefulWidget {
  final ContentItem       contentItem;
  final List<ContentItem> queue;
  final int               initialIndex;

  const TvPlayerScreen({
    super.key,
    required this.contentItem,
    required this.queue,
    required this.initialIndex,
  });

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  // ── media_kit ─────────────────────────────────
  late final Player          _player;
  late final VideoController _vc;

  // ── state ────────────────────────────────────
  late int         _idx;
  late ContentItem _item;

  // track lists — live in setState because they only change on media open
  List<AudioTrack>    _audio    = [];
  List<SubtitleTrack> _subtitle = [];
  List<VideoTrack>    _video    = [];
  AudioTrack?         _curAudio;
  SubtitleTrack?      _curSub;
  VideoTrack?         _curVideo;

  // ── OSD stream ───────────────────────────────
  final _uiCtrl = StreamController<_UiState>.broadcast();
  _UiState _ui  = const _UiState();
  void _push(_UiState next) {
    _ui = next;
    if (!_uiCtrl.isClosed) _uiCtrl.add(next);
  }

  // ── timers ────────────────────────────────────
  Timer? _osdTimer;
  Timer? _historyTimer;
  Duration _lastSaved = Duration.zero;

  // ── focus ─────────────────────────────────────
  final _focus = FocusNode();

  // ── subscriptions ─────────────────────────────
  final _subs = <StreamSubscription>[];

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _idx  = widget.initialIndex;
    _item = widget.contentItem;

    // 1. Create player — DO NOT set vo/gpu-api; media_kit owns the surface
    _player = Player(
      configuration: PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
        bufferSize: 32 * 1024 * 1024,
      ),
    );

    // 2. Create VideoController synchronously before any async work
    _vc = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    // 3. Wire up lightweight stream listeners (no setState — push to stream)
    _wireLightweightListeners();

    // 4. Wire up track listeners (need setState — happens only on media change)
    _wireTrackListeners();

    // 5. Show system UI is already hidden on TV; just request focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });

    // 6. Apply MPV properties and open media — fully async, errors caught
    _startPlayback();
  }

  // ── Wire listeners that only push to the UI stream (never setState) ────────
  void _wireLightweightListeners() {
    bool lastBuffering = true;

    _subs.add(_player.stream.buffering.listen((v) {
      if (v != lastBuffering) {
        lastBuffering = v;
        _push(_ui.copyWith(isBuffering: v));
      }
    }));

    Timer? posDebounce;
    _subs.add(_player.stream.position.listen((pos) {
      final dur = _player.state.duration;
      // watch history — save every 5 s of play movement
      if ((pos - _lastSaved).abs() > const Duration(seconds: 5)) {
        _historyTimer?.cancel();
        _historyTimer = Timer(const Duration(seconds: 5), () {
          _lastSaved = pos;
          _saveHistory(pos, dur);
        });
      }
      if (_ui.osdVisible) {
        posDebounce?.cancel();
        posDebounce = Timer(const Duration(milliseconds: 250), () {
          _push(_ui.copyWith(position: pos, duration: dur));
        });
      }
    }));
  }

  // ── Wire track listeners (these need setState because track lists update) ──
  void _wireTrackListeners() {
    _subs.add(_player.stream.tracks.listen((t) {
      if (!mounted) return;
      setState(() {
        _audio    = t.audio;
        _subtitle = t.subtitle;
        _video    = t.video;
      });
    }));
    _subs.add(_player.stream.track.listen((t) {
      if (!mounted) return;
      setState(() {
        _curAudio = t.audio;
        _curSub   = t.subtitle;
        _curVideo = t.video;
      });
    }));
  }

  // ── Apply safe MPV properties (no vo/gpu-api!) ────────────────────────────
  Future<void> _applyMpv() async {
    final p = _player.platform;
    if (p is! NativePlayer) return;
    try {
      // hardware decode zero-copy
      await p.setProperty('hwdec',       'mediacodec-copy');
      await p.setProperty('hwdec-codecs','all');

      // disable all CPU-side video filters
      await p.setProperty('interpolation',       'no');
      await p.setProperty('scale',               'bilinear');
      await p.setProperty('cscale',              'bilinear');
      await p.setProperty('dscale',              'bilinear');
      await p.setProperty('scale-antiring',      '0.0');
      await p.setProperty('sigmoid-upscaling',   'no');
      await p.setProperty('linear-upscaling',    'no');
      await p.setProperty('correct-downscaling', 'no');
      await p.setProperty('deinterlace',         'no');
      await p.setProperty('dither',              'no');
      // no tone-mapping — TV panel handles HDR natively
      await p.setProperty('tone-mapping',        'clip');
      await p.setProperty('hdr-compute-peak',    'no');

      if (_item.contentType == ContentType.liveStream) {
        await p.setProperty('video-sync',              'audio');
        await p.setProperty('framedrop',               'decoder+vo');
        await p.setProperty('cache',                   'yes');
        await p.setProperty('demuxer-max-bytes',       '8MiB');
        await p.setProperty('demuxer-max-back-bytes',  '2MiB');
        await p.setProperty('demuxer-readahead-secs',  '0.3');
        await p.setProperty('cache-secs',              '1');
        await p.setProperty('demuxer-cache-wait',      'no');
        await p.setProperty('initial-audio-sync',      'no');
        await p.setProperty('vd-lavc-skiploopfilter',  'nonref');
      } else {
        await p.setProperty('video-sync',              'audio');
        await p.setProperty('framedrop',               'decoder');
        await p.setProperty('cache',                   'yes');
        await p.setProperty('demuxer-max-bytes',       '32MiB');
        await p.setProperty('demuxer-max-back-bytes',  '8MiB');
        await p.setProperty('demuxer-readahead-secs',  '0');
        await p.setProperty('cache-secs',              '10');
        await p.setProperty('demuxer-cache-wait',      'no');
        await p.setProperty('initial-audio-sync',      'yes');
        await p.setProperty('audio-buffer',            '0.2');
        // after first frame, allow background readahead
        Future.delayed(const Duration(seconds: 4), () async {
          try { await p.setProperty('demuxer-readahead-secs', '5.0'); }
          catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('[TV] MPV error: $e');
    }
  }

  // ── Full async init (called from initState, errors caught) ────────────────
  Future<void> _startPlayback() async {
    try {
      await _applyMpv();

      Duration startPos = Duration.zero;
      if (_item.contentType != ContentType.liveStream) {
        try {
          final svc = WatchHistoryService();
          final h = await svc.getWatchHistory(
            AppState.currentPlaylist!.id,
            isXtreamCode ? _item.id : (_item.m3uItem?.id ?? _item.id),
          );
          startPos = h?.watchDuration ?? Duration.zero;
        } catch (_) {}
      }

      await _player.open(
        Media(_item.url, start: startPos),
        play: true,
      );

      _push(_ui.copyWith(
        title        : _item.name,
        channelIndex : _idx,
        channelTotal : widget.queue.length,
        isLive       : _item.contentType == ContentType.liveStream,
        isBuffering  : false,
      ));
    } catch (e) {
      debugPrint('[TV] Playback start error: $e');
      if (mounted) {
        _push(_ui.copyWith(isBuffering: false));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play: $e'),
                   backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Channel switch ─────────────────────────────────────────────────────────
  Future<void> _switchTo(int targetIdx) async {
    final i = targetIdx.clamp(0, widget.queue.length - 1);
    if (i == _idx) return;
    _idx  = i;
    _item = widget.queue[i];
    _push(_ui.copyWith(
      title        : _item.name,
      channelIndex : i,
      isBuffering  : true,
    ));
    try {
      await _player.open(Media(_item.url), play: true);
    } catch (e) {
      debugPrint('[TV] Channel switch error: $e');
    }
  }

  // ── Watch history save ─────────────────────────────────────────────────────
  Future<void> _saveHistory(Duration pos, Duration dur) async {
    if (!mounted) return;
    try {
      await WatchHistoryService().saveWatchHistory(WatchHistory(
        playlistId  : AppState.currentPlaylist!.id,
        contentType : _item.contentType,
        streamId    : isXtreamCode ? _item.id : (_item.m3uItem?.id ?? _item.id),
        lastWatched : DateTime.now(),
        title       : _item.name,
        imagePath   : _item.imagePath,
        totalDuration : dur,
        watchDuration : pos,
        seriesId    : _item.seriesStream?.seriesId,
      ));
    } catch (e) {
      debugPrint('[TV] History save error: $e');
    }
  }

  // ── OSD ───────────────────────────────────────────────────────────────────
  void _showOsd() {
    _osdTimer?.cancel();
    _push(_ui.copyWith(osdVisible: true));
    _osdTimer = Timer(const Duration(seconds: 5), () {
      _push(_ui.copyWith(osdVisible: false));
    });
  }

  // ── Key handler ───────────────────────────────────────────────────────────
  void _onKey(KeyEvent ev) {
    if (ev is! KeyDownEvent) return;
    _showOsd();
    final k = ev.logicalKey;

    // MENU / hamburger → toggle panel
    if (k == LogicalKeyboardKey.contextMenu ||
        k == LogicalKeyboardKey.f1 ||
        ev.logicalKey.keyId == 0x00100000052) {
      _push(_ui.copyWith(panelOpen: !_ui.panelOpen, osdVisible: true));
      _osdTimer?.cancel();
      return;
    }

    // BACK while panel open → close panel
    if (_ui.panelOpen &&
        (k == LogicalKeyboardKey.escape  ||
         k == LogicalKeyboardKey.goBack  ||
         k == LogicalKeyboardKey.browserBack)) {
      _push(_ui.copyWith(panelOpen: false));
      return;
    }

    // BACK → pop
    if (k == LogicalKeyboardKey.escape  ||
        k == LogicalKeyboardKey.goBack  ||
        k == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).maybePop();
      return;
    }

    // Live: UP/DOWN = channel change
    if (_item.contentType == ContentType.liveStream) {
      if (k == LogicalKeyboardKey.arrowUp   || k == LogicalKeyboardKey.channelUp)   { _switchTo(_idx - 1); return; }
      if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown) { _switchTo(_idx + 1); return; }
    }

    // VOD: LEFT/RIGHT = seek ±10s
    if (_item.contentType != ContentType.liveStream) {
      if (k == LogicalKeyboardKey.arrowRight) {
        _player.seek(_player.state.position + const Duration(seconds: 10));
        return;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        final t = _player.state.position - const Duration(seconds: 10);
        _player.seek(t < Duration.zero ? Duration.zero : t);
        return;
      }
    }

    // OK/ENTER/A = play-pause
    if (k == LogicalKeyboardKey.select       ||
        k == LogicalKeyboardKey.enter        ||
        k == LogicalKeyboardKey.gameButtonA  ||
        k == LogicalKeyboardKey.mediaPlayPause) {
      _player.playOrPause();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _osdTimer?.cancel();
    _historyTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _uiCtrl.close();
    _focus.dispose();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_ui.panelOpen) {
          _push(_ui.copyWith(panelOpen: false));
          return;
        }
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: KeyboardListener(
          autofocus: true,
          focusNode: _focus,
          onKeyEvent: _onKey,
          // RepaintBoundary isolates video paint from overlay paint
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── VIDEO — never rebuilds after first frame ──
                Video(
                  controller: _vc,
                  controls: NoVideoControls,
                  fill: Colors.black,
                ),

                // ── OVERLAY — only the StreamBuilder subtree rebuilds ──
                StreamBuilder<_UiState>(
                  initialData: _ui,
                  stream: _uiCtrl.stream,
                  builder: (_, snap) {
                    final ui = snap.data ?? _ui;
                    return _Overlay(
                      ui      : ui,
                      item    : _item,
                      queue   : widget.queue,
                      curIdx  : _idx,
                      audio   : _audio,
                      subtitle: _subtitle,
                      video   : _video,
                      curAudio: _curAudio,
                      curSub  : _curSub,
                      curVideo: _curVideo,
                      fmt     : _fmt,
                      onOsd   : _showOsd,
                      onPanelToggle : () => _push(_ui.copyWith(panelOpen: !_ui.panelOpen)),
                      onPanelClose  : () => _push(_ui.copyWith(panelOpen: false)),
                      onPanelTab    : (t) => _push(_ui.copyWith(panelTab: t)),
                      onSubCycle    : _cycleSubtitle,
                      onChannelTap  : (i) {
                        _switchTo(i);
                        _push(_ui.copyWith(panelOpen: false));
                      },
                      onTrackAudio  : (t) => _player.setAudioTrack(t),
                      onTrackSub    : (t) => _player.setSubtitleTrack(t),
                      onTrackVideo  : (t) => _player.setVideoTrack(t),
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

  void _cycleSubtitle() {
    final tracks = <SubtitleTrack>[SubtitleTrack.no(),
      ..._subtitle.where((t) => t.id != 'no')];
    final ci = tracks.indexWhere((t) => t.id == (_curSub?.id ?? 'no'));
    _player.setSubtitleTrack(tracks[(ci + 1) % tracks.length]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY — pure StatelessWidget, receives all data via constructor.
// This is separated so the Video widget is NEVER in the same build scope.
// ─────────────────────────────────────────────────────────────────────────────
class _Overlay extends StatelessWidget {
  final _UiState          ui;
  final ContentItem       item;
  final List<ContentItem> queue;
  final int               curIdx;
  final List<AudioTrack>    audio;
  final List<SubtitleTrack> subtitle;
  final List<VideoTrack>    video;
  final AudioTrack?         curAudio;
  final SubtitleTrack?      curSub;
  final VideoTrack?         curVideo;
  final String Function(Duration) fmt;
  final VoidCallback  onOsd;
  final VoidCallback  onPanelToggle;
  final VoidCallback  onPanelClose;
  final void Function(int)           onPanelTab;
  final VoidCallback  onSubCycle;
  final void Function(int)           onChannelTap;
  final void Function(AudioTrack)    onTrackAudio;
  final void Function(SubtitleTrack) onTrackSub;
  final void Function(VideoTrack)    onTrackVideo;

  const _Overlay({
    required this.ui,
    required this.item,
    required this.queue,
    required this.curIdx,
    required this.audio,
    required this.subtitle,
    required this.video,
    required this.curAudio,
    required this.curSub,
    required this.curVideo,
    required this.fmt,
    required this.onOsd,
    required this.onPanelToggle,
    required this.onPanelClose,
    required this.onPanelTab,
    required this.onSubCycle,
    required this.onChannelTap,
    required this.onTrackAudio,
    required this.onTrackSub,
    required this.onTrackVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Buffering spinner
        if (ui.isBuffering)
          const Center(
            child: SizedBox(
              width: 56, height: 56,
              child: CircularProgressIndicator(
                color: Colors.white70, strokeWidth: 3),
            ),
          ),

        // OSD bottom bar
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          bottom: ui.osdVisible ? 0 : -140,
          left: 0, right: 0,
          child: _buildOsd(context),
        ),

        // Side panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          top: 0, bottom: 0,
          right: ui.panelOpen ? 0 : -400,
          width: 400,
          child: _buildPanel(context),
        ),
      ],
    );
  }

  // ── OSD ───────────────────────────────────────────────────────────────────
  Widget _buildOsd(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(36, 18, 36, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xDD000000), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
          Row(children: [
            Expanded(
              child: Text(ui.title,
                style: const TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),

            // Subtitle toggle
            IconButton(
              icon: Icon(
                (curSub != null && curSub!.id != 'no')
                    ? Icons.subtitles_rounded
                    : Icons.subtitles_off_outlined,
                color: Colors.white70, size: 22),
              onPressed: onSubCycle,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),

            // Hamburger
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white70, size: 22),
              onPressed: onPanelToggle,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 12),

            if (ui.isLive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LIVE',
                  style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              if (ui.channelTotal > 1) ...[
                const SizedBox(width: 10),
                Text('${ui.channelIndex + 1} / ${ui.channelTotal}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ] else
              Text('${fmt(ui.position)}  /  ${fmt(ui.duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ]),

          // Progress bar (VOD only)
          if (!ui.isLive && ui.duration.inSeconds > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ui.position.inMilliseconds /
                       ui.duration.inMilliseconds.clamp(1, double.infinity),
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
                minHeight: 4,
              ),
            ),
          ],

          // Hints
          const SizedBox(height: 8),
          Row(children: [
            const _Hint(icon: Icons.arrow_back, label: 'Back'),
            const SizedBox(width: 18),
            if (ui.isLive)
              const _Hint(icon: Icons.swap_vert, label: '↑↓ Channel')
            else ...[
              const _Hint(icon: Icons.fast_rewind, label: '←  -10s'),
              const SizedBox(width: 12),
              const _Hint(icon: Icons.fast_forward, label: '→  +10s'),
              const SizedBox(width: 12),
              const _Hint(icon: Icons.check_circle_outline, label: 'OK Play/Pause'),
            ],
            const SizedBox(width: 18),
            const _Hint(icon: Icons.menu, label: 'MENU Options'),
          ]),
        ],
      ),
    );
  }

  // ── Side panel ────────────────────────────────────────────────────────────
  Widget _buildPanel(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF2101020),
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
            child: Row(children: [
              Expanded(
                child: Text(item.name,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: onPanelClose),
            ]),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _Tab(label: 'Tracks',   i: 0, cur: ui.panelTab, onTap: onPanelTab),
              _Tab(label: 'Info',     i: 1, cur: ui.panelTab, onTap: onPanelTab),
              if (item.contentType == ContentType.liveStream)
                _Tab(label: 'Channels', i: 2, cur: ui.panelTab, onTap: onPanelTab),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),

          Expanded(child: switch (ui.panelTab) {
            0 => _tracksTab(context),
            1 => _infoTab(),
            2 => _channelsTab(context),
            _ => const SizedBox.shrink(),
          }),
        ],
      ),
    );
  }

  Widget _tracksTab(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (audio.isNotEmpty) ...[
          const _SLabel('Audio'),
          ...audio.map((t) => _TTile(
            label    : t.language ?? t.title ?? 'Track ${t.id}',
            selected : curAudio?.id == t.id,
            primary  : primary,
            onTap    : () => onTrackAudio(t))),
          const SizedBox(height: 12),
        ],
        if (subtitle.isNotEmpty) ...[
          const _SLabel('Subtitles'),
          _TTile(label: 'Off',
            selected: curSub == null || curSub!.id == 'no',
            primary: primary,
            onTap: () => onTrackSub(SubtitleTrack.no())),
          ...subtitle.where((t) => t.id != 'no').map((t) => _TTile(
            label    : t.language ?? t.title ?? 'Track ${t.id}',
            selected : curSub?.id == t.id,
            primary  : primary,
            onTap    : () => onTrackSub(t))),
          const SizedBox(height: 12),
        ],
        if (video.length > 1) ...[
          const _SLabel('Video'),
          ...video.map((t) => _TTile(
            label    : t.title ?? 'Track ${t.id}',
            selected : curVideo?.id == t.id,
            primary  : primary,
            onTap    : () => onTrackVideo(t))),
        ],
      ],
    );
  }

  Widget _infoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imagePath.isNotEmpty)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(item.imagePath,
                  width: 160, height: 120, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          const SizedBox(height: 16),
          Text(item.name,
            style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          if (item.contentType == ContentType.liveStream) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: const Text('LIVE',
                style: TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
          if (item.m3uItem?.groupTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _IRow(label: 'Category', value: item.m3uItem!.groupTitle!),
          ],
        ],
      ),
    );
  }

  Widget _channelsTab(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      itemBuilder: (_, i) {
        final ch = queue[i];
        final sel = i == curIdx;
        return ListTile(
          dense: true,
          selected: sel,
          selectedTileColor: primary.withValues(alpha: 0.2),
          selectedColor: Colors.white,
          leading: ch.imagePath.isNotEmpty
              ? Image.network(ch.imagePath,
                  width: 32, height: 32, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.live_tv, size: 20, color: Colors.white38))
              : const Icon(Icons.live_tv, size: 20, color: Colors.white38),
          title: Text(ch.name,
            style: TextStyle(
              color: sel ? Colors.white : Colors.white60,
              fontSize: 13,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onChannelTap(i),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Hint extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Hint({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white38, size: 13),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
}

class _Tab extends StatelessWidget {
  final String label;
  final int i, cur;
  final void Function(int) onTap;
  const _Tab({required this.label, required this.i,
               required this.cur, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = i == cur;
    return GestureDetector(
      onTap: () => onTap(i),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary : Colors.white10,
          borderRadius: BorderRadius.circular(6)),
        child: Text(label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38, fontSize: 10,
        letterSpacing: 1.2, fontWeight: FontWeight.bold)));
}

class _TTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;
  const _TTile({required this.label, required this.selected,
                required this.primary, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    onTap: onTap,
    title: Text(label,
      style: TextStyle(
        color: selected ? Colors.white : Colors.white60, fontSize: 13)),
    trailing: selected
        ? Icon(Icons.check_circle_rounded, color: primary, size: 18)
        : null,
  );
}

class _IRow extends StatelessWidget {
  final String label, value;
  const _IRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80,
          child: Text('$label:',
            style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(child: Text(value,
          style: const TextStyle(color: Colors.white70, fontSize: 12))),
      ]));
}
