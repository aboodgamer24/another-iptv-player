import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../widgets/player_widget.dart';
import '../../services/event_bus.dart';

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

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  bool _osdVisible = false;
  Timer? _osdTimer;
  late ContentItem _currentItem;
  late int _currentIndex;

  // Dedicated, stable FocusNode so KeyboardListener always has keyboard focus
  final FocusNode _keyboardFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentItem = widget.contentItem;
    _currentIndex = widget.initialIndex;
    // Grab focus immediately so remote keys work without tapping first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _osdTimer?.cancel();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _showOsd() {
    setState(() => _osdVisible = true);
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _osdVisible = false);
    });
  }

  void _switchChannel(int direction) {
    final newIndex =
        (_currentIndex + direction).clamp(0, widget.queue.length - 1);
    if (newIndex == _currentIndex) return;
    setState(() {
      _currentIndex = newIndex;
      _currentItem = widget.queue[newIndex];
    });
    EventBus().emit('player_content_item_index_changed', newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        autofocus: true,
        focusNode: _keyboardFocus,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          _showOsd();

          // Back key — exit player
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.browserBack) {
            Navigator.of(context).maybePop();
            return;
          }

          // Channel up/down for live streams (also OK on arrow keys)
          if (_currentItem.contentType == ContentType.liveStream) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.channelUp) {
              _switchChannel(-1);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.channelDown) {
              _switchChannel(1);
            }
          }

          // LEFT/RIGHT for VOD seek — forward to PlayerWidget via EventBus
          if (_currentItem.contentType != ContentType.liveStream) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              EventBus().emit('player_seek_forward', null);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              EventBus().emit('player_seek_backward', null);
            }
          }

          // OK/Select = play/pause
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            EventBus().emit('player_toggle_pause', null);
          }
        },
        child: Stack(
          children: [
            PlayerWidget(
              contentItem: _currentItem,
              queue: widget.queue,
              showControls: true,
              showPersistentSidebar: false,
            ),
            if (_osdVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildOsd(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOsd() {
    return AnimatedOpacity(
      opacity: _osdVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _currentItem.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_currentItem.contentType == ContentType.liveStream)
              Text(
                '${_currentIndex + 1} / ${widget.queue.length}',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
