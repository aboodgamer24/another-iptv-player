import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/playlist_content_model.dart';
import 'tv_player_screen.dart';

class TvLiveTvScreen extends StatefulWidget {
  const TvLiveTvScreen({super.key});

  @override
  State<TvLiveTvScreen> createState() => _TvLiveTvScreenState();
}

class _TvLiveTvScreenState extends State<TvLiveTvScreen> {
  int _selectedCategoryIndex = 0;
  late FocusScopeNode _categoryScope;
  late FocusScopeNode _channelScope;

  @override
  void initState() {
    super.initState();
    _categoryScope = FocusScopeNode();
    _channelScope = FocusScopeNode();
  }

  @override
  void dispose() {
    _categoryScope.dispose();
    _channelScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<XtreamCodeHomeController>(context);
    final categories = controller.liveCategories ?? [];
    if (categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final selectedCategory = categories[_selectedCategoryIndex];
    final channels = controller.getLiveChannelsByCategory(
      selectedCategory.category.categoryId,
    );

    return Row(
      children: [
        // ── CATEGORY PANEL ──
        FocusScope(
          node: _categoryScope,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _channelScope.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: 240,
            color: const Color(0xFF12122A),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: categories.length,
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isSelected = i == _selectedCategoryIndex;
                return Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      setState(() {
                        _selectedCategoryIndex = i;
                      });
                    }
                  },
                  child: Builder(
                    builder: (ctx) {
                      final hasFocus = Focus.of(ctx).hasFocus;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: hasFocus || isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: hasFocus
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Text(
                          cat.category.categoryName,
                          style: TextStyle(
                            color: hasFocus || isSelected
                                ? Colors.white
                                : Colors.white54,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        // ── CHANNEL GRID ──
        Expanded(
          child: FocusScope(
            node: _channelScope,
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 16 / 9,
              ),
              itemCount: channels.length,
              itemBuilder: (ctx, i) {
                final ch = channels[i];
                return Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                          i % 6 == 0) {
                        _categoryScope.requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                        _openChannel(ch, channels, i);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(
                    builder: (ctx) {
                      final hasFocus = Focus.of(ctx).hasFocus;
                      return GestureDetector(
                        onTap: () => _openChannel(ch, channels, i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E3A),
                            borderRadius: BorderRadius.circular(8),
                            border: hasFocus
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 3,
                                  )
                                : Border.all(color: Colors.white12, width: 3),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (ch.imagePath.isNotEmpty)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.network(
                                      ch.imagePath,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.live_tv,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.live_tv,
                                  color: Colors.white38,
                                  size: 28,
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                                child: Text(
                                  ch.name,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
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
        ),
      ],
    );
  }

  void _openChannel(ContentItem ch, List<ContentItem> queue, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TvPlayerScreen(contentItem: ch, queue: queue, initialIndex: index),
      ),
    );
  }
}
