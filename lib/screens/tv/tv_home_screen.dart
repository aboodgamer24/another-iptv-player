import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/tv_utils.dart';
import '../../services/app_state.dart';
import '../../models/playlist_model.dart';
import '../../models/playlist_content_model.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/m3u_home_controller.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'home-hero-btn');
  List<FocusNode> _rowFocusNodes = [];

  @override
  void dispose() {
    _heroFocusNode.dispose();
    for (final node in _rowFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _rebuildFocusNodes(int count) {
    if (_rowFocusNodes.length == count) return;
    for (final node in _rowFocusNodes) {
      node.dispose();
    }
    _rowFocusNodes.clear();
    for (int i = 0; i < count; i++) {
      _rowFocusNodes.add(FocusNode(debugLabel: 'home-card-$i'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isXtream = AppState.currentPlaylist?.type == PlaylistType.xtream;

    ContentItem? heroItem;
    List<ContentItem> recommendations = [];

    if (isXtream) {
      final controller = context.watch<XtreamCodeHomeController>();
      heroItem = controller.heroItem;
      recommendations = controller.recommendations;
    } else {
      final controller = context.watch<M3UHomeController>();
      if (controller.m3uItems != null && controller.m3uItems!.isNotEmpty) {
        // Fallback for M3U
        final list = controller.m3uItems!.take(16).map((x) => ContentItem(
          x.url,
          x.name ?? '',
          x.tvgLogo ?? '',
          x.contentType,
          m3uItem: x,
        )).toList();
        if (list.isNotEmpty) heroItem = list.first;
        if (list.length > 1) recommendations = list.skip(1).toList();
      }
    }

    if (heroItem == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _rebuildFocusNodes(recommendations.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (recommendations.isEmpty) {
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO BANNER ──────────────────────────────────────────────
            _HeroBanner(
              focusNode: _heroFocusNode,
              item: heroItem,
              onPlay: () => navigateByContentType(context, heroItem!),
            ),

            const SizedBox(height: 48),

            // ── RECOMMENDATIONS ────────────────────────────────────────
            if (recommendations.isNotEmpty) ...[
              Text(
                context.loc.history, // Just using history/recommendations title
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      final item = recommendations[index];
                      return _HomeCard(
                        item: item,
                        index: index,
                        focusNode: _rowFocusNodes[index],
                        onPlay: () => navigateByContentType(context, item),
                      );
                    },
                  ), // ListView.builder
                ), // FocusTraversalGroup
              ), // SizedBox
            ], // if
          ], // children
        ), // Column
      ), // SingleChildScrollView
      ), // Focus
    ); // Scaffold
  }
}

class _HeroBanner extends StatelessWidget {
  final FocusNode focusNode;
  final ContentItem item;
  final VoidCallback onPlay;

  const _HeroBanner({
    required this.focusNode,
    required this.item,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF111122),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (item.imageUrl.isNotEmpty)
            Opacity(
              opacity: 0.3,
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          
          // Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.transparent],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                if (item.imageUrl.isNotEmpty)
                  Container(
                    width: 140,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.movie, size: 40)),
                    ),
                  ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getSubtitle(),
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Focus(
                        focusNode: focusNode,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
                            onPlay();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: FocusableControlBuilder(
                          autoFocus: true,
                          onPressed: onPlay,
                          builder: (context, state) => AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            decoration: BoxDecoration(
                              color: state.isFocused || focusNode.hasFocus ? Colors.white : primary,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: state.isFocused || focusNode.hasFocus ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: state.isFocused || focusNode.hasFocus
                                  ? [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: state.isFocused || focusNode.hasFocus ? Colors.black : Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.loc.start_watching,
                                  style: TextStyle(
                                    color: state.isFocused || focusNode.hasFocus ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle() {
    if (item.vodStream != null) return 'Movie • ${item.vodStream!.rating.isNotEmpty ? '⭐ ${item.vodStream!.rating}' : ''}';
    if (item.seriesStream != null) return 'Series • ${item.seriesStream!.rating?.isNotEmpty == true ? '⭐ ${item.seriesStream!.rating}' : ''}';
    if (item.liveStream != null) return 'Live TV Channel';
    return 'Featured Content';
  }
}

class _HomeCard extends StatelessWidget {
  final ContentItem item;
  final int index;
  final FocusNode focusNode;
  final VoidCallback onPlay;

  const _HomeCard({
    required this.item,
    required this.index,
    required this.focusNode,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select) {
              onPlay();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index == 0) {
              Actions.maybeInvoke(context, const MoveToRailIntent());
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: FocusableControlBuilder(
          onPressed: onPlay,
          builder: (context, state) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 140,
            transform: (state.isFocused || focusNode.hasFocus)
              ? (Matrix4.identity()..scale(1.05, 1.05, 1.0))
              : Matrix4.identity(),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.isFocused || focusNode.hasFocus ? Colors.white : Colors.white10,
                width: 2,
              ),
              boxShadow: state.isFocused || focusNode.hasFocus
                  ? [BoxShadow(color: primary.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.movie, color: Colors.white24, size: 40)),
                    )
                  else
                    const Center(child: Icon(Icons.movie, color: Colors.white24, size: 40)),
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    height: 50,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8, right: 8, bottom: 8,
                    child: Text(
                      item.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
