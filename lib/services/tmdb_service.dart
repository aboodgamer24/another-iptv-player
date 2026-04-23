import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_config.dart';

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  static const String _cacheKeyMovies  = 'tmdb_cache_trending_movies';
  static const String _cacheKeyTv      = 'tmdb_cache_trending_tv';
  static const String _cacheTimeMovies = 'tmdb_cache_time_movies';
  static const String _cacheTimeTv     = 'tmdb_cache_time_tv';
  static const Duration _cacheTtl      = Duration(hours: 6);

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Returns cached movies immediately (if available), then refreshes in background.
  /// If cache is empty, waits for network and caches the result.
  Future<List<Map<String, dynamic>>> getTrendingMovies() async {
    return _getCached(
      cacheKey:    _cacheKeyMovies,
      cacheTimeKey: _cacheTimeMovies,
      fetchFn:     _fetchTrendingMovies,
    );
  }

  /// Returns cached TV shows immediately (if available), then refreshes in background.
  Future<List<Map<String, dynamic>>> getTrendingTv() async {
    return _getCached(
      cacheKey:    _cacheKeyTv,
      cacheTimeKey: _cacheTimeTv,
      fetchFn:     _fetchTrendingTv,
    );
  }

  String getPosterUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  String getBackdropUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/original$path';
  }

  // ─── Cache Logic ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _getCached({
    required String cacheKey,
    required String cacheTimeKey,
    required Future<List<Map<String, dynamic>>> Function() fetchFn,
  }) async {
    if (_isApiKeyMissing) return [];

    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs, cacheKey);
    final isFresh = _isCacheFresh(prefs, cacheTimeKey);

    if (cached.isNotEmpty) {
      // Return cached data immediately
      if (!isFresh) {
        // Stale — refresh in background without blocking UI
        fetchFn().then((fresh) {
          if (fresh.isNotEmpty) _writeCache(prefs, cacheKey, cacheTimeKey, fresh);
        }).catchError((_) {});
      }
      return cached;
    }

    // Cache is empty — must wait for network
    try {
      final fresh = await fetchFn();
      if (fresh.isNotEmpty) _writeCache(prefs, cacheKey, cacheTimeKey, fresh);
      return fresh;
    } catch (_) {
      return [];
    }
  }

  bool get _isApiKeyMissing =>
      AppConfig.tmdbApiKey == 'YOUR_TMDB_API_KEY_HERE' ||
      AppConfig.tmdbApiKey.isEmpty;

  List<Map<String, dynamic>> _readCache(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = json.decode(raw);
      return List<Map<String, dynamic>>.from(decoded as List);
    } catch (_) {
      return [];
    }
  }

  bool _isCacheFresh(SharedPreferences prefs, String timeKey) {
    final savedMs = prefs.getInt(timeKey);
    if (savedMs == null) return false;
    final savedAt = DateTime.fromMillisecondsSinceEpoch(savedMs);
    return DateTime.now().difference(savedAt) < _cacheTtl;
  }

  void _writeCache(
    SharedPreferences prefs,
    String cacheKey,
    String cacheTimeKey,
    List<Map<String, dynamic>> data,
  ) {
    try {
      prefs.setString(cacheKey, json.encode(data));
      prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[TmdbService] Cache write failed: $e');
    }
  }

  // ─── Network Fetchers ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchTrendingMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/movie/week?api_key=${AppConfig.tmdbApiKey}'),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] as List);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchTrendingTv() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/tv/week?api_key=${AppConfig.tmdbApiKey}'),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] as List);
    }
    return [];
  }
}
