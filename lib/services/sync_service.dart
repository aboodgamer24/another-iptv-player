import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../repositories/user_preferences.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  Dio? _dio;
  String? _token;
  String? _serverUrl;

  Future<void> init() async {
    _serverUrl = await UserPreferences.getSyncServerUrl();
    _token = await UserPreferences.getSyncToken();
    if (_serverUrl != null && _serverUrl!.isNotEmpty) {
      _dio = Dio(BaseOptions(
        baseUrl: _serverUrl!,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ));
      _dio!.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ));
    }
  }

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<Map<String, dynamic>> login(String serverUrl, String email, String password) async {
    final dio = Dio(BaseOptions(baseUrl: serverUrl));
    final res = await dio.post('/auth/login', data: {'email': email, 'password': password});
    await _saveSession(serverUrl, res.data['token'], res.data['user']);
    return res.data;
  }

  Future<Map<String, dynamic>> register(String serverUrl, String email, String password, String displayName) async {
    final dio = Dio(BaseOptions(baseUrl: serverUrl));
    final res = await dio.post('/auth/register', data: {'email': email, 'password': password, 'displayName': displayName});
    await _saveSession(serverUrl, res.data['token'], res.data['user']);
    return res.data;
  }

  Future<void> _saveSession(String serverUrl, String token, Map user) async {
    _serverUrl = serverUrl;
    _token = token;
    await UserPreferences.setSyncServerUrl(serverUrl);
    await UserPreferences.setSyncToken(token);
    await UserPreferences.setSyncUser(user);
    await init();
  }

  Future<void> logout() async {
    _token = null;
    _serverUrl = null;
    _dio = null;
    await UserPreferences.setSyncToken('');
    await UserPreferences.setSyncUser({});
  }

  // Pull all data from server and return it
  Future<Map<String, dynamic>?> pullSync() async {
    if (_dio == null || !isLoggedIn) return null;
    try {
      final res = await _dio!.get('/sync');
      return res.data;
    } catch (e) {
      debugPrint('[Sync] Pull failed: $e');
      return null;
    }
  }

  // Push a single field to server
  Future<void> pushField(String field, dynamic data) async {
    if (_dio == null || !isLoggedIn) return;
    try {
      await _dio!.patch('/sync/$field', data: {'data': data});
      debugPrint('[Sync] Pushed field: $field');
    } catch (e) {
      debugPrint('[Sync] Push $field failed: $e');
    }
  }

  // Push all data at once
  Future<void> pushAll(Map<String, dynamic> data) async {
    if (_dio == null || !isLoggedIn) return;
    try {
      await _dio!.put('/sync', data: data);
      debugPrint('[Sync] Full push complete');
    } catch (e) {
      debugPrint('[Sync] Full push failed: $e');
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    if (_dio == null || !isLoggedIn) return null;
    try {
      final res = await _dio!.get('/sync/me');
      return res.data;
    } catch (e) {
      return null;
    }
  }
}
