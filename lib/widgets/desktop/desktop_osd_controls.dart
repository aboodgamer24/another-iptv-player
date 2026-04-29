import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:c4tv_player/models/content_type.dart';
import 'package:c4tv_player/services/player_state.dart';
import 'package:c4tv_player/services/event_bus.dart';

/// Minimalist OSD overlay for desktop playback.
/// Auto-hides after inactivity, revealed on mouse move.
class DesktopOsdControls extends StatefulWidget {
  final Player player;
  final String title;
  final ContentType contentType;
  final VoidCallback? onBack;

  const DesktopOsdControls({
    super.key,
    required this.player,
    required this.title,
    required this.contentType,
    this.onBack,
  });

  @override
  State<DesktopOsdControls> createState() => _DesktopOsdControlsState();
}

class _DesktopOsdControlsState extends State<DesktopOsdControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  bool _isMuted = false;
  bool _isDragging = false;
  double _dragPosition = 0;

  late StreamSubscription _playingSub;
  late StreamSubscription _positionSub;
  late StreamSubscription _durationSub;
  late StreamSubscription _volumeSub;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.player.state.playing;
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _volume = widget.player.state.volume;

    _playingSub = widget.player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    _positionSub = widget.player.stream.position.listen((p) {
      if (mounted && !_isDragging) setState(() => _position = p);
    });
    _durationSub = widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _volumeSub = widget.player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });

    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playingSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _volumeSub.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_visible) setState(() => _visible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) setState(() => _visible = false);
    });
  }

  void _onMouseMove(PointerEvent _) => _resetHideTimer();

  void _togglePlayPause() {
    widget.player.playOrPause();
    _resetHideTimer();
  }

  void _seek(Duration pos) {
    widget.player.seek(pos);
    _resetHideTimer();
  }

  void _toggleMute() {
    if (_isMuted) {
      widget.player.setVolume(_volume > 0 ? _volume : 100);
    } else {
      widget.player.setVolume(0);
    }
    setState(() => _isMuted = !_isMuted);
    _resetHideTimer();
  }

  void _changeVolume(double v) {
    widget.player.setVolume(v);
    if (_isMuted && v > 0) setState(() => _isMuted = false);
    _resetHideTimer();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlayPause();
        break;
      case LogicalKeyboardKey.keyM:
        _toggleMute();
        break;
      case LogicalKeyboardKey.arrowLeft:
        _seek(_position - const Duration(seconds: 10));
        break;
      case LogicalKeyboardKey.arrowRight:
        _seek(_position + const Duration(seconds: 10));
        break;
      case LogicalKeyboardKey.arrowUp:
        _changeVolume((_volume + 5).clamp(0, 100));
        break;
      case LogicalKeyboardKey.arrowDown:
        _changeVolume((_volume - 5).clamp(0, 100));
        break;
      case LogicalKeyboardKey.escape:
        widget.onBack?.call();
        break;
      default:
        break;
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: MouseRegion(
        onHover: _onMouseMove,
        onEnter: (_) => _resetHideTimer(),
        child: GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Top: Title bar
              if (_visible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          if (widget.onBack != null)
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: widget.onBack,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              PlayerState.title.isNotEmpty
                                  ? PlayerState.title
                                  : widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom: Controls
              if (_visible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: _visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          if (widget.contentType != ContentType.liveStream &&
                              _duration > Duration.zero)
                            _buildSeekBar(),
                          const SizedBox(height: 8),
                          // Control row
                          _buildControlRow(),
                        ],
                      ),
                    ),
                  ),
                ),

              // Center: Big play button when paused
              if (!_isPlaying && _visible)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    final totalMs = _duration.inMilliseconds.toDouble();
    final currentMs =
        (_isDragging ? _dragPosition : _position.inMilliseconds.toDouble())
            .clamp(0.0, totalMs > 0 ? totalMs : 1.0);

    return Row(
      children: [
        Text(
          _fmt(
            _isDragging ? Duration(milliseconds: currentMs.toInt()) : _position,
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: const Color(0xFF5A45FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF5A45FF).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: currentMs,
              min: 0,
              max: totalMs > 0 ? totalMs : 1.0,
              onChangeStart: (v) {
                setState(() {
                  _isDragging = true;
                  _dragPosition = v;
                });
              },
              onChanged: (v) {
                setState(() => _dragPosition = v);
              },
              onChangeEnd: (v) {
                _seek(Duration(milliseconds: v.toInt()));
                setState(() => _isDragging = false);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _fmt(_duration),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildControlRow() {
    return Row(
      children: [
        // Play/Pause
        _OsdButton(
          icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: _togglePlayPause,
        ),

        // Channel up/down for live
        if (widget.contentType == ContentType.liveStream) ...[
          const SizedBox(width: 8),
          _OsdButton(
            icon: Icons.skip_previous_rounded,
            onTap: () => EventBus().emit(
              'player_content_item_index_changed',
              (PlayerState.currentIndex) - 1,
            ),
            size: 20,
          ),
          const SizedBox(width: 4),
          _OsdButton(
            icon: Icons.skip_next_rounded,
            onTap: () => EventBus().emit(
              'player_content_item_index_changed',
              (PlayerState.currentIndex) + 1,
            ),
            size: 20,
          ),
        ],

        // Next for VOD/Series
        if (widget.contentType != ContentType.liveStream) ...[
          const SizedBox(width: 8),
          _OsdButton(
            icon: Icons.skip_next_rounded,
            onTap: () => widget.player.jump(
              (widget.player.state.playlist.index + 1).clamp(
                0,
                widget.player.state.playlist.medias.length - 1,
              ),
            ),
            size: 20,
          ),
        ],

        const Spacer(),

        // Volume
        _OsdButton(
          icon: _isMuted || _volume == 0
              ? Icons.volume_off_rounded
              : (_volume < 50
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded),
          onTap: _toggleMute,
          size: 20,
        ),
        SizedBox(
          width: 100,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _isMuted ? 0 : _volume,
              min: 0,
              max: 100,
              onChanged: _changeVolume,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Channel list toggle
        _OsdButton(
          icon: Icons.list_rounded,
          onTap: () {
            PlayerState.showChannelList = !PlayerState.showChannelList;
            EventBus().emit('toggle_channel_list', PlayerState.showChannelList);
          },
          size: 20,
        ),
      ],
    );
  }
}

class _OsdButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _OsdButton({required this.icon, required this.onTap, this.size = 24});

  @override
  State<_OsdButton> createState() => _OsdButtonState();
}

class _OsdButtonState extends State<_OsdButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Icon(widget.icon, color: Colors.white, size: widget.size),
        ),
      ),
    );
  }
}
