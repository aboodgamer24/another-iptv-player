import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../services/player_state.dart' as app_player_state;
import '../../models/content_type.dart';
import '../../models/category_view_model.dart';
import '../../services/fullscreen_notifier.dart';
import '../../utils/get_playlist_type.dart';
import '../../services/event_bus.dart';
import '../../models/playlist_content_model.dart';
import '../../repositories/user_preferences.dart';
import '../player-buttons/low_latency_button.dart';
import '../player-buttons/video_settings_widget.dart';

class C4PlayerOverlay extends StatefulWidget {
  final Player player;
  final VideoController controller;

  final XtreamCodeHomeController? homeController;
  final VoidCallback? onFullscreenOverride;
  final bool isInline;
  final ContentType? contentType;

  const C4PlayerOverlay({
    super.key,
    required this.player,
    required this.controller,
    this.homeController,
    this.onFullscreenOverride,
    this.isInline = false,
    this.contentType,
  });

  @override
  State<C4PlayerOverlay> createState() => _C4PlayerOverlayState();
}

enum _SidePanelMode { channels, categories }

class _C4PlayerOverlayState extends State<C4PlayerOverlay> {
  bool _isVisible = true;
  bool _showSidePanel = false;
  bool _showInfoPanel = false;
  bool _nativeFullscreen = false;
  _SidePanelMode _sidePanelMode = _SidePanelMode.channels;
  
  // Stream metadata state
  int? _resW;
  int? _resH;
  double? _fps;
  int? _bitrate;
  String? _codec;
  String? _upscalerPreset;
  bool _showEnhancementPanel = false;

  // Gesture flags
  bool _brightnessGesture = false;
  bool _volumeGesture = false;
  bool _seekGesture = false;
  bool _speedUpOnLongPress = true;
  bool _seekOnDoubleTap = true;

  // Enhancement values — MPV ranges
  double _sharpness = 0.0;      // range: -1.0 to 1.0, default 0
  double _contrast = 0.0;       // range: -1.0 to 1.0, default 0
  double _saturation = 0.0;     // range: -1.0 to 1.0, default 0
  double _noiseReduction = 0.0; // range: 0.0 to 1.0, default 0
  
  Timer? _hideTimer;
  Timer? _statsTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isMuted = false;
  late List<StreamSubscription> _subscriptions;
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'player_overlay');

  final _positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final _durationNotifier = ValueNotifier<Duration>(Duration.zero);
  List<ContentItem>? _panelQueue;

  @override
  void initState() {
    super.initState();
    _volume = widget.player.state.volume / 100.0;
    _isMuted = widget.player.state.volume == 0;
    _loadGesturePrefs();
    _startHideTimer();
    _panelQueue = app_player_state.PlayerState.queue;
    _subscriptions = [
      widget.player.stream.position.listen((p) {
        _positionNotifier.value = p;
        _position = p;
      }),
      widget.player.stream.duration.listen((d) {
        _durationNotifier.value = d;
        _duration = d;
      }),
      widget.player.stream.volume.listen((v) {
        if (!mounted) return;
        final newVol = v / 100.0;
        final newMuted = v == 0;
        if (newVol != _volume || newMuted != _isMuted) {
          setState(() {
            _volume = newVol;
            _isMuted = newMuted;
          });
        }
      }),
      // videoParams for resolution
      widget.player.stream.videoParams.listen((vp) {
        if (!mounted) return;
        if ((vp.w != null && vp.w != _resW) || (vp.h != null && vp.h != _resH)) {
          setState(() {
            if (vp.w != null && vp.w! > 0) _resW = vp.w;
            if (vp.h != null && vp.h! > 0) _resH = vp.h;
          });
        }
      }),

      // Available tracks list carries demuxer metadata (fps, bitrate, codec)
      widget.player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        for (final vt in tracks.video) {
          // Skip pseudo-tracks ('auto', 'no')
          if (vt.id == 'auto' || vt.id == 'no') continue;
          final newFps = vt.fps;
          final newBitrate = vt.bitrate;
          final newCodec = vt.codec;
          final newW = vt.w;
          final newH = vt.h;
          if (newFps != _fps || newBitrate != _bitrate || newCodec != _codec ||
              newW != _resW || newH != _resH) {
            setState(() {
              if (newFps != null && newFps > 0) _fps = newFps;
              if (newBitrate != null && newBitrate > 0) _bitrate = newBitrate;
              if (newCodec != null && newCodec!.isNotEmpty) _codec = newCodec;
              if (newW != null && newW > 0) _resW = newW;
              if (newH != null && newH > 0) _resH = newH;
            });
          }
          break; // use the first real video track
        }
      }),

      // Selected track subscription — subtitle state
      widget.player.stream.track.listen((track) {
        if (!mounted) return;
        setState(() {
          app_player_state.PlayerState.subtitles =
              widget.player.state.tracks.subtitle;
          app_player_state.PlayerState.selectedSubtitle =
              widget.player.state.track.subtitle;
        });
      }),
    ];

    // Periodic poll for live stats (tracks metadata may update over time)
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_showInfoPanel) return;
      final tracks = widget.player.state.tracks;
      for (final vt in tracks.video) {
        if (vt.id == 'auto' || vt.id == 'no') continue;
        setState(() {
          if (vt.fps != null && vt.fps! > 0) _fps = vt.fps;
          if (vt.bitrate != null && vt.bitrate! > 0) _bitrate = vt.bitrate;
          if (vt.codec != null && vt.codec!.isNotEmpty) _codec = vt.codec;
          if (vt.w != null && vt.w! > 0) _resW = vt.w;
          if (vt.h != null && vt.h! > 0) _resH = vt.h;
        });
        break;
      }
      // Also refresh resolution from videoParams
      final vp = widget.player.state.videoParams;
      if (vp.w != null && vp.w! > 0) _resW = vp.w;
      if (vp.h != null && vp.h! > 0) _resH = vp.h;
      final nativeP = widget.player.platform;
      if (nativeP is NativePlayer) {
        nativeP.getProperty('scale').then((liveValue) {
          if (mounted) setState(() => _upscalerPreset = liveValue);
        }).catchError((_) {});
      }
    });

    // Read the actual live value from MPV so we show what is truly applied
    final nativeInit = widget.player.platform;
    if (nativeInit is NativePlayer) {
      nativeInit.getProperty('scale').then((liveValue) {
        if (mounted) setState(() => _upscalerPreset = liveValue);
      }).catchError((_) {});
    }

    // Request focus once so keyboard shortcuts work,
    // but never steal it again after that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_keyboardFocusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_keyboardFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _statsTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _keyboardFocusNode.dispose();
    if (_nativeFullscreen) {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        windowManager.setFullScreen(false);
        windowManager.setTitleBarStyle(TitleBarStyle.normal);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadGesturePrefs() async {
    final b = await UserPreferences.getBrightnessGesture();
    final v = await UserPreferences.getVolumeGesture();
    final s = await UserPreferences.getSeekGesture();
    final lp = await UserPreferences.getSpeedUpOnLongPress();
    final dt = await UserPreferences.getSeekOnDoubleTap();
    if (mounted) {
      setState(() {
        _brightnessGesture = b;
        _volumeGesture = v;
        _seekGesture = s;
        _speedUpOnLongPress = lp;
        _seekOnDoubleTap = dt;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_showSidePanel || _showInfoPanel || _showEnhancementPanel) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isVisible = false);
    });
  }

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
      if (_isVisible) _startHideTimer();
    });
  }

  void _showOverlay() {
    setState(() {
      _isVisible = true;
      _startHideTimer();
    });
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    }
    return "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // First press simply reveals overlay
    if (!_isVisible) {
      _showOverlay();
      return;
    }

    _startHideTimer();

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.pageUp) {
      _adjustVolume(0.05);
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.pageDown) {
      _adjustVolume(-0.05);
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace) {
      if (_showSidePanel) {
        setState(() => _showSidePanel = false);
      } else if (_showInfoPanel) {
        setState(() => _showInfoPanel = false);
      } else if (_showEnhancementPanel) {
        setState(() => _showEnhancementPanel = false);
      } else if (!widget.isInline) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleFullscreen() async {
    if (widget.onFullscreenOverride != null) {
      widget.onFullscreenOverride!.call();
    } else {
      await _toggleNativeFullscreen();
    }
  }

  Future<void> _toggleNativeFullscreen() async {
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isDesktop) {
      if (_nativeFullscreen) {
        await windowManager.setFullScreen(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      } else {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setFullScreen(true);
      }
    } else {
      if (_nativeFullscreen) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
    if (mounted) setState(() => _nativeFullscreen = !_nativeFullscreen);
  }

  void _openSubtitleSelector() {
    _startHideTimer();
    final theme = Theme.of(context);
    final subs = app_player_state.PlayerState.subtitles;
    final selected = app_player_state.PlayerState.selectedSubtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Subtitle Selection',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                   _buildSubtitleTile('Auto', SubtitleTrack.auto(), selected, theme),
                   _buildSubtitleTile('Off', SubtitleTrack.no(), selected, theme),
                   ...subs.map((track) => _buildSubtitleTile(
                     '${track.language ?? "Unknown"} ${track.title ?? ""}'.trim(), 
                     track, 
                     selected, 
                     theme
                   )),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleTile(String title, SubtitleTrack track, SubtitleTrack selected, ThemeData theme) {
    final isSelected = selected == track;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: isSelected ? theme.colorScheme.primary : Colors.white24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        widget.player.setSubtitleTrack(track);
        Navigator.pop(context);
      },
    );
  }

  ContentType? _currentContentType() {
    final queue = app_player_state.PlayerState.queue;
    if (queue == null || queue.isEmpty) return null;
    return queue.first.contentType;
  }

  void _adjustVolume(double delta) {
    double newVol = (_volume + delta).clamp(0.0, 1.0);
    widget.player.setVolume(newVol * 100);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = _duration.inSeconds == 0;
    final videoTrack = widget.player.state.track.video;

    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenNotifier,
      builder: (context, isFullscreen, _) {
        return KeyboardListener(
          focusNode: _keyboardFocusNode,
          onKeyEvent: (event) {
            // Only handle keys when no TextField has focus
            if (FocusManager.instance.primaryFocus?.context
                    ?.widget is! EditableText) {
              _onKey(event);
            }
          },
          child: GestureDetector(
            onTap: _toggleVisibility,
            behavior: HitTestBehavior.translucent,
            // Volume / Brightness — vertical swipe on halves
            onVerticalDragUpdate: (_volumeGesture || _brightnessGesture) ? (details) {
              final width = MediaQuery.sizeOf(context).width;
              final isLeft = details.localPosition.dx < width / 2;
              if (isLeft && _brightnessGesture) {
                // Brightness placeholder (requires package, for now just show overlay)
                _showOverlay();
              } else if (!isLeft && _volumeGesture) {
                final delta = -details.primaryDelta! / 200;
                _adjustVolume(delta);
                _showOverlay();
              }
            } : null,
            // Seek — horizontal swipe
            onHorizontalDragUpdate: _seekGesture ? (details) {
              final delta = details.primaryDelta! * 0.5;
              final newPos = _position + Duration(seconds: delta.toInt());
              widget.player.seek(newPos);
              _showOverlay();
            } : null,
            // Speed up on long press
            onLongPressStart: _speedUpOnLongPress ? (_) {
              widget.player.setRate(2.0);
              _showOverlay();
            } : null,
            onLongPressEnd: _speedUpOnLongPress ? (_) {
              widget.player.setRate(1.0);
            } : null,
            // Seek on double tap (halves)
            onDoubleTapDown: _seekOnDoubleTap ? (details) {
              final width = MediaQuery.sizeOf(context).width;
              final isLeft = details.localPosition.dx < width / 2;
              if (isLeft) {
                widget.player.seek(_position - const Duration(seconds: 10));
              } else {
                widget.player.seek(_position + const Duration(seconds: 10));
              }
              _showOverlay();
            } : null,
            child: Stack(
              children: [
                // Overlay Content
                AnimatedOpacity(
                  opacity: _isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_isVisible,
                    child: Stack(
                      children: [
                        // Top Bar
                        _buildTopBar(theme, isFullscreen),

                        // Bottom Bar
                        _buildBottomBar(theme, isLive),

                        // Info Panel (Metadata overlay)
                        if (_showInfoPanel) _buildInfoPanel(theme, videoTrack),
                        if (_showEnhancementPanel) _buildEnhancementPanel(theme),
                      ],
                    ),
                  ),
                ),

                // Side Panel (Always accessible if visible, or can trigger visibility)
                if (_showSidePanel) _buildSidePanel(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(ThemeData theme, bool isFullscreen) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return Container(
            height: compact ? 52 : 120,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 40,
              vertical: compact ? 8 : 40,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                if (!widget.isInline) ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: compact ? 18 : 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: compact ? 6 : 20),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        app_player_state.PlayerState.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 12 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!compact && isXtreamCode)
                        Text(
                          'Live TV Stream',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                    ],
                  ),
                ),
                if (!compact)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 20,
                    icon: Icon(
                      Icons.tune_rounded,
                      color: _showEnhancementPanel
                          ? theme.colorScheme.primary
                          : Colors.white,
                    ),
                    onPressed: () => setState(() {
                      _showEnhancementPanel = !_showEnhancementPanel;
                      _showInfoPanel = false;
                      _showSidePanel = false;
                      _startHideTimer();
                    }),
                  ),
                if (!compact) const SizedBox(width: 8),
                if (!compact)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      _showInfoPanel
                          ? Icons.info_rounded
                          : Icons.info_outline_rounded,
                      color: _showInfoPanel
                          ? theme.colorScheme.primary
                          : Colors.white,
                    ),
                    onPressed: () => setState(() {
                      _showInfoPanel = !_showInfoPanel;
                      _showSidePanel = false;
                      _showEnhancementPanel = false;
                      _startHideTimer();
                    }),
                  ),
                if (!compact) const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    _showSidePanel
                        ? Icons.menu_open_rounded
                        : Icons.menu_rounded,
                    color: _showSidePanel
                        ? theme.colorScheme.primary
                        : Colors.white,
                    size: compact ? 20 : 24,
                  ),
                  onPressed: () => setState(() {
                    _showSidePanel = !_showSidePanel;
                    _showInfoPanel = false;
                    _showEnhancementPanel = false;
                    _startHideTimer();
                  }),
                ),
                if (!compact)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      Icons.subtitles_rounded,
                      color: app_player_state.PlayerState.selectedSubtitle ==
                              SubtitleTrack.no()
                          ? Colors.white
                          : theme.colorScheme.primary,
                    ),
                    onPressed: _openSubtitleSelector,
                  ),
                if (!compact) const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    (_nativeFullscreen || isFullscreen)
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: compact ? 20 : 24,
                  ),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool isLive) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 60,
              compact ? 16 : 40,
              compact ? 12 : 60,
              compact ? 12 : 60,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLive) ...[
                    ValueListenableBuilder<Duration>(
                      valueListenable: _positionNotifier,
                      builder: (context, position, _) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: _durationNotifier,
                          builder: (context, duration, _) {
                            final total = duration.inSeconds.toDouble().clamp(1.0, double.infinity);
                            final current = position.inSeconds.toDouble().clamp(0.0, total);
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: theme.colorScheme.primary,
                                    overlayColor:
                                        theme.colorScheme.primary.withValues(alpha: 0.2),
                                    trackHeight: compact ? 2 : 4,
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: compact ? 4 : 6,
                                    ),
                                  ),
                                  child: Slider(
                                    value: current,
                                    max: total,
                                    onChanged: (val) =>
                                        widget.player.seek(Duration(seconds: val.toInt())),
                                  ),
                                ),
                                if (!compact) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position),
                                          style: const TextStyle(color: Colors.white70)),
                                      Text(_formatDuration(duration),
                                          style: const TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.circle,
                          color: Colors.red, size: compact ? 8 : 10),
                      SizedBox(width: compact ? 4 : 8),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: compact ? 8 : 24),
                Row(
                  children: [
                    _PlayerControlBtn(
                      icon: widget.player.state.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      isLarge: !compact,
                      size: compact ? 32 : 64,
                      iconSize: compact ? 20 : 40,
                      onPressed: () => widget.player.playOrPause(),
                    ),
                    SizedBox(width: compact ? 8 : 32),
                    Icon(
                      _isMuted || _volume == 0
                          ? Icons.volume_off_rounded
                          : _volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded,
                      color: Colors.white70,
                      size: compact ? 18 : 24,
                    ),
                    if (!compact)
                      SizedBox(
                        width: 150,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: Colors.white,
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _volume,
                            onChanged: (val) =>
                                widget.player.setVolume(val * 100),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (!isLive && !compact) ...[
                      _PlayerControlBtn(
                        icon: Icons.replay_10_rounded,
                        size: 48,
                        iconSize: 24,
                        onPressed: () => widget.player
                            .seek(_position - const Duration(seconds: 10)),
                      ),
                      const SizedBox(width: 16),
                      _PlayerControlBtn(
                        icon: Icons.forward_10_rounded,
                        size: 48,
                        iconSize: 24,
                        onPressed: () => widget.player
                            .seek(_position + const Duration(seconds: 10)),
                      ),
                    ],
                    const SizedBox(width: 16),
                    const LowLatencyButton(),
                    const SizedBox(width: 8),
                    const VideoSettingsWidget(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _applyEnhancement() async {
    final native = widget.player.platform;
    if (native is! NativePlayer) return;

    // MPV sharpen uses lavfi — map -1..1 to -5..5
    final sharpVal = (_sharpness * 5).clamp(-5.0, 5.0);
    // MPV contrast/saturation use -100 to 100 integer scale
    final contrastVal = (_contrast * 100).round();
    final saturationVal = (_saturation * 100).round();
    // denoise maps 0..1 to 0..10 for hqdn3d strength
    final denoiseVal = (_noiseReduction * 10).clamp(0.0, 10.0);

    try {
      await native.setProperty('sharpen', sharpVal.toStringAsFixed(3));
      await native.setProperty('contrast', contrastVal.toString());
      await native.setProperty('saturation', saturationVal.toString());
      if (_noiseReduction > 0.01) {
        await native.setProperty(
          'vf', 'hqdn3d=${denoiseVal.toStringAsFixed(1)}:${denoiseVal.toStringAsFixed(1)}:6:6',
        );
      } else {
        await native.setProperty('vf', '');
      }
    } catch (e) {
      debugPrint('[Enhancement] Failed to apply: $e');
    }
  }

  Widget _buildEnhancementPanel(ThemeData theme) {
    return Positioned(
      top: 130,
      right: 40,
      child: Container(
        width: 320,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enhancement',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildEnhancementSlider(
                theme,
                label: 'Sharpness',
                icon: Icons.landscape_rounded,
                value: _sharpness,
                min: -1.0,
                max: 1.0,
                onChanged: (val) {
                  setState(() => _sharpness = val);
                  _applyEnhancement();
                },
              ),
              _buildEnhancementSlider(
                theme,
                label: 'Contrast',
                icon: Icons.contrast_rounded,
                value: _contrast,
                min: -1.0,
                max: 1.0,
                onChanged: (val) {
                  setState(() => _contrast = val);
                  _applyEnhancement();
                },
              ),
              _buildEnhancementSlider(
                theme,
                label: 'Saturation',
                icon: Icons.color_lens_rounded,
                value: _saturation,
                min: -1.0,
                max: 1.0,
                onChanged: (val) {
                  setState(() => _saturation = val);
                  _applyEnhancement();
                },
              ),
              _buildEnhancementSlider(
                theme,
                label: 'Noise Reduction',
                icon: Icons.grain_rounded,
                value: _noiseReduction,
                min: 0.0,
                max: 1.0,
                onChanged: (val) {
                  setState(() => _noiseReduction = val);
                  _applyEnhancement();
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _sharpness = 0.0;
                    _contrast = 0.0;
                    _saturation = 0.0;
                    _noiseReduction = 0.0;
                  });
                  _applyEnhancement();
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset All'),
                style: TextButton.styleFrom(foregroundColor: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancementSlider(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                  color: value == 0.0 ? Colors.white38 : theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: Colors.white12,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(ThemeData theme, VideoTrack track) {
    return Positioned(
      top: 130,
      right: 40,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stream Information',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Title', value: app_player_state.PlayerState.title),
            _InfoRow(
              label: 'Resolution', 
              value: (_resW != null && _resH != null && _resW! > 0) ? '$_resW x $_resH' : 'N/A'
            ),
            _InfoRow(label: 'FPS', value: _fps != null ? _fps!.toStringAsFixed(2) : 'N/A'),
            _InfoRow(label: 'Codec', value: (_codec != null && _codec!.isNotEmpty) ? _codec! : 'N/A'),
            _InfoRow(
              label: 'Upscaler',
              value: (_upscalerPreset == null || _upscalerPreset!.isEmpty || _upscalerPreset == 'none')
                  ? 'Disabled'
                  : _upscalerPreset!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(ThemeData theme) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    final safePadding = MediaQuery.paddingOf(context);

    final panelWidth = isPhone
        ? (screenWidth * 0.85).clamp(220.0, 320.0)
        : 350.0;

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: SizedBox(
        width: panelWidth,
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.97),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  safePadding.top + 12,
                  8,
                  12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _sidePanelMode == _SidePanelMode.channels
                            ? 'Channel List'
                            : 'Categories',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isPhone ? 15 : 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      iconSize: isPhone ? 20 : 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => setState(() => _showSidePanel = false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _sidePanelMode == _SidePanelMode.channels
                    ? _buildChannelListView(theme)
                    : _buildCategoryListView(theme, widget.homeController),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  safePadding.bottom + 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_sidePanelMode == _SidePanelMode.channels) {
                          if (widget.homeController != null) {
                            _sidePanelMode = _SidePanelMode.categories;
                          }
                        } else {
                          _sidePanelMode = _SidePanelMode.channels;
                        }
                      });
                    },
                    icon: Icon(
                      _sidePanelMode == _SidePanelMode.channels
                          ? Icons.explore_outlined
                          : Icons.arrow_back_rounded,
                      size: isPhone ? 16 : 18,
                    ),
                    label: Text(
                      _sidePanelMode == _SidePanelMode.channels
                          ? (widget.homeController != null
                              ? 'Browse categories'
                              : 'Categories unavailable')
                          : 'Back to channels',
                      style: TextStyle(fontSize: isPhone ? 12 : 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white10),
                      padding: EdgeInsets.symmetric(
                        vertical: isPhone ? 10 : 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelListView(ThemeData theme) {
    final channels = _panelQueue ?? app_player_state.PlayerState.queue ?? [];
    final currentContent = app_player_state.PlayerState.currentContent;
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: isPhone ? 4 : 8),
      itemExtent: isPhone ? 56.0 : 64.0,
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isPlaying = currentContent != null && channel.id == currentContent.id;
        
        return ListTile(
          selected: isPlaying,
          selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white10,
            ),
            child: channel.imageUrl.isNotEmpty
                ? Image.network(
                    channel.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.live_tv, size: 20, color: Colors.white24),
                  )
                : const Icon(Icons.live_tv, size: 20, color: Colors.white24),
          ),
          title: Text(
            channel.name,
            style: TextStyle(
              color: isPlaying ? theme.colorScheme.primary : Colors.white,
              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
              fontSize: isPhone ? 13 : 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            app_player_state.PlayerState.queue = channels;
            EventBus().emit('player_queue_changed', channels);
            EventBus().emit('player_content_item_index_changed', index);
            
            setState(() {
              _showSidePanel = false;
              _isVisible = true;
            });
            _startHideTimer();
          },
        );
      },
    );
  }

  Widget _buildCategoryListView(ThemeData theme, XtreamCodeHomeController? homeController) {
    final categories = homeController == null ? <CategoryViewModel>[] : (() {
      final type = _currentContentType();
      if (type == ContentType.vod) return homeController.visibleMovieCategories;
      if (type == ContentType.series) return homeController.visibleSeriesCategories;
      return homeController.liveCategories ?? [];
    })();

    if (homeController == null || categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Categories not available for this playlist',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final categoryVM = categories[index];
        
        return ListTile(
          title: Text(
            categoryVM.category.categoryName,
            style: const TextStyle(color: Colors.white),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          onTap: () {
            setState(() {
              _panelQueue = categoryVM.contentItems;
              _sidePanelMode = _SidePanelMode.channels;
              _isVisible = true;
            });
            _startHideTimer();
          },
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final bool isLarge;

  const _PlayerControlBtn({
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconSize = 24,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLarge ? theme.colorScheme.primary : Colors.white10,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
