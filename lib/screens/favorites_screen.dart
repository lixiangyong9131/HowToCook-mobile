import 'package:flutter/material.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../routes/circular_reveal_route.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FavoritesScope.of(context);
    final recipes = <Recipe>[];
    for (final id in store.ids) {
      final r = RecipeRepository.instance.byId(id);
      if (r != null) recipes.add(r);
    }
    recipes.sort((a, b) => a.title.compareTo(b.title));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '收藏',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Text(
                    '${recipes.length} SAVED',
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
            Expanded(
              child: recipes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppTheme.lavender,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_border,
                                size: 32, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '还没有收藏',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '在菜谱详情点爱心即可收藏',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                      itemCount: recipes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = recipes[i];
                        return Builder(
                          builder: (ctx) {
                            return RecipeCard(
                              index: i + 1,
                              recipe: r,
                              accent: categoryColors[r.categoryId] ??
                                  AppTheme.lime,
                              showCategory: true,
                              onTap: () {
                                final box =
                                    ctx.findRenderObject() as RenderBox?;
                                final origin = box?.localToGlobal(
                                      box.size.center(Offset.zero),
                                    ) ??
                                    Offset.zero;
                                CircularRevealRoute.open(
                                  context,
                                  page: RecipeDetailScreen(recipe: r),
                                  from: origin,
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
