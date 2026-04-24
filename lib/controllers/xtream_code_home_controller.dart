import 'dart:async';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import '../repositories/user_preferences.dart';
import '../models/category_type.dart';
import '../models/live_stream.dart';
import '../models/vod_streams.dart';
import '../models/series.dart';
import '../models/category.dart';

class XtreamCodeHomeController extends ChangeNotifier {
  late PageController _pageController;
  final IptvRepository _repository = AppState.xtreamCodeRepository!;

  int _currentIndex = 0;
  bool _isLoading = false;

  final List<CategoryViewModel> _liveCategories = [];
  final List<CategoryViewModel> _movieCategories = [];
  final List<CategoryViewModel> _seriesCategories = [];
  
  ContentItem? _heroItem;
  List<ContentItem> _recommendations = [];
  Timer? _heroRotationTimer;
  List<ContentItem> _heroPool = []; // full pool to pick from

  // --- Categoriy hidden ---
  final Set<String> _hiddenMovieCategoryIds = {};
  final Set<String> _hiddenSeriesCategoryIds = {};

  // Getters publics
  Set<String> get hiddenMovieCategoryIds => _hiddenMovieCategoryIds;
  Set<String> get hiddenSeriesCategoryIds => _hiddenSeriesCategoryIds;

  // Fonctions toggle
  void toggleMovieCategoryVisibility(String categoryId) {
    if (_hiddenMovieCategoryIds.contains(categoryId)) {
      _hiddenMovieCategoryIds.remove(categoryId);
    } else {
      _hiddenMovieCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  void toggleSeriesCategoryVisibility(String categoryId) {
    if (_hiddenSeriesCategoryIds.contains(categoryId)) {
      _hiddenSeriesCategoryIds.remove(categoryId);
    } else {
      _hiddenSeriesCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  // Getters filtrés
  List<CategoryViewModel> get visibleMovieCategories => _movieCategories
      .where((c) => !_hiddenMovieCategoryIds.contains(c.category.categoryId))
      .toList();

  List<CategoryViewModel> get visibleSeriesCategories => _seriesCategories
      .where((c) => !_hiddenSeriesCategoryIds.contains(c.category.categoryId))
      .toList();

  // Getters
  PageController get pageController => _pageController;

  int get currentIndex => _currentIndex;

  bool get isLoading => _isLoading;

  List<CategoryViewModel>? get liveCategories => _liveCategories;

  List<CategoryViewModel> get movieCategories => _movieCategories;

  List<CategoryViewModel> get seriesCategories => _seriesCategories;

  ContentItem? get heroItem => _heroItem;
  List<ContentItem> get recommendations => _recommendations;

  XtreamCodeHomeController(bool all) {
    _pageController = PageController();
    _loadCategories(all);
  }

  @override
  void dispose() {
    _heroRotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void onNavigationTap(int index) {
    _currentIndex = index;
    notifyListeners();

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void onPageChanged(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  String getPageTitle(BuildContext context) {
    switch (currentIndex) {
      case 0:
        return context.loc.history;
      case 1:
        return context.loc.live_streams;
      case 2:
        return context.loc.movies;
      case 3:
        return context.loc.series_plural;
      case 4:
        return context.loc.settings;
      default:
        return 'Another IPTV Player';
    }
  }


  Future<void> _loadCategories(bool all) async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = AppState.database;
      final playlistId = AppState.currentPlaylist!.id;

      if (all) {
        // Run categories+streams fetches in parallel per type
        await Future.wait([
          _repository.getLiveCategories(forceRefresh: true)
              .then((_) => _repository.getLiveChannelsFromApi()),
          _repository.getVodCategories(forceRefresh: true)
              .then((_) => _repository.getMoviesFromApi()),
          _repository.getSeriesCategories(forceRefresh: true)
              .then((_) => _repository.getSeriesFromApi()),
        ]);
      }

      // ── LOAD FROM DB — parallel bulk fetch ─────────────────────────
      final results = await Future.wait([
        db.getCategoriesByTypeAndPlaylist(playlistId, CategoryType.live),
        db.getCategoriesByTypeAndPlaylist(playlistId, CategoryType.vod),
        db.getCategoriesByTypeAndPlaylist(playlistId, CategoryType.series),
        db.getLiveStreams(playlistId),
        db.getVodStreamsByPlaylistId(playlistId),
        db.getSeriesStreamsByPlaylistId(playlistId),
      ]);

      final allLiveCats = results[0] as List<dynamic>;
      final allVodCats  = results[1] as List<dynamic>;
      final allSerCats  = results[2] as List<dynamic>;
      final allLiveStreams = results[3] as List<dynamic>;
      final allVodStreams  = results[4] as List<dynamic>;
      final allSerStreams  = results[5] as List<dynamic>;

      // ── AUTO-FETCH if DB is empty ──────────────────────────────────
      if (!all && allLiveStreams.isEmpty && allVodStreams.isEmpty && allSerStreams.isEmpty) {
        debugPrint('[XtreamController] DB is empty — triggering parallel content fetch');
        // Re-trigger with 'all: true' set
        await _loadCategories(true);
        return;
      }

      // Group by categoryId in memory
      final liveMap = <String, List<LiveStream>>{};
      for (final s in allLiveStreams) {
        final stream = s as LiveStream;
        liveMap.putIfAbsent(stream.categoryId, () => []).add(stream);
      }
      final vodMap = <String, List<VodStream>>{};
      for (final s in allVodStreams) {
        final stream = s as VodStream;
        vodMap.putIfAbsent(stream.categoryId, () => []).add(stream);
      }
      final serMap = <String, List<SeriesStream>>{};
      for (final s in allSerStreams) {
        final stream = s as SeriesStream;
        if (stream.categoryId == null) continue;
        serMap.putIfAbsent(stream.categoryId!, () => []).add(stream);
      }

      // Load hidden categories once
      final hiddenSet = (await UserPreferences.getHiddenCategories()).toSet();

      _liveCategories.clear();
      _movieCategories.clear();
      _seriesCategories.clear();

      for (final cat in allLiveCats) {
        final streams = liveMap[cat.categoryId] ?? [];
        if (streams.isEmpty) continue;
        if (!all && hiddenSet.contains(cat.categoryId)) continue;
        _liveCategories.add(CategoryViewModel(
          category: cat,
          contentItems: streams.map((x) => ContentItem(
            x.streamId, x.name, x.streamIcon, ContentType.liveStream,
            liveStream: x,
          )).toList(),
        ));
      }

      for (final cat in allVodCats) {
        final streams = vodMap[cat.categoryId] ?? [];
        if (streams.isEmpty) continue;
        if (!all && hiddenSet.contains(cat.categoryId)) continue;
        _movieCategories.add(CategoryViewModel(
          category: cat,
          contentItems: streams.map((x) => ContentItem(
            x.streamId, x.name, x.streamIcon, ContentType.vod,
            containerExtension: x.containerExtension, vodStream: x,
          )).toList(),
        ));
      }

      for (final cat in allSerCats) {
        final streams = serMap[cat.categoryId] ?? [];
        if (streams.isEmpty) continue;
        if (!all && hiddenSet.contains(cat.categoryId)) continue;
        _seriesCategories.add(CategoryViewModel(
          category: cat,
          contentItems: streams.map((x) => ContentItem(
            x.seriesId, x.name, x.cover ?? '', ContentType.series,
            seriesStream: x,
          )).toList(),
        ));
      }

      _generateDashboardContent();
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint(st.toString());
      debugPrint('Veri yüklenemedi: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAllData(BuildContext context) async {
    _liveCategories.clear();
    _movieCategories.clear();
    _seriesCategories.clear();
    _isLoading = true;
    notifyListeners();
    await _loadCategories(true);
  }

  void _generateDashboardContent() {
    final allVodsAndSeries = [
      ..._movieCategories.expand((c) => c.contentItems),
      ..._seriesCategories.expand((c) => c.contentItems),
    ];

    if (allVodsAndSeries.isNotEmpty) {
      _heroPool = List<ContentItem>.from(allVodsAndSeries)..shuffle();
      _heroItem = _heroPool.first;
      _recommendations = _heroPool.take(15).toList();

      // Start the 15-minute rotation timer
      _heroRotationTimer?.cancel();
      _heroRotationTimer = Timer.periodic(
        const Duration(minutes: 15),
        (_) => _rotateHero(),
      );
    }
    notifyListeners();
  }

  void _rotateHero() {
    if (_heroPool.isEmpty) return;
    // Pick a random item that is different from the current one
    ContentItem? next;
    final pool = _heroPool.where((i) => i.id != _heroItem?.id).toList();
    if (pool.isNotEmpty) {
      pool.shuffle();
      next = pool.first;
    } else {
      _heroPool.shuffle();
      next = _heroPool.first;
    }
    _heroItem = next;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  List<ContentItem> getLiveChannelsByCategory(String categoryId) {
    return _liveCategories
        .firstWhere((c) => c.category.categoryId == categoryId,
            orElse: () => CategoryViewModel(
                category: Category(
                    categoryId: '',
                    categoryName: '',
                    parentId: 0,
                    playlistId: '',
                    type: CategoryType.live),
                contentItems: []))
        .contentItems;
  }

  List<ContentItem> getMoviesByCategory(String categoryId) {
    return _movieCategories
        .firstWhere((c) => c.category.categoryId == categoryId,
            orElse: () => CategoryViewModel(
                category: Category(
                    categoryId: '',
                    categoryName: '',
                    parentId: 0,
                    playlistId: '',
                    type: CategoryType.vod),
                contentItems: []))
        .contentItems;
  }

  List<ContentItem> getSeriesByCategory(String categoryId) {
    return _seriesCategories
        .firstWhere((c) => c.category.categoryId == categoryId,
            orElse: () => CategoryViewModel(
                category: Category(
                    categoryId: '',
                    categoryName: '',
                    parentId: 0,
                    playlistId: '',
                    type: CategoryType.series),
                contentItems: []))
        .contentItems;
  }
}
