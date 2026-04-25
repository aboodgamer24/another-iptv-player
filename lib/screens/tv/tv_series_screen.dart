import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/tv_utils.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../repositories/favorites_repository.dart';
import '../../repositories/watch_later_repository.dart';
import 'tv_content_grid.dart';
import 'tv_series_detail_screen.dart';

// Sentinel IDs for virtual categories
const _kFavoritesCatId = '__favorites__';
const _kWatchLaterCatId = '__watch_later__';

class TvSeriesScreen extends StatefulWidget {
  const TvSeriesScreen({super.key});
  @override
  State<TvSeriesScreen> createState() => _TvSeriesScreenState();
}

class _TvSeriesScreenState extends State<TvSeriesScreen> {
  String _selectedCatId = '';
  List<ContentItem> _currentItems = [];
  bool _loadingVirtual = false;

  final FocusScopeNode _catScope = FocusScopeNode();
  final FocusScopeNode _gridScope = FocusScopeNode();
  final Map<int, FocusNode> _catNodes = {};
  FocusNode _catNode(int i) => _catNodes.putIfAbsent(i, () => FocusNode());

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
    _gridScope.dispose();
    for (final n in _catNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _selectCategory(String catId, XtreamCodeHomeController ctrl) async {
    if (catId == _selectedCatId) return;
    setState(() {
      _selectedCatId = catId;
      _loadingVirtual = catId == _kFavoritesCatId || catId == _kWatchLaterCatId;
    });

    if (catId == _kFavoritesCatId) {
      final repo = FavoritesRepository();
      final favsData = await repo.getFavoritesByContentType(ContentType.series);
      final List<ContentItem> favs = [];
      for (final f in favsData) {
        final item = await repo.getContentItemFromFavorite(f);
        if (item != null) favs.add(item);
      }
      if (mounted) setState(() { _currentItems = favs; _loadingVirtual = false; });
    } else if (catId == _kWatchLaterCatId) {
      final repo = WatchLaterRepository();
      final itemsData = await repo.getAllWatchLaterItems();
      final List<ContentItem> items = itemsData
          .where((e) => e.contentType == ContentType.series)
          .map((e) => ContentItem(
                e.streamId,
                e.title,
                e.imagePath ?? '',
                e.contentType,
              ))
          .toList();
      if (mounted) setState(() { _currentItems = items; _loadingVirtual = false; });
    } else {
      final realCats = ctrl.seriesCategories;
      final realIndex = realCats.indexWhere((c) => c.category.categoryId == catId);
      if (realIndex != -1) {
        await ctrl.loadItemsForCategory(realCats[realIndex], ContentType.series);
      }
      if (mounted) {
        setState(() {
          _currentItems = ctrl.getSeriesByCategory(catId);
          _loadingVirtual = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<XtreamCodeHomeController>();
    final realCats = ctrl.seriesCategories;

    // Virtual categories prepended
    final virtualCats = [
      (id: _kFavoritesCatId, name: '❤  Favorites'),
      (id: _kWatchLaterCatId, name: '🕐  Watch Later'),
    ];

    // Init default selection
    if (_selectedCatId.isEmpty && realCats.isNotEmpty) {
      _selectedCatId = realCats.first.category.categoryId;
      _currentItems = ctrl.getSeriesByCategory(_selectedCatId);
    }

    final totalCats = virtualCats.length + realCats.length;

    return Row(
      children: [
        // ── CATEGORY LIST ──
        FocusScope(
          node: _catScope,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _gridScope.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              TvNavigation.requestRailFocus(context);
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
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: totalCats,
                    itemBuilder: (ctx, i) {
                      final isVirtual = i < virtualCats.length;
                      final catId = isVirtual
                          ? virtualCats[i].id
                          : realCats[i - virtualCats.length].category.categoryId;
                      final catName = isVirtual
                          ? virtualCats[i].name
                          : realCats[i - virtualCats.length].category.categoryName;
                      final isSelected = catId == _selectedCatId;
                      return Focus(
                        focusNode: _catNode(i),
                        onFocusChange: (has) {
                          if (has) _selectCategory(catId, ctrl);
                        },
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.select ||
                               event.logicalKey == LogicalKeyboardKey.enter)) {
                            _gridScope.requestFocus();
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
                            child: Text(catName,
                              style: TextStyle(
                                color: hasFocus || isSelected ? Colors.white : Colors.white54,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
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

        // ── CONTENT GRID ──
        Expanded(
          child: FocusScope(
            node: _gridScope,
            child: _loadingVirtual
                ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                : _currentItems.isEmpty
                    ? const Center(
                        child: Text('No items', style: TextStyle(color: Colors.white38, fontSize: 16)))
                    : TvContentGrid(
                        sectionKey: 'series_$_selectedCatId',
                        items: _currentItems,
                        crossAxisCount: 5,
                        onSelect: (item, idx, queue) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => TvSeriesDetailScreen(series: item),
                          ));
                        },
                        onEdgeLeft: () => _catScope.requestFocus(),
                      ),
          ),
        ),
      ],
    );
  }
}
