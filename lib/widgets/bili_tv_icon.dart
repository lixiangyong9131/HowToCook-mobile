import 'package:flutter/material.dart';

/// Simplified Bilibili-style TV mark (two antenna + rounded screen).
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
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Antennae
    final ax = w * 0.32;
    final ay = h * 0.28;
    canvas.drawLine(Offset(w * 0.5, ay), Offset(ax, h * 0.06), stroke);
    canvas.drawLine(Offset(w * 0.5, ay), Offset(w - ax, h * 0.06), stroke);
    canvas.drawCircle(Offset(ax, h * 0.06), w * 0.045, fill);
    canvas.drawCircle(Offset(w - ax, h * 0.06), w * 0.045, fill);

    // TV body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.26, w * 0.76, h * 0.58),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(body, stroke);

    // Smile / play face (two dots + arc) — classic bili vibe
    final eyeY = h * 0.48;
    canvas.drawCircle(Offset(w * 0.35, eyeY), w * 0.045, fill);
    canvas.drawCircle(Offset(w * 0.65, eyeY), w * 0.045, fill);
    final smile = Path()
      ..moveTo(w * 0.34, h * 0.60)
      ..quadraticBezierTo(w * 0.5, h * 0.72, w * 0.66, h * 0.60);
    canvas.drawPath(smile, stroke);

    // Feet
    canvas.drawLine(
      Offset(w * 0.30, h * 0.84),
      Offset(w * 0.22, h * 0.94),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.70, h * 0.84),
      Offset(w * 0.78, h * 0.94),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BiliTvPainter oldDelegate) =>
      oldDelegate.color != color;
}
