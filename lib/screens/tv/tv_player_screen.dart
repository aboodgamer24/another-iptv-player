import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';

class TvPlayerScreen extends StatefulWidget {
  final String title;
  final String? streamUrl;

  const TvPlayerScreen({
    super.key,
    required this.title,
    this.streamUrl,
  });

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  
  bool _showControls = true;
  bool _showSidePanel = false;
  int _activeTab = 0; // 0: Info, 1: Channels, 2: Episodes
  Timer? _hideTimer;

  final FocusNode _playPauseNode = FocusNode(debugLabel: 'player-play-pause');
  final FocusNode _rewindNode = FocusNode(debugLabel: 'player-rewind');
  final FocusNode _fastForwardNode = FocusNode(debugLabel: 'player-ff');
  final FocusNode _skipNextNode = FocusNode(debugLabel: 'player-next');
  final FocusNode _skipPrevNode = FocusNode(debugLabel: 'player-prev');
  
  final List<FocusNode> _tabNodes = List.generate(3, (i) => FocusNode(debugLabel: 'player-tab-$i'));
  final FocusNode _browseButtonNode = FocusNode(debugLabel: 'player-browse-btn');
  final FocusNode _subtitleNode = FocusNode(debugLabel: 'player-subtitle');
  final FocusNode _infoCloseNode = FocusNode(debugLabel: 'player-info-close');
  final FocusNode _rootNode = FocusNode(debugLabel: 'player-root');

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);

    if (widget.streamUrl != null) {
      _player.open(Media(widget.streamUrl!));
    }

    _resetHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playPauseNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player.dispose();
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
        debugLabel: 'player-root-focus',
        onFocusChange: (focused) => debugPrint('[Player] Root focus changed: $focused'),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            debugPrint('[Player] Key: ${event.logicalKey.debugName}');
            
            final isExitKey = event.logicalKey == LogicalKeyboardKey.backspace || 
                              event.logicalKey == LogicalKeyboardKey.escape ||
                              event.logicalKey == LogicalKeyboardKey.goBack;

            if (!isExitKey) {
              _onActivity();
            }

            // Only open side panel from root if controls are hidden
            if (event.logicalKey == LogicalKeyboardKey.arrowRight && !_showSidePanel && !_showControls) {
              debugPrint('[Player] ArrowRight (Controls hidden) -> Toggle Side Panel');
              _toggleSidePanel();
              return KeyEventResult.handled;
            }
            
            if (event.logicalKey == LogicalKeyboardKey.arrowUp && !_showControls) {
              debugPrint('[Player] ArrowUp -> Show Controls');
              setState(() => _showControls = true);
              _playPauseNode.requestFocus();
              return KeyEventResult.handled;
            }
            
            if (isExitKey) {
              _handleBack();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 1. VIDEO LAYER
              Positioned.fill(
                child: widget.streamUrl != null
                    ? Video(controller: _controller)
                    : const Center(
                        child: Icon(Icons.play_circle_outline, size: 100, color: Colors.white24),
                      ),
              ),

              // 2. CONTROLS OVERLAY
              _buildControlsOverlay(),

              // 3. SIDE PANEL
              _buildSidePanel(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    debugPrint('[Player] Back pressed. Panel: $_showSidePanel, Controls: $_showControls');
    if (_showSidePanel) {
      _toggleSidePanel();
    } else if (_showControls) {
      setState(() => _showControls = false);
      // When hiding controls, ensure root node is focused to catch the next key
      _rootNode.requestFocus();
    } else {
      debugPrint('[Player] Exiting player via rootNavigator pop');
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Widget _buildControlsOverlay() {
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
          height: 160,
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
          child: Row(
            children: [
              // Title (Left)
              SizedBox(
                width: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text('Live Stream • 1080p', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),

              // Buttons (Center)
              Expanded(
                child: FocusTraversalGroup(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PlayerButton(icon: Icons.skip_previous, focusNode: _skipPrevNode),
                      _PlayerButton(icon: Icons.replay_10, focusNode: _rewindNode),
                      _PlayerButton(icon: Icons.play_arrow_rounded, focusNode: _playPauseNode, isLarge: true),
                      _PlayerButton(icon: Icons.forward_10, focusNode: _fastForwardNode),
                      _PlayerButton(icon: Icons.skip_next, focusNode: _skipNextNode),
                      _PlayerButton(
                        icon: Icons.subtitles,
                        focusNode: _subtitleNode,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                            debugPrint('[Player] Subtitle -> ArrowRight -> Open Side Panel');
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
              const SizedBox(
                width: 150,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '10:45 AM',
                    style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ),
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
                  _TabButton(
                    label: 'Channels',
                    isSelected: _activeTab == 1,
                    focusNode: _tabNodes[1],
                    onFocused: () => setState(() => _activeTab = 1),
                  ),
                  _TabButton(
                    label: 'Episodes',
                    isSelected: _activeTab == 2,
                    focusNode: _tabNodes[2],
                    onFocused: () => setState(() => _activeTab = 2),
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
                    _buildListTab('Channels'),
                    _buildListTab('Episodes'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subtitles', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const _InfoRow(label: 'Selected', value: 'English (Internal)'),
          const _InfoRow(label: 'Format', value: 'SRT / ASS'),
          const SizedBox(height: 24),
          const Text(
            'Customize subtitle appearance in settings for a better viewing experience.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          Focus(
            focusNode: FocusNode(), // New node for this specific button
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
                final isFocused = state.isFocused;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isFocused ? Colors.white : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Close Panel',
                      style: TextStyle(
                        color: Colors.black, // Should be conditional but user wants navigation fix
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

  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const _InfoRow(label: 'Resolution', value: '1920x1080'),
          const _InfoRow(label: 'Codec', value: 'H.264 / AVC'),
          const _InfoRow(label: 'Bitrate', value: '4.5 Mbps'),
          const SizedBox(height: 24),
          const Text(
            'Experience high-quality streaming with low latency and crystal-clear audio.',
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

  Widget _buildListTab(String type) {
    return ListView.builder(
      itemCount: 6, // 5 items + 1 button
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemBuilder: (context, index) {
        if (index < 5) {
          return _SidePanelItem(
            title: '$type ${index + 1}',
            subtitle: 'Subtitle for $type ${index + 1}',
            onPressed: () => debugPrint('Selected $type $index'),
          );
        } else {
          // The button as the last item
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Focus(
              focusNode: _browseButtonNode,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _toggleSidePanel();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FocusableControlBuilder(
                onPressed: () => debugPrint('Browse Categories'),
                builder: (context, state) {
                  final isFocused = state.isFocused || _browseButtonNode.hasFocus;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isFocused ? Colors.white : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Browse Categories',
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
          );
        }
      },
    );
  }
}

class _SidePanelItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  const _SidePanelItem({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FocusableControlBuilder(
        onPressed: onPressed,
        builder: (context, state) {
          final isFocused = state.isFocused;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: isFocused ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: isFocused ? Colors.black : Colors.white24,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isFocused ? Colors.black : Colors.white,
                          fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isFocused ? Colors.black54 : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlayerButton extends StatelessWidget {
  final IconData icon;
  final FocusNode focusNode;
  final bool isLarge;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;

  const _PlayerButton({
    required this.icon,
    required this.focusNode,
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
          onPressed: () => debugPrint('Player Action: $icon'),
          builder: (context, state) {
            final isFocused = state.isFocused || focusNode.hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isLarge ? 64 : 48,
              height: isLarge ? 64 : 48,
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : Colors.white10,
                shape: BoxShape.circle,
                boxShadow: isFocused ? [BoxShadow(color: Colors.white24, blurRadius: 10)] : null,
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
