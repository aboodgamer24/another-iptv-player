import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/playlist_content_model.dart';
import '../../repositories/favorites_repository.dart';
import 'tv_player_screen.dart';

class TvLiveTvScreen extends StatefulWidget {
  const TvLiveTvScreen({super.key});
  @override
  State<TvLiveTvScreen> createState() => _TvLiveTvScreenState();
}

class _TvLiveTvScreenState extends State<TvLiveTvScreen> {
  int _catIndex = 0;
  int _chanIndex = 0;
  final FocusScopeNode _catScope = FocusScopeNode();
  final FocusScopeNode _chanScope = FocusScopeNode();
  final ScrollController _catScroll = ScrollController();
  final ScrollController _chanScroll = ScrollController();

  // FocusNode pools — keyed by index, created on demand
  final Map<int, FocusNode> _catNodes = {};
  final Map<int, FocusNode> _chanNodes = {};

  FocusNode _catNode(int i) => _catNodes.putIfAbsent(i, () => FocusNode());
  FocusNode _chanNode(int i) => _chanNodes.putIfAbsent(i, () => FocusNode());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _catScope.requestFocus();
    });
  }

  @override
  void dispose() {
    _catScope.dispose();
    _chanScope.dispose();
    _catScroll.dispose();
    _chanScroll.dispose();
    for (final n in _catNodes.values) {
      n.dispose();
    }
    for (final n in _chanNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _openChannel(ContentItem ch, List<ContentItem> queue, int idx) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => TvPlayerScreen(
        contentItem: ch, queue: queue, initialIndex: idx),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<XtreamCodeHomeController>();
    final categories = ctrl.liveCategories ?? [];
    if (categories.isEmpty) return const SizedBox.shrink();
    final safecat = _catIndex.clamp(0, categories.length - 1);
    final channels = ctrl.getLiveChannelsByCategory(
      categories[safecat].category.categoryId);
    final safechan = channels.isEmpty ? 0 : _chanIndex.clamp(0, channels.length - 1);
    final previewItem = channels.isEmpty ? null : channels[safechan];

    return Row(
      children: [
        // ── CATEGORIES (200px) ──
        FocusScope(
          node: _catScope,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _chanScope.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: 200,
            color: const Color(0xFF0F0F1E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text('Categories',
                    style: TextStyle(
                      color: Colors.white54, fontSize: 11,
                      letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _catScroll,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: categories.length,
                    itemBuilder: (ctx, i) {
                      final cat = categories[i];
                      final isSelected = i == safecat;
                      return Focus(
                        focusNode: _catNode(i),
                        onFocusChange: (has) {
                          if (has) {
                            setState(() { _catIndex = i; _chanIndex = 0; });
                            Scrollable.ensureVisible(_catNode(i).context!,
                              alignment: 0.3,
                              duration: const Duration(milliseconds: 150));
                          }
                        },
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.select ||
                               event.logicalKey == LogicalKeyboardKey.enter ||
                               event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                            setState(() => _catIndex = i);
                            _chanScope.requestFocus();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(builder: (ctx) {
                          final hasFocus = Focus.of(ctx).hasFocus;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: hasFocus
                                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                  : Border.all(color: Colors.transparent, width: 2),
                            ),
                            child: Text(
                              cat.category.categoryName,
                              style: TextStyle(
                                color: hasFocus || isSelected ? Colors.white : Colors.white54,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const VerticalDivider(width: 1, color: Colors.white10),

        // ── CHANNELS (220px) ──
        FocusScope(
          node: _chanScope,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _catScope.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: 220,
            color: const Color(0xFF131326),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    categories.isNotEmpty ? categories[safecat].category.categoryName : '',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _chanScroll,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: channels.length,
                    itemBuilder: (ctx, i) {
                      final ch = channels[i];
                      final isSelected = i == safechan;
                      return Focus(
                        focusNode: _chanNode(i),
                        onFocusChange: (has) {
                          if (has) {
                            setState(() => _chanIndex = i);
                            Scrollable.ensureVisible(_chanNode(i).context!,
                              alignment: 0.3,
                              duration: const Duration(milliseconds: 150));
                          }
                        },
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.select ||
                               event.logicalKey == LogicalKeyboardKey.enter ||
                               event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                            _openChannel(ch, channels, i);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(builder: (ctx) {
                          final hasFocus = Focus.of(ctx).hasFocus;
                          return GestureDetector(
                            onTap: () => _openChannel(ch, channels, i),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: hasFocus
                                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                    : Border.all(color: Colors.transparent, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ch.imagePath.isNotEmpty
                                        ? Image.network(ch.imagePath,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.live_tv, size: 18, color: Colors.white24))
                                        : const Icon(Icons.live_tv, size: 18, color: Colors.white24),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(ch.name,
                                      style: TextStyle(
                                        color: hasFocus || isSelected ? Colors.white : Colors.white60,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const VerticalDivider(width: 1, color: Colors.white10),

        // ── PREVIEW PANEL (remaining width) ──
        Expanded(
          child: _TvLivePreviewPanel(
            item: previewItem,
            channelIndex: safechan,
            totalChannels: channels.length,
            onWatch: previewItem == null
                ? null
                : () => _openChannel(previewItem, channels, safechan),
            onFavorite: previewItem == null ? null : () async {
              final repo = FavoritesRepository();
              await repo.toggleFavorite(previewItem);
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );
  }
}

class _TvLivePreviewPanel extends StatelessWidget {
  final ContentItem? item;
  final int channelIndex;
  final int totalChannels;
  final VoidCallback? onWatch;
  final VoidCallback? onFavorite;

  const _TvLivePreviewPanel({
    required this.item,
    required this.channelIndex,
    required this.totalChannels,
    this.onWatch,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const Center(
        child: Text('Select a channel',
          style: TextStyle(color: Colors.white38, fontSize: 16)),
      );
    }
    return Container(
      color: const Color(0xFF0A0A1A),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Channel logo
          Container(
            width: 160, height: 120,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: item!.imagePath.isNotEmpty
                ? Image.network(item!.imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.live_tv, size: 48, color: Colors.white24))
                : const Icon(Icons.live_tv, size: 48, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          // Channel number badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'CH ${channelIndex + 1} / $totalChannels',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Channel name
          Text(
            item!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 32),
          // Watch button hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Press OK to Watch',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Favorite button
          if (onFavorite != null)
            TextButton.icon(
              onPressed: onFavorite,
              icon: const Icon(Icons.favorite_border, color: Colors.white54, size: 18),
              label: const Text('Add to Favorites',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
