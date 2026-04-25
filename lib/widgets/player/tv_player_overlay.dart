import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../models/playlist_content_model.dart';
import '../../models/content_type.dart';

class TvPlayerOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final ContentItem item;
  final bool isLive;
  final VoidCallback onTogglePanel;
  final VoidCallback onShowOsd;
  final bool isVisible;

  const TvPlayerOverlay({
    super.key,
    required this.controller,
    required this.item,
    required this.isLive,
    required this.onTogglePanel,
    required this.onShowOsd,
    required this.isVisible,
  });

  @override
  State<TvPlayerOverlay> createState() => _TvPlayerOverlayState();
}

class _TvPlayerOverlayState extends State<TvPlayerOverlay> {
  final FocusNode _playPauseNode = FocusNode();
  final FocusNode _rewindNode    = FocusNode();
  final FocusNode _forwardNode   = FocusNode();
  final FocusNode _tracksNode    = FocusNode();
  final FocusNode _infoNode      = FocusNode();
  final FocusNode _seekNode      = FocusNode();

  @override
  void initState() {
    super.initState();
    // Default focus on Play/Pause
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isVisible) {
        _playPauseNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _playPauseNode.dispose();
    _rewindNode.dispose();
    _forwardNode.dispose();
    _tracksNode.dispose();
    _infoNode.dispose();
    _seekNode.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _seekRelative(int seconds) {
    final pos = widget.controller.value.position;
    final targetMs = pos.inMilliseconds + (seconds * 1000);
    final durMs = widget.controller.value.duration.inMilliseconds;
    final clampedMs = targetMs.clamp(0, durMs);
    widget.controller.seekTo(Duration(milliseconds: clampedMs));
    widget.onShowOsd();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: widget.isVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // ── Top Title Area ──
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10)]),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                  ],
                ),
              ),

              // ── Seek Bar (VOD only) ──
              if (!widget.isLive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: ValueListenableBuilder(
                    valueListenable: widget.controller,
                    builder: (context, VideoPlayerValue value, child) {
                      final pos = value.position;
                      final dur = value.duration;
                      final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                      
                      return Column(
                        children: [
                          _TvSeekBar(
                            focusNode: _seekNode,
                            progress: progress,
                            onSeek: (p) => widget.controller.seekTo(dur * p),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(pos), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(_formatDuration(dur), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // ── Control Buttons ──
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TvControlButton(
                      focusNode: _tracksNode,
                      icon: Icons.subtitles_rounded,
                      onPressed: widget.onTogglePanel,
                      label: 'Tracks',
                    ),
                    const SizedBox(width: 20),
                    if (!widget.isLive) ...[
                      _TvControlButton(
                        focusNode: _rewindNode,
                        icon: Icons.replay_10_rounded,
                        onPressed: () => _seekRelative(-10),
                      ),
                      const SizedBox(width: 20),
                    ],
                    _TvControlButton(
                      focusNode: _playPauseNode,
                      icon: widget.controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      isLarge: true,
                      onPressed: () {
                        widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
                        widget.onShowOsd();
                      },
                    ),
                    const SizedBox(width: 20),
                    if (!widget.isLive) ...[
                      _TvControlButton(
                        focusNode: _forwardNode,
                        icon: Icons.forward_10_rounded,
                        onPressed: () => _seekRelative(10),
                      ),
                      const SizedBox(width: 20),
                    ],
                    _TvControlButton(
                      focusNode: _infoNode,
                      icon: Icons.info_outline_rounded,
                      onPressed: widget.onTogglePanel,
                      label: 'Info',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvSeekBar extends StatelessWidget {
  final FocusNode focusNode;
  final double progress;
  final ValueChanged<double> onSeek;

  const _TvSeekBar({required this.focusNode, required this.progress, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onSeek((progress - 0.05).clamp(0.0, 1.0));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          onSeek((progress + 0.05).clamp(0.0, 1.0));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final f = Focus.of(ctx).hasFocus;
        return Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(6),
            border: f ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: f ? Theme.of(context).colorScheme.primary : Colors.white70,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TvControlButton extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLarge;
  final String? label;

  const _TvControlButton({
    required this.focusNode,
    required this.icon,
    required this.onPressed,
    this.isLarge = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 72.0 : 56.0;
    final iconSize = isLarge ? 40.0 : 28.0;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final f = Focus.of(ctx).hasFocus;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: f ? Colors.white : Colors.white10,
                shape: BoxShape.circle,
                boxShadow: f ? [BoxShadow(color: Colors.white24, blurRadius: 15)] : null,
              ),
              child: Icon(icon, color: f ? Colors.black : Colors.white, size: iconSize),
            ),
            if (label != null) ...[
              const SizedBox(height: 8),
              Text(label!, style: TextStyle(color: f ? Colors.white : Colors.white54, fontSize: 12, fontWeight: f ? FontWeight.bold : FontWeight.normal)),
            ],
          ],
        );
      }),
    );
  }
}
