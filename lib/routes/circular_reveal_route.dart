import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Interaction 6 — circular clip reveal expanding from [center] (global).
/// Slowed + softened to avoid harsh flash (晃眼).
class CircularRevealRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset center;
  final Color? veilColor;

  CircularRevealRoute({
    required this.page,
    required this.center,
    this.veilColor,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondary) => page,
          transitionDuration: const Duration(milliseconds: 820),
          reverseTransitionDuration: const Duration(milliseconds: 560),
          opaque: false,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondary, child) {
            return _CircularReveal(
              animation: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
              center: center,
              veilColor: veilColor ?? const Color(0xFF8B7CFF),
              child: child,
            );
          },
        );

  /// Convenience: open [page] using the tap's global position.
  static Future<T?> open<T>(
    BuildContext context, {
    required Widget page,
    Offset? from,
    Color? veilColor,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    final origin = from ??
        (box != null && box.hasSize
            ? box.localToGlobal(box.size.center(Offset.zero))
            : MediaQuery.sizeOf(context).center(Offset.zero));
    return Navigator.of(context).push(
      CircularRevealRoute<T>(
        page: page,
        center: origin,
        veilColor: veilColor,
      ),
    );
  }
}

class _CircularReveal extends StatelessWidget {
  final Animation<double> animation;
  final Offset center;
  final Color veilColor;
  final Widget child;

  const _CircularReveal({
    required this.animation,
    required this.center,
    required this.veilColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final size = MediaQuery.sizeOf(context);
        final maxR = _maxRadius(size, center);
        final t = animation.value;
        // Soft veil expands first; page follows with overlap + fade.
        final veilT = Curves.easeOut.transform((t / 0.55).clamp(0.0, 1.0));
        final pageT = Curves.easeOutCubic.transform(
          ((t - 0.12) / 0.88).clamp(0.0, 1.0),
        );
        // Opacity ramp — never a harsh near-opaque flash.
        final veilAlpha = (0.55 * (1.0 - pageT * 0.85)).clamp(0.0, 0.55);
        final pageFade = Curves.easeOut.transform(
          ((t - 0.08) / 0.55).clamp(0.0, 1.0),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            if (veilAlpha > 0.02)
              ClipPath(
                clipper: _CircleClipper(center: center, radius: maxR * veilT),
                child: ColoredBox(
                  color: veilColor.withValues(alpha: veilAlpha),
                ),
              ),
            ClipPath(
              clipper: _CircleClipper(center: center, radius: maxR * pageT),
              child: Opacity(
                opacity: pageFade,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  double _maxRadius(Size size, Offset c) {
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var m = 0.0;
    for (final p in corners) {
      m = math.max(m, (p - c).distance);
    }
    return m + 24;
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  _CircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleClipper old) =>
      old.center != center || old.radius != radius;
}
