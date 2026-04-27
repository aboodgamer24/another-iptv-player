import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/tv_utils.dart';
import '../../services/app_state.dart';
import '../../models/playlist_model.dart';
import '../../models/content_type.dart';
import '../../models/category_view_model.dart';
import '../../models/playlist_content_model.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/m3u_home_controller.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class TvLiveTvScreen extends StatefulWidget {
  const TvLiveTvScreen({super.key});

  @override
  State<TvLiveTvScreen> createState() => _TvLiveTvScreenState();
}

class _TvLiveTvScreenState extends State<TvLiveTvScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedChannelIndex = 0;
  bool _isLoadingCategory = false;

  final FocusNode _categoriesScopeNode = FocusNode(debugLabel: 'live-categories-scope');
  final FocusNode _channelsScopeNode = FocusNode(debugLabel: 'live-channels-scope');
  final FocusNode _previewScopeNode = FocusNode(debugLabel: 'live-preview-scope');

  final List<FocusNode> _categoryNodes = [];
  List<FocusNode> _channelNodes = [];
  final FocusNode _playButtonNode = FocusNode(debugLabel: 'preview-play-btn');

  // For "All"
  List<ContentItem> _allChannels = [];

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  @override
  void dispose() {
    _categoriesScopeNode.dispose();
    _channelsScopeNode.dispose();
    _previewScopeNode.dispose();
    for (var n in _categoryNodes) {
      n.dispose();
    }
    for (var n in _channelNodes) {
      n.dispose();
    }
    _playButtonNode.dispose();
    super.dispose();
  }

  void _rebuildCategoryNodes(int count) {
    if (_categoryNodes.length == count) return;
    for (var n in _categoryNodes) {
      n.dispose();
    }
    _categoryNodes.clear();
    for (int i = 0; i < count; i++) {
      _categoryNodes.add(FocusNode(debugLabel: 'live-cat-$i'));
    }
  }

  void _rebuildChannelNodes(int count) {
    if (_channelNodes.length == count) return;
    for (var n in _channelNodes) {
      n.dispose();
    }
    _channelNodes.clear();
    for (int i = 0; i < count; i++) {
      _channelNodes.add(FocusNode(debugLabel: 'live-chan-$i'));
    }
  }

  List<CategoryViewModel> _getCategories() {
    final isXtream = AppState.currentPlaylist?.type == PlaylistType.xtream;
    if (isXtream) {
      return context.watch<XtreamCodeHomeController>().liveCategories ?? [];
    } else {
      return context.watch<M3UHomeController>().liveCategories ?? [];
    }
  }

  Future<void> _loadCategoryData() async {
    final isXtream = AppState.currentPlaylist?.type == PlaylistType.xtream;
    if (!isXtream) return; // M3U is already loaded
    final controller = context.read<XtreamCodeHomeController>();
    final categories = controller.liveCategories ?? [];
    if (categories.isEmpty) return;

    if (_selectedCategoryIndex == 0) {
      setState(() {
        _allChannels = categories.expand((c) => c.contentItems).toList();
        _isLoadingCategory = false;
      });
      return;
    }

    final cat = categories[_selectedCategoryIndex - 1];
    if (cat.contentItems.isEmpty) {
      setState(() => _isLoadingCategory = true);
      await controller.loadItemsForCategory(cat, ContentType.liveStream);
      if (mounted) {
        setState(() => _isLoadingCategory = false);
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingCategory = false);
      }
    }
  }

  void _onCategorySelected(int index) {
    if (_selectedCategoryIndex == index) return;
    setState(() {
      _selectedCategoryIndex = index;
      _selectedChannelIndex = 0; // reset
    });
    _loadCategoryData();
  }

  void _goToCategories() {
    if (_categoryNodes.isNotEmpty && _selectedCategoryIndex < _categoryNodes.length) {
      _categoryNodes[_selectedCategoryIndex].requestFocus();
    }
  }

  void _goToChannels() {
    if (_channelNodes.isNotEmpty) {
      _channelNodes[_selectedChannelIndex].requestFocus();
    }
  }

  void _goToPreview() => _playButtonNode.requestFocus();

  List<ContentItem> _getChannelsForCurrentCategory(List<CategoryViewModel> categories) {
    if (_selectedCategoryIndex == 0) return _allChannels;
    if (categories.isEmpty) return [];
    final idx = _selectedCategoryIndex - 1;
    if (idx < 0 || idx >= categories.length) return [];
    return categories[idx].contentItems;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _getCategories();

    if (categories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _rebuildCategoryNodes(categories.length + 1);

    final channels = _getChannelsForCurrentCategory(categories);
    _rebuildChannelNodes(channels.length);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // ── PANEL A: CATEGORIES ────────────────────────────────────
          _buildPanelA(categories),

          // ── PANEL B: CHANNELS ──────────────────────────────────────
          _buildPanelB(channels, categories),

          // ── PANEL C: PREVIEW ───────────────────────────────────────
          _buildPanelC(channels),
        ],
      ),
    );
  }

  Widget _buildPanelA(List<CategoryViewModel> categories) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
        width: 200,
        color: const Color(0xFF0D0D1A),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.loc.categories, style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  final label = index == 0 ? context.loc.all : categories[index - 1].category.categoryName;
                  return _CategoryItem(
                    label: label,
                    isSelected: _selectedCategoryIndex == index,
                    focusNode: _categoryNodes[index],
                    onFocused: () {
                      _onCategorySelected(index);
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _goToChannels();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.goBack) {
                          Actions.maybeInvoke(context, const MoveToRailIntent());
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown && index == categories.length) {
                          _categoryNodes[0].requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                          _categoryNodes[categories.length].requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelB(List<ContentItem> channels, List<CategoryViewModel> categories) {
    final catName = _selectedCategoryIndex == 0 ? context.loc.all : categories[_selectedCategoryIndex - 1].category.categoryName;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
        width: 320,
        color: const Color(0xFF111122),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(catName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            if (_isLoadingCategory)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (channels.isEmpty)
              Expanded(
                child: Center(
                  child: Text(context.loc.not_found_in_category, style: const TextStyle(color: Colors.white54)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final ch = channels[index];
                    return _ChannelItem(
                      name: ch.name,
                      number: (index + 1).toString().padLeft(3, '0'),
                      focusNode: _channelNodes[index],
                      onFocused: () {
                        if (_selectedChannelIndex != index) {
                          setState(() => _selectedChannelIndex = index);
                        }
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                            _goToPreview();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.goBack) {
                            _goToCategories();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelC(List<ContentItem> channels) {
    if (channels.isEmpty || _isLoadingCategory) {
      return const Expanded(
        child: Center(child: Icon(Icons.live_tv_rounded, size: 64, color: Colors.white10)),
      );
    }

    final channel = channels[_selectedChannelIndex];
    final primary = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Stack(
          children: [
            // Ambient Background
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CachedNetworkImage(
                  imageUrl: channel.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: channel.imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(Icons.tv_rounded, size: 40, color: Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel.name,
                              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Channel ${( _selectedChannelIndex + 1 ).toString().padLeft(3, '0')}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Focus(
                    focusNode: _playButtonNode,
                    onFocusChange: (f) {
                      // ignore: invalid_use_of_protected_member
                      (context as Element).markNeedsBuild();
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.goBack) {
                          _goToChannels();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: FocusableControlBuilder(
                      onPressed: () {
                        navigateByContentType(context, channel);
                      },
                      builder: (context, state) {
                        final isFocused = state.isFocused || _playButtonNode.hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          decoration: BoxDecoration(
                            color: isFocused ? primary : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isFocused ? [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: isFocused ? Colors.white : Colors.white70, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                context.loc.start_watching,
                                style: TextStyle(color: isFocused ? Colors.white : Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _CategoryItem({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onFocused,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (f) {
        if (f) onFocused();
        // ignore: invalid_use_of_protected_member
        (context as Element).markNeedsBuild();
      },
      onKeyEvent: onKeyEvent,
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white10 : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFocused || isSelected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChannelItem extends StatelessWidget {
  final String name;
  final String number;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _ChannelItem({
    required this.name,
    required this.number,
    required this.focusNode,
    required this.onFocused,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (f) {
        if (f) onFocused();
        // ignore: invalid_use_of_protected_member
        (context as Element).markNeedsBuild();
      },
      onKeyEvent: onKeyEvent,
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused || focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white10 : Colors.transparent,
            ),
            child: Row(
              children: [
                Text(
                  number,
                  style: TextStyle(color: isFocused ? Theme.of(context).colorScheme.primary : Colors.white38, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isFocused ? Colors.white : Colors.white70, fontSize: 16, fontWeight: isFocused ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
