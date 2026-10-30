import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Interaction 1 — SQUEEZE → TICK → BURST completion feedback.
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
    this.height = 52,
    this.color = AppTheme.lime,
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
      duration: const Duration(milliseconds: 1100),
    );
    _squeeze = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeInOutCubic),
    );
    _tick = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.28, 0.55, curve: Curves.easeOutBack),
    );
    _burst = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.48, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> trigger() async {
    if (_done && !widget.resettable) return;
    HapticFeedback.mediumImpact();
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
        // Width morphs from full pill → circle.
        final widthFactor = 1.0 - squeezeT * 0.72;
        final circleBlend = squeezeT;
        final showTick = _tick.value;
        final burstT = _burst.value;

        return SizedBox(
          height: widget.height + 40,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (burstT > 0)
                CustomPaint(
                  size: Size(widget.height * 3.2, widget.height * 3.2),
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
                        : 220.0;
                    final w = math.max(
                      widget.height,
                      maxW * widthFactor,
                    );
                    return AnimatedContainer(
                      duration: Duration.zero,
                      width: w,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          widget.color,
                          widget.color,
                          circleBlend,
                        ),
                        borderRadius: BorderRadius.circular(
                          lerpDouble(28, widget.height / 2, circleBlend)!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: showTick > 0.05
                          ? Opacity(
                              opacity: showTick.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.6 + 0.4 * showTick,
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.ink,
                                  size: widget.height * 0.55,
                                ),
                              ),
                            )
                          : Text(
                              widget.label,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
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

  double? lerpDouble(num a, num b, double t) => a + (b - a) * t;
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rnd = math.Random(7);
    final n = 18;
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * math.pi * 2 + rnd.nextDouble() * 0.2;
      final dist = 18 + progress * (36 + rnd.nextDouble() * 28);
      final r = (3.0 + rnd.nextDouble() * 3.5) * (1 - progress * 0.55);
      final p = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final paint = Paint()
        ..color = [
          color,
          AppTheme.orange,
          AppTheme.lavender,
          AppTheme.blue,
          Colors.white,
        ][i % 5]
            .withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      canvas.drawCircle(p, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}
