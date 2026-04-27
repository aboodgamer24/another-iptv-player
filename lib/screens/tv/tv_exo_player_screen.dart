import 'dart:async';
import 'package:flutter/material.dart';
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

  const TvExoPlayerScreen({super.key, required this.contentItem});

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

  @override
  void initState() {
    super.initState();
    _watchHistoryService = WatchHistoryService();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final url = widget.contentItem.url;
      if (url.isEmpty) throw Exception('Stream URL is empty');

      _controller = VideoPlayerController.networkUrl(Uri.parse(url));

      await _controller!.initialize();

      // Check Watch History to resume
      if (widget.contentItem.contentType != ContentType.liveStream) {
        final history = await _watchHistoryService.getWatchHistory(
          AppState.currentPlaylist!.id,
          isXtreamCode ? widget.contentItem.id : widget.contentItem.m3uItem?.id ?? widget.contentItem.id,
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
    try {
      await _watchHistoryService.saveWatchHistory(
        WatchHistory(
          playlistId: AppState.currentPlaylist!.id,
          contentType: widget.contentItem.contentType,
          streamId: isXtreamCode ? widget.contentItem.id : widget.contentItem.m3uItem?.id ?? widget.contentItem.id,
          lastWatched: DateTime.now(),
          title: widget.contentItem.name,
          imagePath: widget.contentItem.imagePath,
          totalDuration: _controller!.value.duration,
          watchDuration: _controller!.value.position,
          seriesId: widget.contentItem.seriesStream?.seriesId,
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
          TvExoPlayerOverlay(
            controller: _controller!,
            title: widget.contentItem.name,
            contentType: widget.contentItem.contentType,
            onExit: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
