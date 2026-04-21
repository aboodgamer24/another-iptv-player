import 'package:flutter/material.dart';
import 'dart:io';

/// Returns true only when running on Android.
/// All transition helpers return plain MaterialPageRoute on other platforms.
bool get _isAndroid => Platform.isAndroid;

// ─── Durations ───────────────────────────────────────────────────────────────
const Duration _kEnter  = Duration(milliseconds: 320);
const Duration _kExit   = Duration(milliseconds: 280);

// ─── Curves ──────────────────────────────────────────────────────────────────
const Curve _kCurveIn  = Curves.easeOutCubic;
const Curve _kCurveOut = Curves.easeInCubic;

// ─────────────────────────────────────────────────────────────────────────────
// 1. Shared-axis slide  (primary navigation — most screens)
// ─────────────────────────────────────────────────────────────────────────────

/// Horizontal shared-axis slide + fade.
/// Use for forward navigation (playlist → content, home → detail).
Route<T> slideRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  if (!_isAndroid) {
    return MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: _kEnter,
    reverseTransitionDuration: _kExit,
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: _kCurveIn));

      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.06, 0),
      ).animate(CurvedAnimation(parent: secondaryAnimation, curve: _kCurveOut));

      final fadeIn  = CurvedAnimation(parent: animation, curve: _kCurveIn);
      final fadeOut = Tween<double>(begin: 1, end: 0.85)
          .animate(CurvedAnimation(parent: secondaryAnimation, curve: _kCurveOut));

      return SlideTransition(
        position: slideOut,
        child: FadeTransition(
          opacity: fadeOut,
          child: SlideTransition(
            position: slideIn,
            child: FadeTransition(opacity: fadeIn, child: child),
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Bottom sheet slide-up  (modals, detail panels, settings)
// ─────────────────────────────────────────────────────────────────────────────

/// Slides up from the bottom + fades in.
/// Use for settings, favorites overlay, watch later, account screen.
Route<T> slideUpRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  if (!_isAndroid) {
    return MaterialPageRoute<T>(builder: builder, settings: settings, fullscreenDialog: true);
  }
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: true,
    transitionDuration: _kEnter,
    reverseTransitionDuration: _kExit,
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: _kCurveIn));

      final fade = CurvedAnimation(parent: animation, curve: _kCurveIn);

      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Fade-through  (tab content swaps, welcome → home)
// ─────────────────────────────────────────────────────────────────────────────

/// Pure fade. Use for non-hierarchical transitions (splash → home, tab changes).
Route<T> fadeRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  if (!_isAndroid) {
    return MaterialPageRoute<T>(builder: builder, settings: settings);
  }
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: _kEnter,
    reverseTransitionDuration: _kExit,
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: _kCurveIn),
        child: child,
      );
    },
  );
}
