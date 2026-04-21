import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import '../../../models/content_type.dart';
import '../../../services/event_bus.dart';
import '../../../utils/get_playlist_type.dart';
import '../../../widgets/player_widget.dart';

class LiveStreamScreen extends StatefulWidget {
  final ContentItem content;

  const LiveStreamScreen({super.key, required this.content});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late ContentItem contentItem;
  List<ContentItem> allContents = [];
  bool allContentsLoaded = false;
  int selectedContentItemIndex = 0;
  late StreamSubscription contentItemIndexChangedSubscription;

  @override
  void initState() {
    super.initState();
    contentItem = widget.content;
    _hideSystemUI();
    _initializeQueue();
  }

  Future<void> _initializeQueue() async {
    try {
      if (isXtreamCode) {
        if (widget.content.liveStream == null) {
          // Bare ContentItem from favorites — play solo with no queue
          setState(() {
            allContents = [widget.content];
            selectedContentItemIndex = 0;
            allContentsLoaded = true;
          });
          _setupIndexSubscription();
          return;
        }
        allContents = (await AppState.xtreamCodeRepository!
                .getLiveChannelsByCategoryId(
                  categoryId: widget.content.liveStream!.categoryId,
                ))!
            .map((x) => ContentItem(
                  x.streamId, x.name, x.streamIcon,
                  ContentType.liveStream, liveStream: x,
                ))
            .toList();
      } else {
        if (widget.content.m3uItem == null) {
          setState(() {
            allContents = [widget.content];
            selectedContentItemIndex = 0;
            allContentsLoaded = true;
          });
          _setupIndexSubscription();
          return;
        }
        allContents = (await AppState.m3uRepository!
                .getM3uItemsByCategoryId(
                  categoryId: widget.content.m3uItem!.categoryId!,
                ))!
            .map((x) => ContentItem(
                  x.url, x.name ?? 'NO NAME', x.tvgLogo ?? '',
                  ContentType.liveStream, m3uItem: x,
                ))
            .toList();
      }

      setState(() {
        selectedContentItemIndex = allContents.indexWhere(
          (element) => element.id == widget.content.id,
        );
        if (selectedContentItemIndex == -1) selectedContentItemIndex = 0;
        allContentsLoaded = true;
      });
    } catch (e) {
      debugPrint('[LiveStreamScreen] _initializeQueue error: $e');
      setState(() {
        allContents = [widget.content];
        selectedContentItemIndex = 0;
        allContentsLoaded = true;
      });
    }

    _setupIndexSubscription();
  }

  void _setupIndexSubscription() {
    contentItemIndexChangedSubscription = EventBus()
        .on<int>('player_content_item_index')
        .listen((int index) {
          if (!mounted) return;
          setState(() {
            selectedContentItemIndex = index;
            contentItem = allContents[index];
          });
        });
  }

  @override
  void dispose() {
    contentItemIndexChangedSubscription.cancel();
    _showSystemUI();
    super.dispose();
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!allContentsLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: PlayerWidget(contentItem: contentItem, queue: allContents),
      ),
    );
  }
}
