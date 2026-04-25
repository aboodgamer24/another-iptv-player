import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../repositories/user_preferences.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  String? _token;
  String? _serverUrl;

  Future<void> init() async {
    _serverUrl = await UserPreferences.getSyncServerUrl();
    _token = await UserPreferences.getSyncToken();
  }

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> login(
    String serverUrl,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$serverUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      await _saveSession(serverUrl, data['token'], data['user']);
      return data;
    }
    throw Exception('Login failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> register(
    String serverUrl,
    String email,
    String password,
    String displayName,
  ) async {
    final response = await http.post(
      Uri.parse('$serverUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      await _saveSession(serverUrl, data['token'], data['user']);
      return data;
    }
    throw Exception('Registration failed: ${response.statusCode}');
  }

  Future<void> _saveSession(String serverUrl, String token, Map user) async {
    _serverUrl = serverUrl;
    _token = token;
    await UserPreferences.setSyncServerUrl(serverUrl);
    await UserPreferences.setSyncToken(token);
    await UserPreferences.setSyncUser(user as Map<String, dynamic>);
    await init();
  }

  Future<void> logout() async {
    _token = null;
    _serverUrl = null;
    await UserPreferences.setSyncToken('');
    await UserPreferences.setSyncUser({});
  }

  Future<Map<String, dynamic>?> pullSync() async {
    if (_serverUrl == null || !isLoggedIn) return null;
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/sync'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('[Sync] Pull failed: $e');
      return null;
    }
  }

  Future<void> pushField(String field, dynamic data) async {
    if (_serverUrl == null || !isLoggedIn) return;
    try {
      await http.patch(
        Uri.parse('$_serverUrl/sync/$field'),
        headers: _headers,
        body: json.encode({'data': data}),
      );
      debugPrint('[Sync] Pushed field: $field');
    } catch (e) {
      debugPrint('[Sync] Push $field failed: $e');
    }
  }

  Future<void> pushAll(Map<String, dynamic> data) async {
    if (_serverUrl == null || !isLoggedIn) return;
    try {
      await http.put(
        Uri.parse('$_serverUrl/sync'),
        headers: _headers,
        body: json.encode(data),
      );
      debugPrint('[Sync] Full push complete');
    } catch (e) {
      debugPrint('[Sync] Full push failed: $e');
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    if (_serverUrl == null || !isLoggedIn) return null;
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/sync/me'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
