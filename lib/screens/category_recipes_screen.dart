import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import 'recipe_detail_screen.dart';

class CategoryRecipesScreen extends StatelessWidget {
  final CategoryInfo category;
  const CategoryRecipesScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final recipes = RecipeRepository.instance.byCategory(category.id)
      ..sort((a, b) => a.title.compareTo(b.title));

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: ListView.separated(
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = recipes[i];
          return ListTile(
            title: Text(r.title),
            subtitle: r.difficulty != null
                ? Text('难度 ${r.difficultyStars}')
                : null,
            trailing: const Icon(Icons.chevron_right),
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
