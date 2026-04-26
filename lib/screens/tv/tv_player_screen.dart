import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart'; 
import '../tv/tv_live_tv_screen.dart';
import '../tv/tv_series_screen.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../models/watch_history.dart';
import '../../services/app_state.dart';
import '../../services/watch_history_service.dart';
import '../../utils/get_playlist_type.dart';
import '../../widgets/player/tv_player_overlay.dart';

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
  // ── ExoPlayer (via video_player) ───────────────
  VideoPlayerController? _controller;

  int?    _resW;
  int?    _resH;
  double? _fps;
  String? _codec;
  int?    _bitrate;
  Timer?  _statsTimer;

  // ── state ────────────────────────────────────
  late int         _idx;
  late ContentItem _item;
  bool _isClosing = false;

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

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _idx  = widget.initialIndex;
    _item = widget.contentItem;

    // Show system UI is already hidden on TV; just request focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });

    _startPlayback();
  }

  // ── Full async init (called from initState, errors caught) ────────────────
  Future<void> _startPlayback({Duration startPos = Duration.zero}) async {
    // 1. Dispose old controller if any
    final old = _controller;
    if (old != null) {
      old.removeListener(_vpcListener);
      old.dispose();
      _controller = null;
    }

    // 2. Fetch history if needed
    Duration initialPos = startPos;
    if (initialPos == Duration.zero && _item.contentType != ContentType.liveStream) {
      try {
        final svc = WatchHistoryService();
        final h = await svc.getWatchHistory(
          AppState.currentPlaylist!.id,
          isXtreamCode ? _item.id : (_item.m3uItem?.id ?? _item.id),
        );
        initialPos = h?.watchDuration ?? Duration.zero;
      } catch (_) {}
    }

    // 3. Create new controller
    final next = VideoPlayerController.networkUrl(
      Uri.parse(_item.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      _push(_ui.copyWith(isBuffering: true, title: _item.name, channelIndex: _idx));
      
      await next.initialize();
      if (!mounted) {
        next.dispose();
        return;
      }

      setState(() {
        _controller = next;
      });

      next.addListener(_vpcListener);
      
      if (initialPos > Duration.zero) {
        await next.seekTo(initialPos);
      }
      
      await next.play();

      _push(_ui.copyWith(
        title        : _item.name,
        channelIndex : _idx,
        channelTotal : widget.queue.length,
        isLive       : _item.contentType == ContentType.liveStream,
        isBuffering  : false,
        duration     : next.value.duration,
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

  void _vpcListener() {
    final vpc = _controller;
    if (vpc == null || !mounted) return;

    final val = vpc.value;
    final pos = val.position;
    final dur = val.duration;

    // Buffering check
    if (val.isBuffering != _ui.isBuffering) {
      _push(_ui.copyWith(isBuffering: val.isBuffering));
    }

    final size = _controller!.value.size;
    if (size.width > 0 && size.height > 0) {
      if (size.width.toInt() != _resW || size.height.toInt() != _resH) {
        setState(() {
          _resW = size.width.toInt();
          _resH = size.height.toInt();
        });
      }
    }

    // History save
    if ((pos - _lastSaved).abs() > const Duration(seconds: 5)) {
      _historyTimer?.cancel();
      _historyTimer = Timer(const Duration(seconds: 5), () {
        _lastSaved = pos;
        _saveHistory(pos, dur);
      });
    }

    // OSD Update (Position)
    if (_ui.osdVisible) {
      _push(_ui.copyWith(position: pos, duration: dur));
    }
  }

  // ── Channel switch ─────────────────────────────────────────────────────────
  Future<void> _switchTo(int targetIdx) async {
    final i = targetIdx.clamp(0, widget.queue.length - 1);
    if (i == _idx) return;
    _idx  = i;
    _item = widget.queue[i];
    _startPlayback();
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
  bool _onKey(KeyEvent ev) {
    if (ev is! KeyDownEvent) return false;
    final k = ev.logicalKey;

    // Never consume back keys — handled by PopScope
    if (k == LogicalKeyboardKey.escape   ||
        k == LogicalKeyboardKey.goBack   ||
        k == LogicalKeyboardKey.browserBack) {
      return false;
    }

    _showOsd();

    // MENU / hamburger → toggle panel
    if (k == LogicalKeyboardKey.contextMenu ||
        k == LogicalKeyboardKey.f1 ||
        ev.logicalKey.keyId == 0x00100000052) {
      _push(_ui.copyWith(panelOpen: !_ui.panelOpen, osdVisible: true));
      _osdTimer?.cancel();
      return true;
    }

    // Live: UP/DOWN = channel change (ONLY if panel is closed)
    if (_item.contentType == ContentType.liveStream && !_ui.panelOpen) {
      if (k == LogicalKeyboardKey.arrowUp   || k == LogicalKeyboardKey.channelUp)   { _switchTo(_idx - 1); return true; }
      if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown) { _switchTo(_idx + 1); return true; }
    }

    // VOD: LEFT/RIGHT = seek ±10s
    if (_item.contentType != ContentType.liveStream && _controller != null) {
      if (k == LogicalKeyboardKey.arrowRight) {
        _controller!.seekTo(_controller!.value.position + const Duration(seconds: 10));
        return true;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        final pos = _controller!.value.position;
        final targetMs = pos.inMilliseconds - (10 * 1000);
        final durMs = _controller!.value.duration.inMilliseconds;
        _controller!.seekTo(Duration(milliseconds: targetMs.clamp(0, durMs)));
        return true;
      }
    }

    // OK/ENTER/A = play-pause
    if (k == LogicalKeyboardKey.select       ||
        k == LogicalKeyboardKey.enter        ||
        k == LogicalKeyboardKey.gameButtonA  ||
        k == LogicalKeyboardKey.mediaPlayPause) {
      if (_controller != null) {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      }
      return true;
    }

    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Map<String, String> _buildTechInfo() {
    final map = <String, String>{};
    final vpc = _controller;
    if (vpc != null && vpc.value.isInitialized) {
      final size = vpc.value.size;
      if (size.width > 0 && size.height > 0) {
        map['Resolution'] = '${size.width.toInt()} × ${size.height.toInt()}';
        final ar = size.width / size.height;
        map['Aspect ratio'] = ar.toStringAsFixed(2);
      }
      final dur = vpc.value.duration;
      if (dur.inMilliseconds > 0) {
        map['Duration'] = _fmt(dur);
      }
    }
    if (_resW != null && _resH != null) {
      // may already be in the map from size, but overwrite with freshest value
      map['Resolution'] = '$_resW × $_resH';
    }
    if (_fps != null)     map['Frame rate']  = '${_fps!.toStringAsFixed(1)} fps';
    if (_codec != null)   map['Video codec'] = _codec!;
    if (_bitrate != null) map['Bitrate']     = '${(_bitrate! / 1000).toStringAsFixed(0)} kbps';
    map['Type']      = _item.contentType.name;
    map['Container'] = _item.containerExtension?.isNotEmpty == true
                       ? _item.containerExtension!
                       : 'Unknown';
    return map;
  }

  Future<void> _closeAndPop() async {
    if (_isClosing || !mounted) return;
    _isClosing = true;

    // Pause without awaiting — fire and forget so we don't block the UI
    _controller?.pause().catchError((_) {});

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _osdTimer?.cancel();
    _historyTimer?.cancel();
    _statsTimer?.cancel();
    _uiCtrl.close();
    _focus.dispose();
    final vpc = _controller;
    if (vpc != null) {
      vpc.removeListener(_vpcListener);
      vpc.pause();
      vpc.dispose();
    }
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
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; // already handled, do nothing

        // If panel is open, close it — do NOT pop the route
        if (_ui.panelOpen) {
          _push(_ui.copyWith(panelOpen: false));
          return;
        }

        // Otherwise exit the player cleanly
        await _closeAndPop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          focusNode: _focus,
          onKeyEvent: (node, event) {
            final k = event.logicalKey;
            // Never consume back keys
            if (k == LogicalKeyboardKey.escape  ||
                k == LogicalKeyboardKey.goBack  ||
                k == LogicalKeyboardKey.browserBack) {
              return KeyEventResult.ignored;
            }
            final handled = _onKey(event);
            return handled ? KeyEventResult.handled : KeyEventResult.ignored;
          },
          // RepaintBoundary isolates video paint from overlay paint
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── VIDEO — never rebuilds after first frame ──
                Center(
                  child: _controller != null && _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : const SizedBox.shrink(),
                ),

                // ── OVERLAY — only the StreamBuilder subtree rebuilds ──
                StreamBuilder<_UiState>(
                  initialData: _ui,
                  stream: _uiCtrl.stream,
                  builder: (_, snap) {
                    final ui = snap.data ?? _ui;
                    if (_controller == null) return const SizedBox.shrink();

                    return Stack(
                      children: [
                        // New Rich Overlay
                        TvPlayerOverlay(
                          controller: _controller!,
                          item: _item,
                          isLive: ui.isLive,
                          isVisible: ui.osdVisible,
                          onShowOsd: _showOsd,
                          onTogglePanel: () => _push(_ui.copyWith(panelOpen: !_ui.panelOpen, osdVisible: true)),
                        ),
                        
                        // Legacy panel for Tracks/Info (reused for now but can be styled)
                        if (ui.panelOpen)
                          Positioned(
                            top: 0, bottom: 0,
                            right: 0, width: 400,
                            child: _buildPanel(context, ui),
                          ),

                        // Buffering indicator
                        if (ui.isBuffering)
                          const Center(
                            child: CircularProgressIndicator(color: Colors.white70),
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

  // Refactored panel builder (previously in _Overlay)
  Widget _buildPanel(BuildContext context, _UiState ui) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF2101020),
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
            child: Row(children: [
              Expanded(
                child: Text(_item.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => _push(_ui.copyWith(panelOpen: false))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _Tab(label: 'Subtitle', i: 0, cur: ui.panelTab, onTap: (t) => _push(_ui.copyWith(panelTab: t))),
              _Tab(label: 'Info',     i: 1, cur: ui.panelTab, onTap: (t) => _push(_ui.copyWith(panelTab: t))),
              if (_item.contentType == ContentType.liveStream)
                _Tab(label: 'Channels', i: 2, cur: ui.panelTab, onTap: (t) => _push(_ui.copyWith(panelTab: t))),
              if (_item.contentType == ContentType.series)
                _Tab(label: 'Episodes', i: 3, cur: ui.panelTab, onTap: (t) => _push(_ui.copyWith(panelTab: t))),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(child: switch (ui.panelTab) {
            0 => _tracksTab(context),
            1 => _infoTab(),
            2 => _channelsTab(context),
            3 => _episodesTab(context),
            _ => const SizedBox.shrink(),
          }),
        ],
      ),
    );
  }

  Widget _tracksTab(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.white38, size: 48),
            SizedBox(height: 16),
            Text('Track selection is managed by ExoPlayer hardware decoder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _infoTab() {
    final tech = _buildTechInfo();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_item.imagePath.isNotEmpty)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _item.imagePath,
                  width: 160, height: 120, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _item.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (_item.contentType == ContentType.liveStream) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          if (_item.m3uItem?.groupTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _IRow(label: 'Category', value: _item.m3uItem!.groupTitle!),
          ],
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            'Stream info',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          for (final e in tech.entries)
            _IRow(label: e.key, value: e.value),
        ],
      ),
    );
  }

  Widget _channelsTab(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Browse categories button ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter  ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                _openLiveCategories();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(builder: (ctx) {
              final hasFocus = Focus.of(ctx).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hasFocus ? Colors.white24 : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFocus ? Colors.white : Colors.white12,
                    width: hasFocus ? 2 : 1,
                  ),
                ),
                child: GestureDetector(
                  onTap: _openLiveCategories,
                  child: Row(
                    children: const [
                      Icon(Icons.list_rounded, size: 18, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Browse categories',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        // ── Channel list ──────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: widget.queue.length,
            itemBuilder: (_, i) {
              final ch  = widget.queue[i];
              final sel = i == _idx;
              return Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    _switchTo(i);
                    _push(_ui.copyWith(panelOpen: false));
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(builder: (ctx) {
                  final f = Focus.of(ctx).hasFocus;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: f ? Colors.white10 : (sel ? primary.withValues(alpha: 0.1) : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                      border: f
                          ? Border.all(color: primary, width: 2)
                          : Border.all(color: Colors.transparent, width: 2),
                    ),
                    child: ListTile(
                      dense: true,
                      selected: sel,
                      leading: ch.imagePath.isNotEmpty
                          ? Image.network(ch.imagePath, width: 32, height: 32, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.live_tv, size: 20, color: Colors.white38))
                          : const Icon(Icons.live_tv, size: 20, color: Colors.white38),
                      title: Text(
                        ch.name,
                        style: TextStyle(
                          color: f || sel ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _switchTo(i);
                        _push(_ui.copyWith(panelOpen: false));
                      },
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openLiveCategories() {
    _push(_ui.copyWith(panelOpen: false));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TvLiveTvScreen()),
    ).then((_) {
      // Re-request focus when we come back so key events work again
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  Widget _episodesTab(BuildContext context) {
    if (_item.episodes == null || _item.episodes!.isEmpty) {
      return const Center(
        child: Text('No episodes found', style: TextStyle(color: Colors.white38)),
      );
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Browse categories button ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter  ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                _openSeriesCategories();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(builder: (ctx) {
              final hasFocus = Focus.of(ctx).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hasFocus ? Colors.white24 : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFocus ? Colors.white : Colors.white12,
                    width: hasFocus ? 2 : 1,
                  ),
                ),
                child: GestureDetector(
                  onTap: _openSeriesCategories,
                  child: Row(
                    children: const [
                      Icon(Icons.list_rounded, size: 18, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Browse categories',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        // ── Episode list ──────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _item.episodes!.length,
            itemBuilder: (_, i) {
              final ep = _item.episodes![i];
              return Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    _switchToEpisode(ep);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(builder: (ctx) {
                  final f = Focus.of(ctx).hasFocus;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: f ? Colors.white10 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: f
                          ? Border.all(color: primary, width: 2)
                          : Border.all(color: Colors.transparent, width: 2),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        ep.name,
                        style: TextStyle(
                          color: f ? Colors.white : Colors.white60,
                          fontSize: 13,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _switchToEpisode(ep),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openSeriesCategories() {
    _push(_ui.copyWith(panelOpen: false));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TvSeriesScreen()),
    ).then((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  void _switchToEpisode(ContentItem ep) {
    _push(_ui.copyWith(panelOpen: false));
    final episodes = _item.episodes ?? [];
    final idx = episodes.indexOf(ep);
    // Update in place instead of replacing the route
    setState(() {
      _item = ep;
      _idx  = idx < 0 ? 0 : idx;
    });
    _startPlayback();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Tab extends StatelessWidget {
  final String label;
  final int i, cur;
  final void Function(int) onTap;
  const _Tab({required this.label, required this.i,
               required this.cur, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = i == cur;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
          onTap(i);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final f = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
                color: f ? Colors.white24 : (active ? Theme.of(context).colorScheme.primary : Colors.white10),
                borderRadius: BorderRadius.circular(6),
                border: f ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Text(label,
              style: TextStyle(
                color: f || active ? Colors.white : Colors.white54,
                fontSize: 12, fontWeight: f || active ? FontWeight.bold : FontWeight.normal)),
          ),
        );
      }),
    );
  }
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
