import 'package:flutter/material.dart';
import '../models/home_rail_config.dart';
import '../repositories/user_preferences.dart';

class HomeRailsController extends ChangeNotifier {
  static const List<HomeRailConfig> defaultRails = [
    HomeRailConfig(id: 'recommended', label: 'Recommended for you'),
    HomeRailConfig(id: 'favorites_live', label: 'Favorite Channels'),
    HomeRailConfig(id: 'favorites_movies', label: 'Favorite Movies'),
    HomeRailConfig(id: 'favorites_series', label: 'Favorite Series'),
    HomeRailConfig(id: 'watch_later', label: 'Watch Later'),
    HomeRailConfig(id: 'continue_watching', label: 'Continue Watching'),
    HomeRailConfig(id: 'live_history', label: 'Recently Watched'),
    HomeRailConfig(id: 'trending_movies', label: 'Trending Movies'),
    HomeRailConfig(id: 'trending_series', label: 'Trending Series'),
  ];

  List<HomeRailConfig> _rails = List.from(defaultRails);
  bool _loaded = false;

  HomeRailsController() {
    _init();
  }

  Future<void> _init() async {
    await load();
  }

  List<HomeRailConfig> get rails => _rails;
  List<HomeRailConfig> get visibleRails =>
      _rails.where((r) => r.visible).toList();
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final savedRails = await UserPreferences.getHomeRails();
    if (savedRails.isEmpty) {
      _rails = List.from(defaultRails);
    } else {
      // Merge saved rails with default rails to handle new rails in future updates
      final List<HomeRailConfig> merged = [];

      // Add saved rails that are still in defaultRails
      for (var saved in savedRails) {
        if (defaultRails.any((d) => d.id == saved.id)) {
          // Keep label from default for localization purposes if it changes
          final def = defaultRails.firstWhere((d) => d.id == saved.id);
          merged.add(saved.copyWith(label: def.label));
        }
      }

      // Add any new default rails that weren't in saved list
      for (var def in defaultRails) {
        if (!merged.any((m) => m.id == def.id)) {
          merged.add(def);
        }
      }

      _rails = merged;
    }
    _loaded = true;

    // Safe notify: defer if we are currently in a build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> updateRails(List<HomeRailConfig> newOrder) async {
    _rails = newOrder;
    notifyListeners();
    await UserPreferences.setHomeRails(newOrder);
  }

  Future<void> toggleRail(String id, bool visible) async {
    final index = _rails.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rails[index] = _rails[index].copyWith(visible: visible);
      notifyListeners();
      await UserPreferences.setHomeRails(_rails);
    }
  }
}
