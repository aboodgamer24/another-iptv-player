import 'dart:async';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/view_state.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import '../repositories/user_preferences.dart';
import '../screens/xtream-codes/xtream_code_data_loader_screen.dart';
import '../database/database.dart';
import '../models/category.dart';
import '../models/category_type.dart';
import '../models/live_stream.dart';
import '../models/vod_streams.dart';
import '../models/series.dart';

class XtreamCodeHomeController extends ChangeNotifier {
  late PageController _pageController;
  final IptvRepository _repository = AppState.xtreamCodeRepository!;
  String? _errorMessage;
  ViewState _viewState = ViewState.idle;

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

  void _setViewState(ViewState state) {
    _viewState = state;
    if (state != ViewState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  Future<void> _loadCategories(bool all) async {
    try {
      final db = AppState.database;
      final playlistId = AppState.currentPlaylist!.id;

      if (all) {
        // ── MANUAL REFRESH: fetch from server, save to DB ──────────────────

        // 1. Fetch all categories from server
        final liveCats = await _repository.getLiveCategories() ?? [];
        final vodCats = await _repository.getVodCategories() ?? [];
        final seriesCats = await _repository.getSeriesCategories() ?? [];

        // 2. Save categories to DB (replace old)
        await db.deleteAllCategoriesByPlaylist(playlistId);
        final allCategories = [
          ...liveCats.map((c) => Category(
            categoryId: c.categoryId,
            categoryName: c.categoryName,
            parentId: int.tryParse(c.parentId ?? '0') ?? 0,
            playlistId: playlistId,
            type: CategoryType.live,
          )),
          ...vodCats.map((c) => Category(
            categoryId: c.categoryId,
            categoryName: c.categoryName,
            parentId: int.tryParse(c.parentId ?? '0') ?? 0,
            playlistId: playlistId,
            type: CategoryType.vod,
          )),
          ...seriesCats.map((c) => Category(
            categoryId: c.categoryId,
            categoryName: c.categoryName,
            parentId: int.tryParse(c.parentId ?? '0') ?? 0,
            playlistId: playlistId,
            type: CategoryType.series,
          )),
        ];
        await db.insertCategories(allCategories);

        // 3. Fetch all streams in parallel and save to DB (replace old)
        await db.deleteLiveStreamsByPlaylistId(playlistId);
        await db.deleteVodStreamsByPlaylistId(playlistId);
        await db.deleteSeriesStreamsByPlaylistId(playlistId);

        final liveResults = await Future.wait(
          liveCats.map((cat) => _repository.getLiveChannelsByCategoryId(
            categoryId: cat.categoryId,
          )),
        );
        final vodResults = await Future.wait(
          vodCats.map((cat) => _repository.getMovies(categoryId: cat.categoryId)),
        );
        final seriesResults = await Future.wait(
          seriesCats.map((cat) => _repository.getSeries(categoryId: cat.categoryId)),
        );

        final allLive = liveResults
            .whereType<List>().expand((x) => x).cast<dynamic>().toList();
        final allVod = vodResults
            .whereType<List>().expand((x) => x).cast<dynamic>().toList();
        final allSeries = seriesResults
            .whereType<List>().expand((x) => x).cast<dynamic>().toList();

        if (allLive.isNotEmpty) {
          await db.insertLiveStreams(allLive.map((x) {
            x.playlistId = playlistId;
            return x as LiveStream;
          }).toList());
        }
        if (allVod.isNotEmpty) {
          await db.insertVodStreams(allVod.map((x) {
            x.playlistId = playlistId;
            return x as VodStream;
          }).toList());
        }
        if (allSeries.isNotEmpty) {
          await db.insertSeriesStreams(allSeries.map((x) {
            x.playlistId = playlistId;
            return x as SeriesStream;
          }).toList());
        }
      }

      // ── LOAD FROM DB (both startup and after refresh) ──────────────────

      final liveCats = await db.getCategoriesByTypeAndPlaylist(
        playlistId, CategoryType.live,
      );
      final vodCats = await db.getCategoriesByTypeAndPlaylist(
        playlistId, CategoryType.vod,
      );
      final seriesCats = await db.getCategoriesByTypeAndPlaylist(
        playlistId, CategoryType.series,
      );

      // Live
      for (final cat in liveCats) {
        final streams = await db.getLiveStreamsByCategoryId(
          playlistId, cat.categoryId,
        );
        if (streams.isEmpty) continue;
        if (!all && await UserPreferences.getHiddenCategory(cat.categoryId)) continue;
        _liveCategories.add(CategoryViewModel(
          category: cat,
          contentItems: streams.map((x) => ContentItem(
            x.streamId, x.name, x.streamIcon, ContentType.liveStream,
            liveStream: x,
          )).toList(),
        ));
      }

      // Movies
      for (final cat in vodCats) {
        final streams = await db.getVodStreamsByCategoryAndPlaylistId(
          categoryId: cat.categoryId, playlistId: playlistId,
        );
        if (streams.isEmpty) continue;
        if (!all && await UserPreferences.getHiddenCategory(cat.categoryId)) continue;
        _movieCategories.add(CategoryViewModel(
          category: cat,
          contentItems: streams.map((x) => ContentItem(
            x.streamId, x.name, x.streamIcon, ContentType.vod,
            containerExtension: x.containerExtension, vodStream: x,
          )).toList(),
        ));
      }

      // Series
      for (final cat in seriesCats) {
        final streams = await db.getSeriesStreamsByCategoryAndPlaylistId(
          categoryId: cat.categoryId, playlistId: playlistId,
        );
        if (streams.isEmpty) continue;
        if (!all && await UserPreferences.getHiddenCategory(cat.categoryId)) continue;
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
      _errorMessage = 'Veri yüklenemedi: $e';
      _isLoading = false;
      _setViewState(ViewState.error);
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
}
