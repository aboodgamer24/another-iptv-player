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

  List<ContentItem> get allLiveChannels =>
      liveCategories?.expand((c) => getLiveChannelsByCategory(c.category.categoryId)).toList() ?? [];
  List<ContentItem> get allMovies =>
      movieCategories.expand((c) => getMoviesByCategory(c.category.categoryId)).toList();
  List<ContentItem> get allSeries =>
      seriesCategories.expand((c) => getSeriesByCategory(c.category.categoryId)).toList();

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
      // Only show full-screen loader if we have NO data at all
      if (_liveCategories.isEmpty && _movieCategories.isEmpty && _seriesCategories.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }

      final db = AppState.database;
      final playlistId = AppState.currentPlaylist!.id;

      if (all) {
        // Run categories+streams fetches in parallel per type but don't block fully if we have some data
        unawaited(Future.wait([
          _repository
              .getLiveCategories(forceRefresh: true)
              .then((_) => _repository.getLiveChannelsFromApi())
              .then((_) => _loadCategories(false)),
          _repository
              .getVodCategories(forceRefresh: true)
              .then((_) => _repository.getMoviesFromApi())
              .then((_) => _loadCategories(false)),
          _repository
              .getSeriesCategories(forceRefresh: true)
              .then((_) => _repository.getSeriesFromApi())
              .then((_) => _loadCategories(false)),
        ]));
        // If we were forced to refresh, we still want to show what we currently have in DB
      }

      // ── LOAD FROM DB — Shallow fetch (Categories only first) ──────
      final results = await Future.wait([
        db.getCategoriesByTypeAndPlaylist(playlistId, CategoryType.live),
        db.getCategoriesByTypeAndPlaylist(playlistId, CategoryType.vod),
        db.getCategoriesByTypeAndPlaylist(playlistId, CategoryType.series),
      ]);

      final allLiveCats = results[0] as List<dynamic>;
      final allVodCats = results[1] as List<dynamic>;
      final allSerCats = results[2] as List<dynamic>;

      // ── GET SAMPLES FOR DASHBOARD (Parallel) ─────────────────────
      final samples = await Future.wait([
        db.getRandomVodStreams(playlistId, 15),
        db.getRandomSeriesStreams(playlistId, 15),
        // Also get first category streams for each type to show immediately on home rows
        if (allLiveCats.isNotEmpty)
          db.getLiveStreamsByCategoryId(playlistId, allLiveCats.first.categoryId, top: 20)
        else
          Future.value(<LiveStream>[]),
        if (allVodCats.isNotEmpty)
          db.getVodStreamsByPlaylistId(playlistId) // For now, still load VODs if small, but let's optimize
        else
          Future.value(<VodStream>[]),
      ]);
      // Wait, if VODs are many, getVodStreamsByPlaylistId is still slow. 
      // Let's just get the first category for VOD too.

      // ── AUTO-FETCH if DB is empty ──────────────────────────────────
      if (!all &&
          allLiveCats.isEmpty &&
          allVodCats.isEmpty &&
          allSerCats.isEmpty) {
        debugPrint(
          '[XtreamController] DB is empty — triggering parallel content fetch',
        );
        unawaited(_loadCategories(true));
        return;
      }

      final randomVods = samples[0] as List<VodStream>;
      final randomSeries = samples[1] as List<SeriesStream>;
      final homeLiveStreams = samples[2] as List<LiveStream>;

      // Map streams for the categories we have samples for
      final liveMap = { if (allLiveCats.isNotEmpty) allLiveCats.first.categoryId: homeLiveStreams };
      
      // We will load other categories' streams lazily or when requested

      // Load hidden categories once
      final hiddenSet = (await UserPreferences.getHiddenCategories()).toSet();

      _liveCategories.clear();
      _movieCategories.clear();
      _seriesCategories.clear();

      for (final cat in allLiveCats) {
        final streams = liveMap[cat.categoryId] ?? [];
        if (!all && hiddenSet.contains(cat.categoryId)) continue;
        _liveCategories.add(CategoryViewModel(category: cat, contentItems: _convertToItems(streams, ContentType.liveStream)));
      }

      for (final cat in allVodCats) {
        if (!all && hiddenSet.contains(cat.categoryId)) continue;
        _movieCategories.add(CategoryViewModel(category: cat, contentItems: []));
      }

      for (final cat in allSerCats) {
        if (!all && hiddenSet.contains(cat.categoryId)) continue;
        _seriesCategories.add(CategoryViewModel(category: cat, contentItems: []));
      }

      // Populate hero from random fetch
      _heroPool = [
        ...randomVods.map((x) => ContentItem(x.streamId, x.name, x.streamIcon, ContentType.vod, vodStream: x)),
        ...randomSeries.map((x) => ContentItem(x.seriesId, x.name, x.cover ?? '', ContentType.series, seriesStream: x)),
      ];
      if (_heroPool.isNotEmpty) {
        _heroPool.shuffle();
        _heroItem = _heroPool.first;
        _recommendations = _heroPool.take(15).toList();
      }

      _generateDashboardContent();
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint(st.toString());
      debugPrint('Error loading content: $e');
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
    // Already handled in _loadCategories now for performance
    notifyListeners();
  }

  List<ContentItem> _convertToItems(List<dynamic> streams, ContentType type) {
    return streams.map((x) {
      if (type == ContentType.liveStream) {
        final s = x as LiveStream;
        return ContentItem(s.streamId, s.name, s.streamIcon, type, liveStream: s);
      } else if (type == ContentType.vod) {
        final s = x as VodStream;
        return ContentItem(s.streamId, s.name, s.streamIcon, type, vodStream: s, containerExtension: s.containerExtension);
      } else {
        final s = x as SeriesStream;
        return ContentItem(s.seriesId, s.name, s.cover ?? '', type, seriesStream: s);
      }
    }).toList();
  }

  Future<void> loadItemsForCategory(CategoryViewModel vm, ContentType type) async {
    if (vm.contentItems.isNotEmpty) return;
    final db = AppState.database;
    final playlistId = AppState.currentPlaylist!.id;
    
    List<dynamic> streams;
    if (type == ContentType.liveStream) {
      streams = await db.getLiveStreamsByCategoryId(playlistId, vm.category.categoryId);
    } else if (type == ContentType.vod) {
      streams = await db.getVodStreamsByCategoryAndPlaylistId(categoryId: vm.category.categoryId, playlistId: playlistId);
    } else {
      streams = await db.getSeriesStreamsByCategoryAndPlaylistId(categoryId: vm.category.categoryId, playlistId: playlistId);
    }
    
    vm.contentItems.clear();
    vm.contentItems.addAll(_convertToItems(streams, type));
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
        .firstWhere(
          (c) => c.category.categoryId == categoryId,
          orElse: () => CategoryViewModel(
            category: Category(
              categoryId: '',
              categoryName: '',
              parentId: 0,
              playlistId: '',
              type: CategoryType.live,
            ),
            contentItems: [],
          ),
        )
        .contentItems;
  }

  List<ContentItem> getMoviesByCategory(String categoryId) {
    return _movieCategories
        .firstWhere(
          (c) => c.category.categoryId == categoryId,
          orElse: () => CategoryViewModel(
            category: Category(
              categoryId: '',
              categoryName: '',
              parentId: 0,
              playlistId: '',
              type: CategoryType.vod,
            ),
            contentItems: [],
          ),
        )
        .contentItems;
  }

  List<ContentItem> getSeriesByCategory(String categoryId) {
    return _seriesCategories
        .firstWhere(
          (c) => c.category.categoryId == categoryId,
          orElse: () => CategoryViewModel(
            category: Category(
              categoryId: '',
              categoryName: '',
              parentId: 0,
              playlistId: '',
              type: CategoryType.series,
            ),
            contentItems: [],
          ),
        )
        .contentItems;
  }
}
