import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';

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
  late final Player _player;
  late final VideoController _videoController;

  Timer? _osdTimer;
  Timer? _updateDebounce;
  bool _osdVisible = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late ContentItem _currentItem;
  late int _currentIndex;

  final FocusNode _keyboardFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentItem = widget.contentItem;
    _currentIndex = widget.initialIndex;

    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );

    _videoController = VideoController(_player);

    _initPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocus.requestFocus();
    });
  }

  Future<void> _initPlayer() async {
    // Basic MPV properties for TV performance
    final native = _player.platform;
    if (native is NativePlayer) {
      await native.setProperty('hwdec', 'mediacodec-copy');
      await native.setProperty('cache', 'yes');
      await native.setProperty('demuxer-max-bytes', '32MiB');
    }

    _player.stream.position.listen((pos) {
      _position = pos;
      _scheduleUpdate();
    });

    _player.stream.duration.listen((dur) {
      _duration = dur;
      _scheduleUpdate();
    });

    _player.stream.buffering.listen((buffering) {
      _isBuffering = buffering;
      _scheduleUpdate();
    });

    await _player.open(Media(_currentItem.url));
  }

  @override
  void dispose() {
    _osdTimer?.cancel();
    _updateDebounce?.cancel();
    _player.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_updateDebounce?.isActive ?? false) return;
    _updateDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {});
    });
  }

  void _showOsd() {
    if (mounted) setState(() => _osdVisible = true);
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _osdVisible = false);
    });
  }

  void _switchChannel(int direction) {
    final newIndex = (_currentIndex + direction).clamp(
      0,
      widget.queue.length - 1,
    );
    if (newIndex == _currentIndex) return;
    
    _currentIndex = newIndex;
    _currentItem = widget.queue[newIndex];
    _player.open(Media(_currentItem.url));
    _showOsd();
    _scheduleUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _keyboardFocus,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          _showOsd();

          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.browserBack) {
            Navigator.of(context).maybePop();
            return;
          }

          if (_currentItem.contentType == ContentType.liveStream) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.channelUp) {
              _switchChannel(-1);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.channelDown) {
              _switchChannel(1);
            }
          } else {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _player.seek(_position + const Duration(seconds: 10));
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _player.seek(_position - const Duration(seconds: 10));
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            _player.playOrPause();
          }
        },
        child: Stack(
          children: [
            RepaintBoundary(
              child: Video(
                controller: _videoController,
                controls: NoVideoControls,
              ),
            ),
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white24),
              ),
            if (_osdVisible) _buildOsd(),
          ],
        ),
      ),
    );
  }

  Widget _buildOsd() {
    final isLive = _currentItem.contentType == ContentType.liveStream;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
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
              LinearProgressIndicator(
                value: _duration.inSeconds > 0
                    ? _position.inSeconds / _duration.inSeconds
                    : 0,
                backgroundColor: Colors.white10,
                color: Theme.of(context).colorScheme.primary,
                minHeight: 4,
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    _currentItem.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isLive)
                  Text(
                    'CH ${_currentIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
