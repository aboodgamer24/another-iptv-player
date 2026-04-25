import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages parental controls: PIN lock, keyword-based content filtering,
/// and manual category blocking.
class ParentalControlService {
  static const String _keyPinHash = 'parental_pin_hash';
  static const String _keyPinEnabled = 'parental_pin_enabled';
  static const String _keyFilterKeywords = 'parental_filter_keywords';
  static const String _keyBlockedCategories = 'parental_blocked_categories';

  // Singleton
  static final ParentalControlService _instance =
      ParentalControlService._internal();
  factory ParentalControlService() => _instance;
  ParentalControlService._internal();

  // In-memory cache
  bool? _pinEnabled;
  String? _pinHash;
  List<String>? _keywords;
  List<String>? _blockedCategories;
  bool _unlocked = false;

  /// Whether parental controls are currently active (PIN set & enabled).
  Future<bool> get isEnabled async {
    _pinEnabled ??= await _loadBool(_keyPinEnabled);
    _pinHash ??= await _loadString(_keyPinHash);
    return _pinEnabled == true && _pinHash != null && _pinHash!.isNotEmpty;
  }

  /// Whether the user has entered the correct PIN this session.
  bool get isUnlocked => _unlocked;

  /// Unlock for the current session (after correct PIN entry).
  void unlock() => _unlocked = true;

  /// Lock again (e.g., on app background or explicit re-lock).
  void lock() => _unlocked = false;

  // ─── PIN Management ─────────────────────────────

  Future<void> setupPin(String pin) async {
    final hash = _hashPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, hash);
    await prefs.setBool(_keyPinEnabled, true);
    _pinHash = hash;
    _pinEnabled = true;
  }

  Future<bool> verifyPin(String pin) async {
    final hash = _hashPin(pin);
    _pinHash ??= await _loadString(_keyPinHash);
    if (_pinHash == hash) {
      _unlocked = true;
      return true;
    }
    return false;
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.setBool(_keyPinEnabled, false);
    _pinHash = null;
    _pinEnabled = false;
    _unlocked = false;
  }

  Future<bool> hasPin() async {
    _pinHash ??= await _loadString(_keyPinHash);
    return _pinHash != null && _pinHash!.isNotEmpty;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPinEnabled, enabled);
    _pinEnabled = enabled;
    if (!enabled) _unlocked = false;
  }

  // ─── Keyword Filtering ──────────────────────────

  Future<List<String>> getKeywords() async {
    _keywords ??= await _loadList(_keyFilterKeywords);
    return _keywords ?? [];
  }

  Future<void> addKeyword(String keyword) async {
    final keywords = await getKeywords();
    final lower = keyword.trim().toLowerCase();
    if (lower.isNotEmpty && !keywords.contains(lower)) {
      keywords.add(lower);
      await _saveList(_keyFilterKeywords, keywords);
      _keywords = keywords;
    }
  }

  Future<void> removeKeyword(String keyword) async {
    final keywords = await getKeywords();
    keywords.remove(keyword.trim().toLowerCase());
    await _saveList(_keyFilterKeywords, keywords);
    _keywords = keywords;
  }

  // ─── Category Blocking ──────────────────────────

  Future<List<String>> getBlockedCategories() async {
    _blockedCategories ??= await _loadList(_keyBlockedCategories);
    return _blockedCategories ?? [];
  }

  Future<void> blockCategory(String categoryId) async {
    final blocked = await getBlockedCategories();
    if (!blocked.contains(categoryId)) {
      blocked.add(categoryId);
      await _saveList(_keyBlockedCategories, blocked);
      _blockedCategories = blocked;
    }
  }

  Future<void> unblockCategory(String categoryId) async {
    final blocked = await getBlockedCategories();
    blocked.remove(categoryId);
    await _saveList(_keyBlockedCategories, blocked);
    _blockedCategories = blocked;
  }

  // ─── Content Checking ───────────────────────────

  /// Returns true if the given content should be hidden.
  Future<bool> isContentBlocked({
    String? categoryName,
    String? contentName,
    String? categoryId,
  }) async {
    final enabled = await isEnabled;
    if (!enabled || _unlocked) return false;

    // Check category ID block
    if (categoryId != null) {
      final blocked = await getBlockedCategories();
      if (blocked.contains(categoryId)) return true;
    }

    // Check keyword filter
    final keywords = await getKeywords();
    if (keywords.isEmpty) return false;

    final nameToCheck = '${categoryName ?? ''} ${contentName ?? ''}'
        .toLowerCase();
    for (final keyword in keywords) {
      if (nameToCheck.contains(keyword)) return true;
    }

    return false;
  }

  /// Filter a list of items, removing blocked ones.
  Future<List<T>> filterContent<T>(
    List<T> items, {
    required String Function(T) getName,
    String Function(T)? getCategoryId,
    String Function(T)? getCategoryName,
  }) async {
    final enabled = await isEnabled;
    if (!enabled || _unlocked) return items;

    final keywords = await getKeywords();
    final blocked = await getBlockedCategories();

    if (keywords.isEmpty && blocked.isEmpty) return items;

    return items.where((item) {
      // Category ID block
      if (getCategoryId != null && blocked.contains(getCategoryId(item))) {
        return false;
      }

      // Keyword check
      if (keywords.isNotEmpty) {
        final name =
            '${getCategoryName != null ? getCategoryName(item) : ''} ${getName(item)}'
                .toLowerCase();
        for (final keyword in keywords) {
          if (name.contains(keyword)) return false;
        }
      }

      return true;
    }).toList();
  }

  // ─── Helpers ────────────────────────────────────

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<String?> _loadString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<bool?> _loadBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<List<String>> _loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  Future<void> _saveList(String key, List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, list);
  }
}
