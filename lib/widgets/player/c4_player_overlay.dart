import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../services/player_state.dart';

class C4PlayerOverlay extends StatefulWidget {
  final Player player;
  final VideoController controller;

  const C4PlayerOverlay({
    super.key,
    required this.player,
    required this.controller,
  });

  @override
  State<C4PlayerOverlay> createState() => _C4PlayerOverlayState();
}

class _C4PlayerOverlayState extends State<C4PlayerOverlay> {
  bool _isVisible = true;
  Timer? _hideTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late List<StreamSubscription> _subscriptions;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _subscriptions = [
      widget.player.stream.position.listen((p) => setState(() => _position = p)),
      widget.player.stream.duration.listen((d) => setState(() => _duration = d)),
    ];
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
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

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    }
    return "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = _duration.inSeconds == 0; // Simplified check for live

    return GestureDetector(
      onTap: _toggleVisibility,
      behavior: HitTestBehavior.translucent,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (!_isVisible) {
            setState(() {
              _isVisible = true;
              _startHideTimer();
            });
            return KeyEventResult.handled;
          }
           _startHideTimer();
           return KeyEventResult.ignored;
        },
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Stack(
            children: [
              // Bottom Gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Metadata (Top Left)
              Positioned(
                top: 40,
                left: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PlayerState.title ?? 'Unknown Content',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Center Controls
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayerControlBtn(
                      icon: Icons.replay_10_rounded,
                      onPressed: () => widget.player.seek(_position - const Duration(seconds: 10)),
                    ),
                    const SizedBox(width: 40),
                    _PlayerControlBtn(
                      icon: widget.player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      isLarge: true,
                      onPressed: () => widget.player.playOrPause(),
                    ),
                    const SizedBox(width: 40),
                    _PlayerControlBtn(
                      icon: Icons.forward_10_rounded,
                      onPressed: () => widget.player.seek(_position + const Duration(seconds: 10)),
                    ),
                  ],
                ),
              ),

              // Bottom Progress Bar
              Positioned(
                bottom: 60,
                left: 60,
                right: 60,
                child: Column(
                  children: [
                    if (!isLive) ...[
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: theme.colorScheme.primary,
                          overlayColor: theme.colorScheme.primary.withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _position.inSeconds.toDouble(),
                          max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                          onChanged: (val) => widget.player.seek(Duration(seconds: val.toInt())),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70)),
                          Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ] else ...[
                       const Row(
                         mainAxisAlignment: MainAxisAlignment.end,
                         children: [
                           Icon(Icons.circle, color: Colors.red, size: 12),
                           SizedBox(width: 8),
                           Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                         ],
                       ),
                    ],
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

class _PlayerControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLarge;

  const _PlayerControlBtn({
    required this.icon,
    required this.onPressed,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isLarge ? 80 : 60,
              height: isLarge ? 80 : 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: focused ? theme.colorScheme.primary : Colors.white10,
                boxShadow: focused ? [
                  BoxShadow(color: theme.colorScheme.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)
                ] : [],
              ),
              child: Icon(
                icon,
                color: focused ? Colors.white : Colors.white70,
                size: isLarge ? 48 : 32,
              ),
            ),
          );
        }
      ),
    );
  }
}
