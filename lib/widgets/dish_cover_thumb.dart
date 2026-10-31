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

/// List/logo thumb: process-image crop
/// `left=10%`, `top=0`, `width=80%`, `height=25%` (upper quarter, middle 80%).
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

  static const _ua = {
    'User-Agent': 'HowToCook-mobile/0.6.24',
    'Accept': 'image/jpeg,image/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    final path = ProcessImageService.instance.assetPathFor(recipe);
    final remote = ProcessImageService.instance.remoteUrlFor(recipe);
    final radius = borderRadius ?? BorderRadius.circular(14);

    final Widget raw;
    if (path != null) {
      raw = Image.asset(
        path,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (remote != null && remote.isNotEmpty) {
      raw = Image.network(
        remote,
        filterQuality: FilterQuality.medium,
        headers: _ua,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      raw = _fallback();
    }

    // Align factors clip to middle 80% × top 25%; FittedBox maps that rect to thumb.
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.fill,
          clipBehavior: Clip.hardEdge,
          child: Align(
            alignment: Alignment.topCenter,
            widthFactor: 0.8,
            heightFactor: 0.25,
            child: raw,
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: AppTheme.softCoral.withValues(alpha: 0.55),
      child: const SizedBox(
        width: 160,
        height: 160,
        child: Center(
          child: Icon(Icons.restaurant_rounded, color: AppTheme.navy, size: 48),
        ),
      ),
    );
  }
}
