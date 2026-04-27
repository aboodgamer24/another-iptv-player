import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import '../../widgets/player/tv_exo_player_overlay.dart';

class TvExoPlayerScreen extends StatefulWidget {
  final ContentItem contentItem;
  final List<ContentItem> queue;
  final int currentIndex;
  final String? subtitleUrl;

  const TvExoPlayerScreen({
    super.key,
    required this.contentItem,
    this.queue = const [],
    this.currentIndex = 0,
    this.subtitleUrl,
  });

  @override
  State<TvExoPlayerScreen> createState() => _TvExoPlayerScreenState();
}

class _TvExoPlayerScreenState extends State<TvExoPlayerScreen> {
  VideoPlayerController? _controller;
  late WatchHistoryService _watchHistoryService;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  Timer? _watchHistoryTimer;
  late int _currentIndex;
  bool _showSubtitles = true;
  
  static const _statsChannel = MethodChannel('com.aboodgamer24.iptv/video_stats');
  Map<String, dynamic>? _videoStats;

  Future<void> _loadVideoStats(String url) async {
    try {
      final stats = await _statsChannel.invokeMapMethod<String, dynamic>(
        'getVideoStats', {'url': url},
      );
      if (mounted && stats != null) setState(() => _videoStats = stats);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _watchHistoryService = WatchHistoryService();
    _initPlayerWithItem(widget.queue.isNotEmpty ? widget.queue[_currentIndex] : widget.contentItem);
  }

  Future<void> _onIndexChanged(int index) async {
    if (index < 0 || (widget.queue.isNotEmpty && index >= widget.queue.length)) return;
    _watchHistoryTimer?.cancel();
    await _saveWatchHistory();
    _controller?.removeListener(_playerListener);
    await _controller?.dispose();
    setState(() {
      _currentIndex = index;
      _isLoading = true;
      _hasError = false;
      _videoStats = null;
    });
    await _initPlayerWithItem(widget.queue[index]);
  }

  Future<void> _initPlayerWithItem(ContentItem item) async {
    try {
      final url = item.url;
      if (url.isEmpty) throw Exception('Stream URL is empty');

      _controller = VideoPlayerController.networkUrl(Uri.parse(url));

      await _controller!.initialize();

      if (widget.subtitleUrl != null && widget.subtitleUrl!.isNotEmpty) {
        final response = await http.get(Uri.parse(widget.subtitleUrl!));
        final text = utf8.decode(response.bodyBytes);
        await _controller!.setClosedCaptionFile(
          Future.value(
            widget.subtitleUrl!.endsWith('.vtt')
                ? WebVTTCaptionFile(text)
                : SubRipCaptionFile(text),
          ),
        );
      }

      _loadVideoStats(url);

      // Check Watch History to resume
      if (item.contentType != ContentType.liveStream) {
        final history = await _watchHistoryService.getWatchHistory(
          AppState.currentPlaylist!.id,
          isXtreamCode ? item.id : item.m3uItem?.id ?? item.id,
        );
        if (history != null && history.watchDuration != null) {
          await _controller!.seekTo(history.watchDuration!);
        }
      }

      _controller!.addListener(_playerListener);
      await _controller!.play();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _playerListener() {
    if (_controller == null || !mounted) return;

    if (_controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _controller!.value.errorDescription ?? 'Unknown error';
      });
    }

    // Debounce history saving (every 5 seconds)
    if (_controller!.value.isPlaying && widget.contentItem.contentType != ContentType.liveStream) {
      if (_watchHistoryTimer == null || !_watchHistoryTimer!.isActive) {
        _watchHistoryTimer = Timer(const Duration(seconds: 5), _saveWatchHistory);
      }
    }
  }

  Future<void> _saveWatchHistory() async {
    if (_controller == null || !mounted) return;
    final item = widget.queue.isNotEmpty ? widget.queue[_currentIndex] : widget.contentItem;
    try {
      await _watchHistoryService.saveWatchHistory(
        WatchHistory(
          playlistId: AppState.currentPlaylist!.id,
          contentType: item.contentType,
          streamId: isXtreamCode ? item.id : item.m3uItem?.id ?? item.id,
          lastWatched: DateTime.now(),
          title: item.name,
          imagePath: item.imagePath,
          totalDuration: _controller!.value.duration,
          watchDuration: _controller!.value.position,
          seriesId: item.seriesStream?.seriesId,
        ),
      );
    } catch (e) {
      debugPrint('Error saving watch history in ExoPlayer: $e');
    }
  }

  @override
  void dispose() {
    _watchHistoryTimer?.cancel();
    _saveWatchHistory(); // Save one last time
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing ExoPlayer...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text('Playback Error', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentItem = widget.queue.isNotEmpty ? widget.queue[_currentIndex] : widget.contentItem;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (_showSubtitles)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller!,
              builder: (_, value, __) {
                final text = value.caption.text;
                if (text.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 90),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: Colors.black.withOpacity(0.55),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ),
                );
              },
            ),
          TvExoPlayerOverlay(
            controller: _controller!,
            title: currentItem.name,
            contentType: currentItem.contentType,
            onExit: () => Navigator.of(context).pop(),
            queue: widget.queue,
            currentIndex: _currentIndex,
            onIndexChanged: _onIndexChanged,
            onSubtitleToggle: (enabled) => setState(() => _showSubtitles = enabled),
            videoStats: _videoStats,
          ),
        ],
      ),
    );
  }
}
