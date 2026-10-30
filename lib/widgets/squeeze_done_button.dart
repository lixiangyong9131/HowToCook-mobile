import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Interaction 1 — SQUEEZE → circle → TICK → particle BURST (bold / obvious).
class SqueezeDoneButton extends StatefulWidget {
  final String label;
  final VoidCallback? onCompleted;
  final bool resettable;
  final double height;
  final Color color;

  const SqueezeDoneButton({
    super.key,
    this.label = '完成这一步',
    this.onCompleted,
    this.resettable = true,
    this.height = 56,
    this.color = AppTheme.neon,
  });

  @override
  State<SqueezeDoneButton> createState() => SqueezeDoneButtonState();
}

class SqueezeDoneButtonState extends State<SqueezeDoneButton>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _squeeze;
  late final Animation<double> _tick;
  late final Animation<double> _burst;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _squeeze = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.32, curve: Curves.easeInOutCubic),
    );
    _tick = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.28, 0.52, curve: Curves.elasticOut),
    );
    _burst = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> trigger() async {
    if (_done && !widget.resettable) return;
    HapticFeedback.heavyImpact();
    setState(() => _done = true);
    await _ctrl.forward(from: 0);
    widget.onCompleted?.call();
  }

  void reset() {
    _ctrl.reset();
    setState(() => _done = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final squeezeT = _squeeze.value;
        final widthFactor = 1.0 - squeezeT * 0.78;
        final circleBlend = squeezeT;
        final showTick = _tick.value;
        final burstT = _burst.value;

        return SizedBox(
          height: widget.height + 72,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (burstT > 0)
                CustomPaint(
                  size: Size(widget.height * 4.5, widget.height * 4.5),
                  painter: _BurstPainter(
                    progress: burstT,
                    color: widget.color,
                  ),
                ),
              GestureDetector(
                onTap: _done && !widget.resettable ? null : trigger,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 240.0;
                    final w = math.max(widget.height, maxW * widthFactor);
                    return Container(
                      width: w,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(
                          _lerp(28, widget.height / 2, circleBlend),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.55),
                            blurRadius: 22,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: showTick > 0.05
                          ? Opacity(
                              opacity: showTick.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.5 + 0.5 * showTick,
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.navy,
                                  size: widget.height * 0.6,
                                ),
                              ),
                            )
                          : Text(
                              widget.label,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _lerp(num a, num b, double t) => (a + (b - a) * t).toDouble();
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rnd = math.Random(7);
    const n = 28;
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * math.pi * 2 + rnd.nextDouble() * 0.25;
      final dist = 28 + progress * (70 + rnd.nextDouble() * 50);
      final r = (5.0 + rnd.nextDouble() * 6) * (1 - progress * 0.5);
      final p = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final paint = Paint()
        ..color = [
          color,
          AppTheme.coral,
          AppTheme.purple,
          AppTheme.lavender,
          Colors.white,
        ][i % 5]
            .withValues(alpha: (1 - progress * 0.85).clamp(0.0, 1.0));
      if (i % 3 == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: r * 2.2, height: r * 1.1),
            const Radius.circular(4),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(p, r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}
