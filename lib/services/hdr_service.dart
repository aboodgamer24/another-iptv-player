import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

enum HdrType { none, hdr10, hlg, hdr10plus, dolbyVision }

extension HdrTypeLabel on HdrType {
  String get label => switch (this) {
    HdrType.hdr10       => 'HDR10',
    HdrType.hlg         => 'HLG',
    HdrType.hdr10plus   => 'HDR10+',
    HdrType.dolbyVision => 'DOLBY VISION',
    HdrType.none        => '',
  };
}

class HdrService {
  /// Detects the HDR type of the currently playing stream.
  /// Call this after the player has started playing (e.g. 800ms after play starts).
  /// Returns HdrType.none if the stream is SDR or detection fails.
  ///
  /// This is READ-ONLY — it only observes MPV video params, never sets
  /// any property that affects rendering.
  static Future<HdrType> detectHdrType(Player player) async {
    if (player.platform is! NativePlayer) return HdrType.none;
    final native = player.platform as NativePlayer;

    // Poll until video-params are populated (max 5s, 500ms intervals)
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final primaries = await native.getProperty('video-params/primaries');
        final gamma = await native.getProperty('video-params/gamma');

        debugPrint('[HdrService] poll=$i primaries="$primaries" gamma="$gamma"');

        if (primaries.isEmpty) continue;
        if (!primaries.contains('bt.2020')) return HdrType.none;

        return switch (gamma.toLowerCase().trim()) {
          'pq' => HdrType.hdr10,
          'hlg' => HdrType.hlg,
          'dolbyvision' => HdrType.dolbyVision,
          'dolby-vision' => HdrType.dolbyVision,
          _ => HdrType.none,
        };
      } catch (e) {
        debugPrint('[HdrService] poll=$i error: $e');
      }
    }
    return HdrType.none;
  }
}
