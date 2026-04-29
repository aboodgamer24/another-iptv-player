import 'package:flutter/material.dart';

/// C4TV brand logo — uses the real logo asset (assets/logo.png).
/// Renders as a rounded square with optional "C4TV" wordmark beside it.
///
/// Usage:
///   C4tvLogo(size: 36)                   // icon only
///   C4tvLogo(size: 36, showLabel: true)  // icon + "C4TV" wordmark
class C4tvLogo extends StatelessWidget {
  final double size;
  final bool showLabel;

  const C4tvLogo({
    super.key,
    this.size = 32,
    this.showLabel = false,
    // ignore: avoid_unused_constructor_parameters
    Color? color, // kept for API compatibility, logo PNG has color baked in
  });

  @override
  Widget build(BuildContext context) {
    final icon = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!showLabel) return icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 10),
        Text(
          'C4TV',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: size * 0.62,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
