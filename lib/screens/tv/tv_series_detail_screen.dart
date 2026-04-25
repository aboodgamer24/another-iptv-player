import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/playlist_content_model.dart';
import 'tv_player_screen.dart';

class TvSeriesDetailScreen extends StatefulWidget {
  final ContentItem series;
  const TvSeriesDetailScreen({super.key, required this.series});

  @override
  State<TvSeriesDetailScreen> createState() => _TvSeriesDetailScreenState();
}

class _TvSeriesDetailScreenState extends State<TvSeriesDetailScreen> {
  int _selectedSeason = 1;

  List<ContentItem> get _episodes => (widget.series.episodes ?? [])
      .where((e) => e.season == _selectedSeason)
      .toList();

  @override
  Widget build(BuildContext context) {
    final seasons =
        (widget.series.episodes?.map((e) => e.season ?? 1).toSet().toList() ??
              [1])
          ..sort();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Backdrop
          if (widget.series.imagePath.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.25,
                child: Image.network(
                  widget.series.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                child: Row(
                  children: [
                    Focus(
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.select) {
                          Navigator.pop(context);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      widget.series.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Season tabs
              if (seasons.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: seasons.map((s) {
                      final isSelected = s == _selectedSeason;
                      return Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) setState(() => _selectedSeason = s);
                        },
                        child: Builder(
                          builder: (ctx) {
                            final hasFocus = Focus.of(ctx).hasFocus;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedSeason = s),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected || hasFocus
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                  border: hasFocus
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: Text(
                                  'Season $s',
                                  style: TextStyle(
                                    color: isSelected || hasFocus
                                        ? Colors.white
                                        : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              // Episode grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: _episodes.length,
                  itemBuilder: (ctx, i) {
                    final ep = _episodes[i];
                    return Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.select) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TvPlayerScreen(
                                contentItem: ep,
                                queue: _episodes,
                                initialIndex: i,
                              ),
                            ),
                          );
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(
                        builder: (ctx) {
                          final hasFocus = Focus.of(ctx).hasFocus;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TvPlayerScreen(
                                  contentItem: ep,
                                  queue: _episodes,
                                  initialIndex: i,
                                ),
                              ),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                                border: hasFocus
                                    ? Border.all(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 3,
                                      )
                                    : Border.all(color: Colors.white12, width: 3),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (ep.imagePath.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.network(
                                        ep.imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(color: Colors.black),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black87,
                                            Colors.transparent,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(7),
                                          bottomRight: Radius.circular(7),
                                        ),
                                      ),
                                      child: Text(
                                        ep.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
