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
    'User-Agent': 'HowToCook-mobile/0.6.13',
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
