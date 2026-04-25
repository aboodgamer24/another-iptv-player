import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformUtils {
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // NEW — true when running on Android TV / Fire TV
  static bool _isTV = false;

  static bool get isTV => _isTV;

  /// Call once from main() before runApp().
  static Future<void> detectTV() async {
    if (kIsWeb || !Platform.isAndroid) {
      _isTV = false;
      return;
    }
    try {
      const channel = MethodChannel('dev.ogos.anotheriptvplayer/platform');
      final result = await channel.invokeMethod<bool>('isTV');
      _isTV = result ?? false;
    } catch (_) {
      _isTV = false;
    }
  }
}
