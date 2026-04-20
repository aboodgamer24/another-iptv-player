import 'package:another_iptv_player/controllers/xtream_code_home_controller.dart';
import 'package:another_iptv_player/services/player_state.dart';
import 'package:another_iptv_player/widgets/player/c4_player_overlay.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/models/content_type.dart';

class VideoWidget extends StatefulWidget {
  final VideoController controller;
  final SubtitleViewConfiguration subtitleViewConfiguration;
  final VoidCallback? onFullscreenOverride;
  final bool isInline;
  final ContentType? contentType;

  const VideoWidget({
    super.key,
    required this.controller,
    required this.subtitleViewConfiguration,
    this.onFullscreenOverride,
    this.isInline = false,
    this.contentType,
  });

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Safely try to get the XtreamCodeHomeController if it exists in the tree
    XtreamCodeHomeController? homeController;
    try {
      homeController = context.read<XtreamCodeHomeController>();
    } catch (_) {
      // No XtreamCodeHomeController in this part of the tree (e.g. M3U playback)
      homeController = null;
    }

    return Stack(
      children: [
        Video(
          controller: widget.controller,
          controls: NoVideoControls,
          resumeUponEnteringForegroundMode: true,
          pauseUponEnteringBackgroundMode: !PlayerState.backgroundPlay,
          subtitleViewConfiguration: widget.subtitleViewConfiguration,
        ),
        C4PlayerOverlay(
          player: widget.controller.player,
          controller: widget.controller,
          homeController: homeController,
          onFullscreenOverride: widget.onFullscreenOverride,
          isInline: widget.isInline,
          contentType: widget.contentType,
        ),
      ],
    );
  }
}

// Backward compatibility wrapper
Widget getVideo(
  BuildContext context,
  VideoController controller,
  SubtitleViewConfiguration subtitleViewConfiguration, {
  VoidCallback? onFullscreenOverride,
  bool isInline = false,
  ContentType? contentType,
}) {
  return VideoWidget(
    controller: controller,
    subtitleViewConfiguration: subtitleViewConfiguration,
    onFullscreenOverride: onFullscreenOverride,
    isInline: isInline,
    contentType: contentType,
  );
}
