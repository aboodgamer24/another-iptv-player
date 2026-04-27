import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/tv_player_service.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';

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
  @override
  void initState() {
    super.initState();
    _launchNativePlayer();
  }

  Future<void> _launchNativePlayer() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final currentQueue = widget.queue.isNotEmpty ? widget.queue : [widget.contentItem];
        final currentIdx = widget.queue.isNotEmpty ? widget.currentIndex : 0;
        
        await TvPlayerService.launchQueue(
          queue: currentQueue.map((item) => TvPlayerItem(
            url: item.url,
            title: item.name,
            subtitleUrl: widget.subtitleUrl ?? '',
          )).toList(),
          currentIndex: currentIdx,
          contentType: widget.contentItem.contentType.name,
          position: 0,
        );
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      // Fallback or error message for non-android platforms if this screen is reached
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Native player is only available on Android TV')),
          );
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
