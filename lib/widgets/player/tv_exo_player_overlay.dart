import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import 'package:another_iptv_player/controllers/xtream_code_home_controller.dart';
import 'package:another_iptv_player/models/content_type.dart';

class TvExoPlayerOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final XtreamCodeHomeController? homeController;
  final ContentType? contentType;
  final String title;
  final VoidCallback onExit;

  const TvExoPlayerOverlay({
    super.key,
    required this.controller,
    this.homeController,
    this.contentType,
    required this.title,
    required this.onExit,
  });

  @override
  State<TvExoPlayerOverlay> createState() => _TvExoPlayerOverlayState();
}

class _TvExoPlayerOverlayState extends State<TvExoPlayerOverlay> {
  bool _showControls = true;
  bool _showSidePanel = false;
  int _activeTab = 0; // 0: Info, 1: Channels, 2: Episodes
  Timer? _hideTimer;
  
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  final FocusNode _playPauseNode = FocusNode(debugLabel: 'exo-play-pause');
  final FocusNode _rewindNode = FocusNode(debugLabel: 'exo-rewind');
  final FocusNode _fastForwardNode = FocusNode(debugLabel: 'exo-ff');
  final FocusNode _skipNextNode = FocusNode(debugLabel: 'exo-next');
  final FocusNode _skipPrevNode = FocusNode(debugLabel: 'exo-prev');
  
  final List<FocusNode> _tabNodes = List.generate(3, (i) => FocusNode(debugLabel: 'exo-tab-$i'));
  final FocusNode _browseButtonNode = FocusNode(debugLabel: 'exo-browse-btn');
  final FocusNode _subtitleNode = FocusNode(debugLabel: 'exo-subtitle');
  final FocusNode _infoCloseNode = FocusNode(debugLabel: 'exo-info-close');
  final FocusNode _rootNode = FocusNode(debugLabel: 'exo-root');

  @override
  void initState() {
    super.initState();
    
    widget.controller.addListener(_videoListener);
    
    _resetHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootNode.requestFocus();
    });
  }
  
  void _videoListener() {
    if (!mounted) return;
    setState(() {
      _position = widget.controller.value.position;
      _duration = widget.controller.value.duration;
      _playing = widget.controller.value.isPlaying;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_videoListener);

    _playPauseNode.dispose();
    _rewindNode.dispose();
    _fastForwardNode.dispose();
    _skipNextNode.dispose();
    _skipPrevNode.dispose();
    for (var n in _tabNodes) {
      n.dispose();
    }
    _browseButtonNode.dispose();
    _subtitleNode.dispose();
    _infoCloseNode.dispose();
    _rootNode.dispose();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (_showControls && !_showSidePanel) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _onActivity() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _playPauseNode.requestFocus();
    }
    _resetHideTimer();
  }

  void _toggleSidePanel() {
    setState(() {
      _showSidePanel = !_showSidePanel;
      if (_showSidePanel) {
        _showControls = true;
        _hideTimer?.cancel();
        _tabNodes[_activeTab].requestFocus();
      } else {
        _resetHideTimer();
        _playPauseNode.requestFocus();
      }
    });
  }

  void _handleBack() {
    if (_showSidePanel) {
      _toggleSidePanel();
    } else if (_showControls) {
      setState(() => _showControls = false);
      _rootNode.requestFocus();
    } else {
      widget.onExit();
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showSidePanel && !_showControls,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Focus(
        focusNode: _rootNode,
        autofocus: true,
        debugLabel: 'exo-overlay-root-focus',
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final isExitKey = event.logicalKey == LogicalKeyboardKey.backspace || 
                              event.logicalKey == LogicalKeyboardKey.escape ||
                              event.logicalKey == LogicalKeyboardKey.goBack;

            if (!isExitKey) {
              _onActivity();
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowRight && !_showSidePanel && !_showControls) {
              _toggleSidePanel();
              return KeyEventResult.handled;
            }
            
            if (event.logicalKey == LogicalKeyboardKey.arrowUp && !_showControls) {
              setState(() => _showControls = true);
              _playPauseNode.requestFocus();
              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.select && !_showControls && !_showSidePanel) {
              _playing ? widget.controller.pause() : widget.controller.play();
              _onActivity();
              return KeyEventResult.handled;
            }
            
            if (isExitKey) {
              _handleBack();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // 1. CONTROLS OVERLAY
            _buildControlsOverlay(),

            // 2. SIDE PANEL
            _buildSidePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final title = widget.title;
    final isLiveStream = widget.contentType == ContentType.liveStream;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      bottom: _showControls ? 0 : -200,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showControls ? 1.0 : 0.0,
        child: Container(
          height: 180,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isLiveStream)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              Row(
                children: [
                  // Title (Left)
                  SizedBox(
                    width: 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(isLiveStream ? 'Live Stream' : 'Video on Demand', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),

                  // Buttons (Center)
                  Expanded(
                    child: FocusTraversalGroup(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isLiveStream)
                            _PlayerButton(
                              icon: Icons.replay_10,
                              focusNode: _rewindNode,
                              onPressed: () => widget.controller.seekTo(_position - const Duration(seconds: 10)),
                            ),
                          _PlayerButton(
                            icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            focusNode: _playPauseNode,
                            isLarge: true,
                            onPressed: () {
                              _playing ? widget.controller.pause() : widget.controller.play();
                            },
                          ),
                          if (!isLiveStream)
                            _PlayerButton(
                              icon: Icons.forward_10,
                              focusNode: _fastForwardNode,
                              onPressed: () => widget.controller.seekTo(_position + const Duration(seconds: 10)),
                            ),
                          _PlayerButton(
                            icon: Icons.info_outline,
                            focusNode: _subtitleNode,
                            onPressed: _toggleSidePanel,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                _toggleSidePanel();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Time (Right)
                  SizedBox(
                    width: 150,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        TimeOfDay.now().format(context),
                        style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      right: _showSidePanel ? 0 : -320,
      top: 0,
      bottom: 0,
      child: Container(
        width: 320,
        color: const Color(0xFF111122),
        child: Column(
          children: [
            // Tabs
            Container(
              padding: const EdgeInsets.only(top: 48, bottom: 16),
              color: const Color(0xFF0D0D1A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TabButton(
                    label: 'Info',
                    isSelected: _activeTab == 0,
                    focusNode: _tabNodes[0],
                    onFocused: () => setState(() => _activeTab = 0),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: IndexedStack(
                  index: _activeTab,
                  children: [
                    _buildInfoTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    final title = widget.title;
    final isLiveStream = widget.contentType == ContentType.liveStream;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _InfoRow(label: 'Type', value: isLiveStream ? 'Live Stream' : 'Video on Demand'),
          const _InfoRow(label: 'Engine', value: 'ExoPlayer (Android)'),
          const SizedBox(height: 24),
          const Text(
            'Powered by standard ExoPlayer for robust playback on Android TV.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          Focus(
            focusNode: _infoCloseNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _toggleSidePanel();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: FocusableControlBuilder(
              onPressed: _toggleSidePanel,
              builder: (context, state) {
                final isFocused = state.isFocused || _infoCloseNode.hasFocus;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isFocused ? Colors.white : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Close Panel',
                      style: TextStyle(
                        color: isFocused ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
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

class _PlayerButton extends StatelessWidget {
  final IconData icon;
  final FocusNode focusNode;
  final bool isLarge;
  final VoidCallback onPressed;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;

  const _PlayerButton({
    required this.icon,
    required this.focusNode,
    required this.onPressed,
    this.isLarge = false,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: onKeyEvent,
        onFocusChange: (focused) {
          // ignore: invalid_use_of_protected_member
          (context as Element).markNeedsBuild();
        },
        child: FocusableControlBuilder(
          onPressed: onPressed,
          builder: (context, state) {
            final isFocused = state.isFocused || focusNode.hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isLarge ? 64 : 48,
              height: isLarge ? 64 : 48,
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : Colors.white10,
                shape: BoxShape.circle,
                boxShadow: isFocused ? [const BoxShadow(color: Colors.white24, blurRadius: 10)] : null,
              ),
              child: Icon(icon, color: isFocused ? Colors.black : Colors.white, size: isLarge ? 32 : 24),
            );
          },
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocused;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onFocused,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) {
        if (focused) onFocused();
        // ignore: invalid_use_of_protected_member
        (context as Element).markNeedsBuild();
      },
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              color: isFocused ? Colors.white10 : Colors.transparent,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isFocused || isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
