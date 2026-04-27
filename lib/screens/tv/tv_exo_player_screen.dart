import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../services/tv_player_service.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
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
  static const _statsChannel =
      MethodChannel('com.aboodgamer24.iptv/video_stats');

  int _currentIndex = 0;
  bool _subtitlesEnabled = true;
  Map<String, dynamic>? _videoStats;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _launch();
  }

  // ───────────────────────────────────────────────────────────
  // Launch / re-launch native player
  // ───────────────────────────────────────────────────────────

  Future<void> _launch() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Native TV player is only available on Android'),
            ),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }

    final queue =
        widget.queue.isNotEmpty ? widget.queue : [widget.contentItem];
    final idx = _currentIndex.clamp(0, queue.length - 1);

    await TvPlayerService.launchQueue(
      queue: queue
          .map((item) => TvPlayerItem(
                url: item.url,
                title: item.name,
                subtitleUrl: widget.subtitleUrl ?? '',
              ))
          .toList(),
      currentIndex: idx,
      contentType: widget.contentItem.contentType.name,
      position: 0,
    );

    // Fetch video stats for the current item in the background.
    _loadVideoStats(queue[idx].url);

    if (mounted) setState(() => _launched = true);
  }

  Future<void> _loadVideoStats(String url) async {
    try {
      final stats = await _statsChannel
          .invokeMapMethod<String, dynamic>('getVideoStats', {'url': url});
      if (mounted && stats != null) {
        setState(() => _videoStats = Map<String, dynamic>.from(stats));
      }
    } catch (e) {
      // Stats are optional — silently ignore failures.
      debugPrint('[TvExoPlayerScreen] videoStats error: $e');
    }
  }

  // ───────────────────────────────────────────────────────────
  // Index change from side panel
  // ───────────────────────────────────────────────────────────

  Future<void> _onIndexChanged(int index) async {
    final queue =
        widget.queue.isNotEmpty ? widget.queue : [widget.contentItem];
    if (index < 0 || index >= queue.length) return;

    setState(() {
      _currentIndex = index;
      _videoStats = null; // clear stale stats
    });

    // Re-launch native player at the new index.
    await TvPlayerService.launchQueue(
      queue: queue
          .map((item) => TvPlayerItem(
                url: item.url,
                title: item.name,
                subtitleUrl: widget.subtitleUrl ?? '',
              ))
          .toList(),
      currentIndex: index,
      contentType: widget.contentItem.contentType.name,
      position: 0,
    );

    _loadVideoStats(queue[index].url);
  }

  // ───────────────────────────────────────────────────────────
  // Subtitle toggle
  // ───────────────────────────────────────────────────────────

  void _onSubtitleToggle(bool enabled) {
    setState(() => _subtitlesEnabled = enabled);
    // Forward the toggle to the native player via TvPlayerChannel if needed.
    // For now the native side (PlayerViewModel.toggleSubtitles) handles its
    // own state independently. This flag keeps the overlay icon in sync.
  }

  // ───────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final queue =
        widget.queue.isNotEmpty ? widget.queue : [widget.contentItem];
    final currentItem = queue[_currentIndex.clamp(0, queue.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Loading indicator while the native player starts ──
          if (!_launched)
            const Center(child: CircularProgressIndicator()),

          // ── Flutter overlay (side panel, subtitle toggle, info) ──
          // Sits on top of the black scaffold; the actual video renders
          // inside the native TvPlayerActivity launched by TvPlayerService.
          if (_launched)
            TvExoPlayerOverlay(
              title: currentItem.name,
              contentType: widget.contentItem.contentType,
              onExit: () => Navigator.of(context).pop(),
              queue: queue,
              currentIndex: _currentIndex,
              onIndexChanged: _onIndexChanged,
              onSubtitleToggle: _onSubtitleToggle,
              subtitlesEnabled: _subtitlesEnabled,
              videoStats: _videoStats,
            ),
        ],
      ),
    );
  }
}
