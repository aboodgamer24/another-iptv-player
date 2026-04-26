import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import '../../utils/tv_utils.dart';
import 'tv_player_screen.dart';

class TvLiveTvScreen extends StatefulWidget {
  const TvLiveTvScreen({super.key});

  @override
  State<TvLiveTvScreen> createState() => _TvLiveTvScreenState();
}

class _TvLiveTvScreenState extends State<TvLiveTvScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedChannelIndex = 0;

  final List<String> _categories = ['All', 'News', 'Sports', 'Movies', 'Kids', 'Entertainment'];
  final List<String> _channels = List.generate(8, (i) => 'Channel ${i + 1}');

  final FocusNode _categoriesScopeNode = FocusNode(debugLabel: 'live-categories-scope');
  final FocusNode _channelsScopeNode = FocusNode(debugLabel: 'live-channels-scope');
  final FocusNode _previewScopeNode = FocusNode(debugLabel: 'live-preview-scope');

  final List<FocusNode> _categoryNodes = List.generate(6, (i) => FocusNode(debugLabel: 'cat-$i'));
  final List<FocusNode> _channelNodes = List.generate(8, (i) => FocusNode(debugLabel: 'chan-$i'));
  final FocusNode _playButtonNode = FocusNode(debugLabel: 'preview-play-btn');

  @override
  void dispose() {
    _categoriesScopeNode.dispose();
    _channelsScopeNode.dispose();
    _previewScopeNode.dispose();
    for (var n in _categoryNodes) {
      n.dispose();
    }
    for (var n in _channelNodes) {
      n.dispose();
    }
    _playButtonNode.dispose();
    super.dispose();
  }

  void _goToCategories() => _categoryNodes[_selectedCategoryIndex].requestFocus();
  void _goToChannels() => _channelNodes[_selectedChannelIndex].requestFocus();
  void _goToPreview() => _playButtonNode.requestFocus();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // ── PANEL A: CATEGORIES ────────────────────────────────────
          _buildPanelA(),

          // ── PANEL B: CHANNELS ──────────────────────────────────────
          _buildPanelB(),

          // ── PANEL C: PREVIEW ───────────────────────────────────────
          _buildPanelC(),
        ],
      ),
    );
  }

  Widget _buildPanelA() {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
        width: 180,
        color: const Color(0xFF0D0D1A),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Categories', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) => _CategoryItem(
                  label: _categories[index],
                  isSelected: _selectedCategoryIndex == index,
                  focusNode: _categoryNodes[index],
                  onFocused: () {
                    debugPrint('[LiveTV] Category $index focused');
                    setState(() => _selectedCategoryIndex = index);
                  },
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        debugPrint('[LiveTV] Category -> Right -> Panel B');
                        _goToChannels();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        debugPrint('[LiveTV] Category -> Left -> Rail');
                        Actions.maybeInvoke(context, const MoveToRailIntent());
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown && index == _categories.length - 1) {
                        _categoryNodes[0].requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                        _categoryNodes[_categories.length - 1].requestFocus();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelB() {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
        width: 280,
        color: const Color(0xFF111122),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_categories[_selectedCategoryIndex], style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _channels.length,
                itemBuilder: (context, index) => _ChannelItem(
                  name: '${_channels[index]} - ${_categories[_selectedCategoryIndex]}',
                  number: (index + 1 + (_selectedCategoryIndex * 8)).toString().padLeft(3, '0'),
                  focusNode: _channelNodes[index],
                  onFocused: () {
                    debugPrint('[LiveTV] Channel $index focused');
                    setState(() => _selectedChannelIndex = index);
                  },
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        debugPrint('[LiveTV] Channel -> Right -> Panel C');
                        FocusScope.of(context).requestFocus(_playButtonNode);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        debugPrint('[LiveTV] Channel -> Left -> Panel A');
                        _goToCategories();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown && index == _channels.length - 1) {
                        _channelNodes[0].requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                        _channelNodes[_channels.length - 1].requestFocus();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelC() {
    return Expanded(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Center(child: Icon(Icons.tv, size: 64, color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '${_channels[_selectedChannelIndex]} - ${_categories[_selectedCategoryIndex]}',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Channel ${(1 + _selectedChannelIndex + (_selectedCategoryIndex * 8)).toString().padLeft(3, '0')}',
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text(
              'Now Playing: Morning News and Highlights of the Day.',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const Spacer(),
            Center(
              child: Focus(
                focusNode: _playButtonNode,
                canRequestFocus: true,
                onFocusChange: (focused) {
                  debugPrint('[LiveTV] PlayButton focus changed: $focused');
                  setState(() {}); // Force rebuild for visual update
                },
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      debugPrint('[LiveTV] PlayButton -> Left -> Panel B');
                      FocusScope.of(context).requestFocus(_channelNodes[_selectedChannelIndex]);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                      debugPrint('[LiveTV] PlayButton -> Select -> Open Player');
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => TvPlayerScreen(
                            title: _channels[_selectedChannelIndex],
                            streamUrl: null,
                          ),
                        ),
                      );
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusableControlBuilder(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => TvPlayerScreen(
                          title: _channels[_selectedChannelIndex],
                          streamUrl: null, // Mock for now
                        ),
                      ),
                    );
                  },
                  builder: (context, state) {
                    final primary = Theme.of(context).colorScheme.primary;
                    final isFocused = state.isFocused || _playButtonNode.hasFocus;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      transform: Matrix4.identity()..scale(isFocused ? 1.05 : 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      decoration: BoxDecoration(
                        color: isFocused ? Colors.white : primary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: isFocused ? Colors.black : Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Play',
                            style: TextStyle(
                              color: isFocused ? Colors.black : Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _CategoryItem({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onFocused,
    required this.onKeyEvent,
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
      onKeyEvent: onKeyEvent,
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          final primary = Theme.of(context).colorScheme.primary;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white10 : (isSelected ? primary.withValues(alpha: 0.2) : Colors.transparent),
              border: Border(left: BorderSide(color: isSelected ? primary : Colors.transparent, width: 4)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isFocused || isSelected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChannelItem extends StatelessWidget {
  final String name;
  final String number;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _ChannelItem({
    required this.name,
    required this.number,
    required this.focusNode,
    required this.onFocused,
    required this.onKeyEvent,
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
      onKeyEvent: onKeyEvent,
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white10 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isFocused ? Colors.white54 : Colors.transparent),
            ),
            child: Row(
              children: [
                Text(number, style: TextStyle(color: isFocused ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(child: Text(name, style: TextStyle(color: isFocused ? Colors.white : Colors.white70, fontSize: 14))),
              ],
            ),
          );
        },
      ),
    );
  }
}
