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


/// Full-row list background: process-image band as width-filled cover.
/// Skips the top ~1/9 (often letterbox / chrome), then takes the next ~1/4.
/// Puts [child] above a readability scrim (no side logo thumb).
class DishCoverRowBackground extends StatelessWidget {
  final Recipe? recipe;
  final Color fallbackColor;
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  const DishCoverRowBackground({
    super.key,
    required this.recipe,
    required this.fallbackColor,
    required this.child,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  });

  /// Ignore this fraction from the very top of the process image.
  static const double skipTop = 1 / 9;

  /// Vertical band height (of full image) used as the row cover.
  static const double bandHeight = 0.25;

  /// Align.y so [skipTop, skipTop+bandHeight] is the visible band.
  /// y = 2*skipTop/(1-bandHeight) - 1 = 2/(9*0.75) - 1 = 8/27 - 1 = -19/27
  static const Alignment _bandAlign = Alignment(0, -19 / 27);

  static const _ua = {
    'User-Agent': 'HowToCook-mobile/0.6.27',
    'Accept': 'image/jpeg,image/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radius);
    final r = recipe;
    final path =
        r == null ? null : ProcessImageService.instance.assetPathFor(r);
    final remote =
        r == null ? null : ProcessImageService.instance.remoteUrlFor(r);

    Widget? image;
    if (path != null) {
      image = Image.asset(
        path,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else if (remote != null && remote.isNotEmpty) {
      image = Image.network(
        remote,
        filterQuality: FilterQuality.medium,
        headers: _ua,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Fallback / base fill.
          Positioned.fill(child: ColoredBox(color: fallbackColor)),
          // Band [skipTop, skipTop+bandHeight], cover-fitted to the row.
          if (image != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                child: Align(
                  alignment: _bandAlign,
                  heightFactor: bandHeight,
                  child: image,
                ),
              ),
            ),
          // Scrim so title stays readable over food photo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: image != null ? 0.55 : 0.0),
                    Colors.black.withValues(alpha: image != null ? 0.35 : 0.0),
                    Colors.black.withValues(alpha: image != null ? 0.45 : 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
