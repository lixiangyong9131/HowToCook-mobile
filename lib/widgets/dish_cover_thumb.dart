import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Dish cover/logo from the process-image top (food photo), shown as a square
/// thumb — for list number slots and detail navy header. Not a body strip.
class DishCoverThumb extends StatelessWidget {
  final Recipe recipe;
  final double size;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final Color? fallbackColor;

  const DishCoverThumb({
    super.key,
    required this.recipe,
    this.size = 44,
    this.borderRadius,
    this.fallback,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(14);
    final path = ProcessImageService.instance.assetPathFor(recipe);
    final remote = ProcessImageService.instance.remoteUrlFor(recipe);

    Widget content;
    if (path != null) {
      content = Image.asset(
        path,
        fit: BoxFit.cover,
        // Top-center ≈ finished-dish photo on 9:16 process cards.
        alignment: const Alignment(0, -0.92),
        cacheWidth: (size * 3).round().clamp(64, 256),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallbackBox(),
      );
    } else if (remote != null && remote.isNotEmpty) {
      content = Image.network(
        remote,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.92),
        cacheWidth: (size * 3).round().clamp(64, 256),
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _fallbackBox(),
        headers: const {
          'User-Agent': 'HowToCook-mobile/0.6.12',
          'Accept': 'image/jpeg,image/*;q=0.8',
        },
      );
    } else {
      content = _fallbackBox();
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: content,
      ),
    );
  }

  Widget _fallbackBox() {
    if (fallback != null) return fallback!;
    return ColoredBox(
      color: fallbackColor ?? AppTheme.softCoral,
      child: const SizedBox.expand(),
    );
  }
}
