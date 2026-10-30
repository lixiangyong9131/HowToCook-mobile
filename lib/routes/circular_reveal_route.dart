import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Interaction 6 — circular clip reveal expanding from [center] (global).
/// Used for page pushes AND bottom-tab content swaps.
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
          reverseTransitionDuration: const Duration(milliseconds: 360),
          opaque: false,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondary, child) {
            return CircularReveal(
              progress: CurvedAnimation(
                parent: animation,
                curve: const Cubic(0.4, 0.0, 0.2, 1.0),
                reverseCurve: Curves.easeInCubic,
              ),
              center: center,
              child: child,
            );
          },
        );

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

/// Clip child with a circle growing from [center] as [progress] goes 0→1.
/// Spec: 0% → ~150% at tapped point, ~450ms, cubic-bezier(0.4,0,0.2,1).
class CircularReveal extends StatelessWidget {
  final Animation<double> progress;
  final Offset center;
  final Widget child;

  const CircularReveal({
    super.key,
    required this.progress,
    required this.center,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final size = MediaQuery.sizeOf(context);
        final maxR = _maxRadius(size, center) * 1.5; // ~150%
        final t = progress.value.clamp(0.0, 1.0);
        return ClipPath(
          clipper: CircleRevealClipper(center: center, radius: maxR * t),
          child: child,
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
    return m;
  }
}

class CircleRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  CircleRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant CircleRevealClipper old) =>
      old.center != center || old.radius != radius;
}
