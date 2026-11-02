import 'package:flutter/material.dart';

/// Bilibili-style mini TV: rounded body, twin antennas, centered ▶ cutout.
///
/// Body fill + stroke use [color] (typically white). The play triangle is a
/// transparent hole so the content behind shows through.
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

    // Solid body fill (white when color is white) — not translucent.
    final bodyFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Body sits a bit lower so antennas fit.
    final bodyRect = Rect.fromLTWH(w * 0.14, h * 0.30, w * 0.72, h * 0.56);
    final body = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(w * 0.16),
    );

    // Play triangle hole (transparent) punched through the body.
    final cx = w * 0.52;
    final cy = h * 0.58;
    final tw = w * 0.22;
    final th = h * 0.22;
    final tri = Path()
      ..moveTo(cx - tw * 0.45, cy - th * 0.55)
      ..lineTo(cx - tw * 0.45, cy + th * 0.55)
      ..lineTo(cx + tw * 0.55, cy)
      ..close();

    final bodyWithHole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(body)
      ..addPath(tri, Offset.zero);

    canvas.drawPath(bodyWithHole, bodyFill);
    canvas.drawRRect(body, stroke);

    // Twin stub antennas.
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
  }

  @override
  bool shouldRepaint(covariant _BiliTvPainter oldDelegate) =>
      oldDelegate.color != color;
}
