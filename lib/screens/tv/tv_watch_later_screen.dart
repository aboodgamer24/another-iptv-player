import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/playlist_content_model.dart';
import '../../models/content_type.dart';
import '../../repositories/watch_later_repository.dart';
import 'tv_player_screen.dart';
import 'tv_series_detail_screen.dart';

class TvWatchLaterScreen extends StatefulWidget {
  const TvWatchLaterScreen({super.key});

  @override
  State<TvWatchLaterScreen> createState() => _TvWatchLaterScreenState();
}

class _TvWatchLaterScreenState extends State<TvWatchLaterScreen> {
  bool _loading = true;
  List<ContentItem> _movies = [];
  List<ContentItem> _series = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final repo = WatchLaterRepository();
    final all = await repo.getAllWatchLaterItems();
    
    final List<ContentItem> movieItems = [];
    final List<ContentItem> seriesItems = [];

    for (final e in all) {
      final item = ContentItem(
        e.streamId,
        e.title,
        e.imagePath ?? '',
        e.contentType,
      );
      
      if (item.contentType == ContentType.vod) {
        movieItems.add(item);
      } else if (item.contentType == ContentType.series) {
        seriesItems.add(item);
      }
    }

    if (mounted) {
      setState(() {
        _movies = movieItems;
        _series = seriesItems;
        _loading = false;
      });
    }
  }

  void _onSelect(ContentItem item, int idx, List<ContentItem> queue) {
    if (item.contentType == ContentType.series) {
      Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => TvSeriesDetailScreen(series: item),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ));
    } else {
      Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => TvPlayerScreen(
          contentItem: item, queue: queue, initialIndex: idx),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white54));
    }

    if (_movies.isEmpty && _series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.watch_later_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text('Watch Later is empty',
                style: TextStyle(color: Colors.white38, fontSize: 18)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        if (_movies.isNotEmpty) ...[
          _buildSection('Movies', _movies),
          const SizedBox(height: 40),
        ],
        if (_series.isNotEmpty) ...[
          _buildSection('Series', _series),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  Widget _buildSection(String title, List<ContentItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2 / 3,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            return TvContentGridItem(
              item: items[i],
              onSelect: () => _onSelect(items[i], i, items),
            );
          },
        ),
      ],
    );
  }
}

// Minimal card for the watch later grid
class TvContentGridItem extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onSelect;

  const TvContentGridItem({
    super.key,
    required this.item,
    required this.onSelect,
  });

  @override
  State<TvContentGridItem> createState() => _TvContentGridItemState();
}

class _TvContentGridItemState extends State<TvContentGridItem> {
  final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: hasFocus
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                  : Border.all(color: Colors.transparent, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.item.imagePath.isNotEmpty)
                    Image.network(widget.item.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.movie, size: 48, color: Colors.white12))
                  else
                    const Icon(Icons.movie, size: 48, color: Colors.white12),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Text(widget.item.name,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
