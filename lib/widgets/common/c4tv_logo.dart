import 'package:flutter/material.dart';

/// C4TV brand logo — traced from the official icon.
/// The dragon-circle mark renders entirely in SVG via CustomPaint so it
/// scales perfectly at any size with no raster blur.
///
/// Usage:
///   C4tvLogo(size: 36)                 // icon only
///   C4tvLogo(size: 36, showLabel: true) // icon + "C4TV" wordmark beside it
class C4tvLogo extends StatelessWidget {
  final double size;
  final bool showLabel;
  final Color? color;

  const C4tvLogo({
    super.key,
    this.size = 32,
    this.showLabel = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.primary;

    final logo = CustomPaint(
      size: Size(size, size),
      painter: _C4tvLogoPainter(color: resolvedColor),
    );

    if (!showLabel) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        Text(
          'C4TV',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: size * 0.62,
            fontWeight: FontWeight.w800,
            color: resolvedColor,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _C4tvLogoPainter extends CustomPainter {
  final Color color;
  const _C4tvLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // ── Outer circle ring ──────────────────────────────────────────────────
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.085
      ..isAntiAlias = true;

    // Circle: ~80 % of the icon, centred, with a break at the top-right
    // where the dragon head/tail exits.
    final center = Offset(s * 0.5, s * 0.54);
    final radius = s * 0.36;

    // Draw arc from ~20° to ~340° (leaving gap for dragon head)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg(20),   // startAngle
      _deg(300),  // sweepAngle  (360 - 60 gap)
      false,
      ringPaint,
    );

    // ── Dragon body / tail curves (simplified spline shapes) ────────────────
    // These Path segments approximate the ouroboros dragon silhouette.
    final bodyPath = Path();

    // Tail curling at top-left
    bodyPath.moveTo(s * 0.22, s * 0.12);
    bodyPath.cubicTo(
      s * 0.18, s * 0.06,
      s * 0.30, s * 0.02,
      s * 0.38, s * 0.08,
    );
    bodyPath.cubicTo(
      s * 0.44, s * 0.13,
      s * 0.40, s * 0.20,
      s * 0.36, s * 0.22,
    );
    bodyPath.cubicTo(
      s * 0.30, s * 0.24,
      s * 0.24, s * 0.20,
      s * 0.22, s * 0.12,
    );
    bodyPath.close();
    canvas.drawPath(bodyPath, paint);

    // Dragon head (top-right area)
    final headPath = Path();
    headPath.moveTo(s * 0.62, s * 0.08);
    headPath.cubicTo(
      s * 0.72, s * 0.04,
      s * 0.80, s * 0.10,
      s * 0.78, s * 0.20,
    );
    headPath.cubicTo(
      s * 0.76, s * 0.28,
      s * 0.68, s * 0.30,
      s * 0.62, s * 0.26,
    );
    headPath.cubicTo(
      s * 0.56, s * 0.22,
      s * 0.56, s * 0.14,
      s * 0.62, s * 0.08,
    );
    headPath.close();
    canvas.drawPath(headPath, paint);

    // Small horn spike on head
    final hornPath = Path();
    hornPath.moveTo(s * 0.68, s * 0.04);
    hornPath.lineTo(s * 0.72, s * -0.01);
    hornPath.lineTo(s * 0.76, s * 0.05);
    hornPath.close();
    canvas.drawPath(hornPath, paint);

    // Secondary small horn
    final horn2Path = Path();
    horn2Path.moveTo(s * 0.76, s * 0.06);
    horn2Path.lineTo(s * 0.82, s * 0.02);
    horn2Path.lineTo(s * 0.84, s * 0.09);
    horn2Path.close();
    canvas.drawPath(horn2Path, paint);

    // Eye dot
    canvas.drawCircle(
      Offset(s * 0.72, s * 0.17),
      s * 0.028,
      Paint()
        ..color = color.withValues(alpha: 0.0) // hollow
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025,
    );
    // Eye fill (contrasting — use background color approximation)
    canvas.drawCircle(
      Offset(s * 0.72, s * 0.17),
      s * 0.022,
      Paint()..color = color,
    );
  }

  double _deg(double degrees) => degrees * 3.14159265358979 / 180.0;

  @override
  bool shouldRepaint(_C4tvLogoPainter old) => old.color != color;
}
