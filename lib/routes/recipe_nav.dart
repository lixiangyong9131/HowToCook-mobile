import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../screens/recipe_detail_screen.dart';
import '../services/history_store.dart';
import '../services/process_image_service.dart';
import '../services/recipe_repository.dart';

/// Open [RecipeDetailScreen] from any list / history / favorites entry.
///
/// Uses a plain [MaterialPageRoute] so navigation is reliable (circular
/// reveal had opaque:false / gesture edge cases that made taps look dead).
///
/// Prefer passing [recipe] when you already have it. For 最近浏览, pass
/// [browse] so we can fall back title+categoryId if the stored id is stale.
Future<void> openRecipeDetail(
  BuildContext context, {
  Recipe? recipe,
  String? recipeId,
  BrowseEntry? browse,
}) async {
  var r = recipe;
  if (r == null && browse != null) {
    r = RecipeRepository.instance.resolveBrowse(browse);
  }
  if (r == null && recipeId != null && recipeId.isNotEmpty) {
    r = RecipeRepository.instance.byId(recipeId);
  }
  if (r == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到该菜谱，可能已更新数据')),
      );
    }
    return;
  }

  // Warm process-image index + kick disk/network cache before the route
  // paints Module1 — avoids empty 做法大图 on the browse→detail cold path.
  final warm = r;
  await ProcessImageService.instance.ensureLoaded();
  if (ProcessImageService.instance.hasImage(warm)) {
    // Fire-and-forget prefetch; detail viewer will reuse the cached file.
    // ignore: unawaited_futures
    ProcessImageService.instance.cachedFileFor(warm);
  }

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => RecipeDetailScreen(recipe: warm),
    ),
  );
}
