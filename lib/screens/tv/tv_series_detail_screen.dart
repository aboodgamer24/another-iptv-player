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
    final primary = Theme.of(context).colorScheme.primary;
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
                opacity: 0.15,
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
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                child: Row(
                  children: [
                    Focus(
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                             event.logicalKey == LogicalKeyboardKey.enter ||
                             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                          Navigator.pop(context);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(builder: (ctx) {
                        final f = Focus.of(ctx).hasFocus;
                        return GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: f ? Colors.white : Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_back, color: f ? Colors.black : Colors.white, size: 24),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        widget.series.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1.0,
                        ),
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
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: hasFocus ? Colors.white : (isSelected ? primary.withValues(alpha: 0.2) : Colors.white10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasFocus ? Colors.white : (isSelected ? primary : Colors.transparent),
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  'Season $s',
                                  style: TextStyle(
                                    color: hasFocus ? Colors.black : (isSelected ? Colors.white : Colors.white60),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
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
              const SizedBox(height: 24),
              // Episode grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _episodes.length,
                  itemBuilder: (ctx, i) {
                    final ep = _episodes[i];
                    return Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                             event.logicalKey == LogicalKeyboardKey.enter ||
                             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => TvPlayerScreen(
                                contentItem: ep,
                                queue: _episodes,
                                initialIndex: i,
                              ),
                              transitionDuration: Duration.zero,
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
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => TvPlayerScreen(
                                  contentItem: ep,
                                  queue: _episodes,
                                  initialIndex: i,
                                ),
                                transitionDuration: Duration.zero,
                              ),
                            ),
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 150),
                              scale: hasFocus ? 1.05 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasFocus ? primary : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: hasFocus
                                      ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 15)]
                                      : null,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (ep.imagePath.isNotEmpty)
                                      Image.network(
                                        ep.imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                                      )
                                    else
                                      Container(color: Colors.white10, child: const Icon(Icons.play_circle_outline, color: Colors.white12, size: 40)),
                                    
                                    Positioned(
                                      bottom: 0, left: 0, right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [Colors.black87, Colors.transparent],
                                          ),
                                        ),
                                        child: Text(
                                          ep.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (hasFocus)
                                      const Center(
                                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                                      ),
                                  ],
                                ),
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
