import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Platforms where MPV property setting is supported.
bool get isMpvSupported =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid);

/// Android supports spline36 but ewa_lanczos is too heavy for most devices.
bool get isHighQualitySupported =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Returns the list of preset keys available on the current platform.
/// Returns empty list on unsupported platforms (iOS, web).
List<String> get availableUpscalePresets {
  if (!isMpvSupported) return [];
  if (isHighQualitySupported) return ['standard', 'enhanced', 'high_quality'];
  // Android: only standard + enhanced (ewa_lanczos is too GPU-heavy)
  return ['standard', 'enhanced'];
}

String upscalePresetLabel(String preset) {
  switch (preset) {
    case 'enhanced':    return 'Enhanced (spline36)';
    case 'high_quality': return 'High Quality (ewa_lanczos)';
    default:            return 'Standard (bilinear)';
  }
}

String upscalePresetDescription(String preset) {
  switch (preset) {
    case 'enhanced':    return 'Recommended — smoother edges, minimal GPU cost';
    case 'high_quality': return 'Best quality — requires a dedicated GPU';
    default:            return 'Default — no processing, works on all hardware';
  }
}

Future<void> applyUpscalePreset(Player player, String preset) async {
  if (!isMpvSupported) return;
  try {
    switch (preset) {
      case 'enhanced':
        await player.setProperty('scale', 'spline36');
        await player.setProperty('cscale', 'spline36');
        await player.setProperty('dscale', 'mitchell');
        await player.setProperty('scale-antiring', '0.6');
        await player.setProperty('sigmoid-upscaling', 'yes');
        break;
      case 'high_quality':
        await player.setProperty('scale', 'ewa_lanczos');
        await player.setProperty('cscale', 'ewa_lanczos');
        await player.setProperty('dscale', 'mitchell');
        await player.setProperty('scale-antiring', '0.7');
        await player.setProperty('sigmoid-upscaling', 'yes');
        await player.setProperty('linear-upscaling', 'yes');
        break;
      default: // 'standard'
        await player.setProperty('scale', 'bilinear');
        await player.setProperty('cscale', 'bilinear');
        await player.setProperty('dscale', 'bilinear');
        await player.setProperty('scale-antiring', '0.0');
        await player.setProperty('sigmoid-upscaling', 'no');
        await player.setProperty('linear-upscaling', 'no');
        break;
    }
  } catch (_) {
    // Silently ignore — platform may not support a specific property
  }
}
