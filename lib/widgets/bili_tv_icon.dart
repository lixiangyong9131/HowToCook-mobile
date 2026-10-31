import 'package:flutter/material.dart';

/// Bilibili-style mini TV: rounded body, twin antennas, centered ▶.
/// Matches the in-app overlay mark (no face, no feet).
class BiliTvIcon extends StatelessWidget {
  final double size;
  final Color color;
  const BiliTvIcon({super.key, this.size = 24, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BiliTvPainter(color),
      ),
    );
  }
}

class _BiliTvPainter extends CustomPainter {
  final Color color;
  _BiliTvPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bodyFill = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    // Dark play mark on light/translucent body; same-hue fill when color is dark.
    final playColor =
        color.computeLuminance() > 0.55 ? const Color(0xFF2C2C2C) : color;
    final playFill = Paint()
      ..color = playColor
      ..style = PaintingStyle.fill;

    // Body sits a bit lower so antennas fit.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.30, w * 0.72, h * 0.56),
      Radius.circular(w * 0.16),
    );
    canvas.drawRRect(body, bodyFill);
    canvas.drawRRect(body, stroke);

    // Twin stub antennas (short thick nubs angled outward) — image-2 style.
    final antenna = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.34, h * 0.32),
      Offset(w * 0.22, h * 0.10),
      antenna,
    );
    canvas.drawLine(
      Offset(w * 0.66, h * 0.32),
      Offset(w * 0.78, h * 0.10),
      antenna,
    );

    // Centered play triangle ▶
    final cx = w * 0.52;
    final cy = h * 0.58;
    final tw = w * 0.22;
    final th = h * 0.22;
    final tri = Path()
      ..moveTo(cx - tw * 0.45, cy - th * 0.55)
      ..lineTo(cx - tw * 0.45, cy + th * 0.55)
      ..lineTo(cx + tw * 0.55, cy)
      ..close();
    canvas.drawPath(tri, playFill);
  }

  @override
  bool shouldRepaint(covariant _BiliTvPainter oldDelegate) =>
      oldDelegate.color != color;
}
