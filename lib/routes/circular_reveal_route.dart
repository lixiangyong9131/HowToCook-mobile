import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Interaction 6 — circular clip reveal expanding from [center] (global).
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
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 380),
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
        (box != null
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
        // First half: expanding dark veil; second: reveal page through clip.
        final veilT = (t / 0.45).clamp(0.0, 1.0);
        final pageT = ((t - 0.18) / 0.82).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (veilT < 1)
              ClipPath(
                clipper: _CircleClipper(center: center, radius: maxR * veilT),
                child: ColoredBox(color: veilColor.withValues(alpha: 0.98)),
              ),
            ClipPath(
              clipper: _CircleClipper(center: center, radius: maxR * pageT),
              child: child,
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
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleClipper old) =>
      old.center != center || old.radius != radius;
}
