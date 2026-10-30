import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../routes/circular_reveal_route.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class CategoryRecipesScreen extends StatelessWidget {
  final CategoryInfo category;
  const CategoryRecipesScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final recipes = RecipeRepository.instance.byCategory(category.id)
      ..sort((a, b) => a.title.compareTo(b.title));
    final catIndex = RecipeRepository.instance.db?.categories
            .indexWhere((c) => c.id == category.id) ??
        0;
    final accent = categoryAccent(category.id, catIndex < 0 ? 0 : catIndex);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 22, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  Text(
                    '${recipes.length} DISHES',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      categoryEmojis[category.id] ?? '📖',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                itemCount: recipes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = recipes[i];
                  return Builder(
                    builder: (ctx) {
                      return RecipeCard(
                        index: i + 1,
                        recipe: r,
                        accent: accent,
                        onTap: () {
                          final box = ctx.findRenderObject() as RenderBox?;
                          final origin = box?.localToGlobal(
                            box.size.center(Offset.zero),
                          );
                          CircularRevealRoute.open(
                            context,
                            page: RecipeDetailScreen(recipe: r),
                            from: origin,
                            veilColor: isDarkCard(accent)
                                ? accent
                                : AppTheme.blackCard,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
