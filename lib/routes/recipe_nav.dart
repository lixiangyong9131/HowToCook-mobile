import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../screens/recipe_detail_screen.dart';
import '../services/recipe_repository.dart';

/// Open [RecipeDetailScreen] from any list / history / favorites entry.
///
/// Uses a plain [MaterialPageRoute] so navigation is reliable (circular
/// reveal had opaque:false / gesture edge cases that made taps look dead).
Future<void> openRecipeDetail(
  BuildContext context, {
  Recipe? recipe,
  String? recipeId,
}) async {
  var r = recipe;
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
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => RecipeDetailScreen(recipe: r!),
    ),
  );
}
