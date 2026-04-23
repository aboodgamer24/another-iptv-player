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
  if (isHighQualitySupported) return ['standard', 'enhanced', 'high_quality', 'ewa_lanczossharp'];
  // Android: only standard + enhanced (ewa_lanczos is too GPU-heavy)
  return ['standard', 'enhanced'];
}

String upscalePresetLabel(String preset) {
  switch (preset) {
    case 'enhanced':         return 'Enhanced (spline36)';
    case 'high_quality':      return 'High Quality (ewa_lanczos)';
    case 'ewa_lanczossharp':  return 'Sharp (Sport/Live)';
    default:                  return 'Standard (bilinear)';
  }
}

String upscalePresetDescription(String preset) {
  switch (preset) {
    case 'enhanced':         return 'Recommended — smoother edges, minimal GPU cost';
    case 'high_quality':      return 'Best quality — requires a dedicated GPU';
    case 'ewa_lanczossharp':  return 'Extra sharpness — ideal for sport and live broadcasts';
    default:                  return 'Default — no processing, works on all hardware';
  }
}

Future<void> applyUpscalePreset(Player player, String preset) async {
  if (!isMpvSupported) return;
  // Clamp preset if requested one is not available on this platform (e.g. synced from desktop to mobile)
  final String effectivePreset = availableUpscalePresets.contains(preset) ? preset : 'standard';

  // Access the underlying NativePlayer to call MPV properties
  final native = player.platform;
  if (native is! NativePlayer) return;

  try {
    switch (effectivePreset) {
      case 'enhanced':
        await native.setProperty('scale', 'spline36');
        await native.setProperty('cscale', 'spline36');
        await native.setProperty('dscale', 'mitchell');
        await native.setProperty('scale-antiring', '0.6');
        await native.setProperty('sigmoid-upscaling', 'yes');
        break;
      case 'high_quality':
        await native.setProperty('scale', 'ewa_lanczos');
        await native.setProperty('cscale', 'ewa_lanczos');
        await native.setProperty('dscale', 'mitchell');
        await native.setProperty('scale-antiring', '0.7');
        await native.setProperty('sigmoid-upscaling', 'yes');
        await native.setProperty('linear-upscaling', 'yes');
        break;
      case 'ewa_lanczossharp':
        await native.setProperty('scale', 'ewa_lanczossharp');
        await native.setProperty('cscale', 'ewa_lanczossharp');
        await native.setProperty('scale-blur', '0.981251');
        break;
      default: // 'standard'
        await native.setProperty('scale', 'bilinear');
        await native.setProperty('cscale', 'bilinear');
        await native.setProperty('dscale', 'bilinear');
        await native.setProperty('scale-antiring', '0.0');
        await native.setProperty('sigmoid-upscaling', 'no');
        await native.setProperty('linear-upscaling', 'no');
        break;
    }
  } catch (_) {
    // Silently ignore — platform may not support a specific property
  }

  // Verify MPV actually applied the scale value
  await Future.delayed(const Duration(milliseconds: 200));
  try {
    final applied = await native.getProperty('scale');
    debugPrint('[Upscaler] Requested: $effectivePreset | MPV applied: $applied');
    if (applied.trim() != effectivePreset.trim()) {
      debugPrint('[Upscaler] WARNING: scale mismatch — upscaler may not be active');
    }
  } catch (e) {
    debugPrint('[Upscaler] Could not verify scale property: $e');
  }
}

Future<void> applyStreamEnhancement(Player player, bool enabled) async {
  if (!isMpvSupported) return;
  final native = player.platform;
  if (native is! NativePlayer) return;

  try {
    if (enabled) {
      if (!Platform.isAndroid) {
        // Deband is too GPU-heavy for 4K on Android — desktop only
        await native.setProperty('deband', 'yes');
        await native.setProperty('deband-iterations', '2');
        await native.setProperty('deband-threshold', '48');
        await native.setProperty('deband-range', '16');
        await native.setProperty('deband-grain', '12');
      } else {
        await native.setProperty('deband', 'no');
      }
      await native.setProperty('video-sharpness', Platform.isAndroid ? '0' : '0.3');
    } else {
      await native.setProperty('deband', 'no');
      await native.setProperty('deband-iterations', '1');
      await native.setProperty('deband-threshold', '48');
      await native.setProperty('deband-range', '16');
      await native.setProperty('deband-grain', '0');
      await native.setProperty('video-sharpness', '0');
    }
  } catch (_) {
    // Silently ignore unsupported properties
  }
}

