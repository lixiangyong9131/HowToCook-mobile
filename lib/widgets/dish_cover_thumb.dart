import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Full-bleed header backdrop: top band of the process image (food photo
/// above the text/steps card). Do not over-crop into the step text.
class DishHeaderBackdrop extends StatelessWidget {
  final Recipe recipe;
  final Widget? child;

  const DishHeaderBackdrop({
    super.key,
    required this.recipe,
    this.child,
  });

  static const _ua = {
    'User-Agent': 'HowToCook-mobile/0.6.14',
    'Accept': 'image/jpeg,image/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    final path = ProcessImageService.instance.assetPathFor(recipe);
    final remote = ProcessImageService.instance.remoteUrlFor(recipe);

    Widget? image;
    if (path != null) {
      image = Image.asset(
        path,
        fit: BoxFit.cover,
        // Top of 9:16 card = dish photo; avoid shifting into step text.
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.expand(),
      );
    } else if (remote != null && remote.isNotEmpty) {
      image = Image.network(
        remote,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        headers: _ua,
        errorBuilder: (_, __, ___) => const SizedBox.expand(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppTheme.blackCard),
        if (image != null) image,
        // Scrim so title/icons stay readable over the food photo.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.72),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}


/// List/logo thumb: top-band crop like [DishHeaderBackdrop], then cut an
/// extra ~300px off the bottom of that square band (food only, less card UI).
class DishCoverThumb extends StatelessWidget {
  final Recipe recipe;
  final double size;
  final BorderRadius? borderRadius;

  const DishCoverThumb({
    super.key,
    required this.recipe,
    this.size = 52,
    this.borderRadius,
  });

  /// Typical bundled process-image width (720×1289). Square cover shows the
  /// top [srcWidth]×[srcWidth] band; we drop [cutBottomPx] from that band.
  static const double srcWidth = 720;
  static const double cutBottomPx = 300;

  static const _ua = {
    'User-Agent': 'HowToCook-mobile/0.6.21',
    'Accept': 'image/jpeg,image/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    final path = ProcessImageService.instance.assetPathFor(recipe);
    final remote = ProcessImageService.instance.remoteUrlFor(recipe);
    final radius = borderRadius ?? BorderRadius.circular(14);
    // Render taller than the clip so bottom of the square crop is discarded.
    final visibleBand = srcWidth - cutBottomPx; // 420
    final tall = size * (srcWidth / visibleBand); // ~1.714 × size

    Widget image;
    if (path != null) {
      image = Image.asset(
        path,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: size,
        height: tall,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (remote != null && remote.isNotEmpty) {
      image = Image.network(
        remote,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: size,
        height: tall,
        filterQuality: FilterQuality.medium,
        headers: _ua,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      image = _fallback();
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: size, height: tall, child: image),
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: AppTheme.softCoral.withValues(alpha: 0.55),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: AppTheme.navy, size: 22),
      ),
    );
  }
}
