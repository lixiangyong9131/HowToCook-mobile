import 'package:flutter/material.dart';

import '../main.dart';
import '../models/recipe.dart';
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
      appBar: AppBar(title: const Text('我的收藏')),
      body: recipes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('还没有收藏',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Text(
                    '在菜谱详情页点 ❤️ 即可收藏',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = recipes[i];
                return RecipeCard(
                  index: i + 1,
                  recipe: r,
                  accent: categoryColors[r.categoryId] ?? AppTheme.accent,
                  showCategory: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipe: r),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
