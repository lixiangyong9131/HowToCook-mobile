import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../routes/recipe_nav.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';
import '../utils/recipe_meta.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_filter_bar.dart';

class CategoryRecipesScreen extends StatefulWidget {
  final CategoryInfo category;
  const CategoryRecipesScreen({super.key, required this.category});

  @override
  State<CategoryRecipesScreen> createState() => _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends State<CategoryRecipesScreen> {
  DifficultyFilter _difficulty = DifficultyFilter.all;
  TimeFilter _time = TimeFilter.all;
  CalorieFilter _calories = CalorieFilter.all;
  RecipeSort _sort = RecipeSort.name;

  @override
  Widget build(BuildContext context) {
    final base = RecipeRepository.instance.byCategory(widget.category.id);
    final recipes = applyRecipeFilters(
      base,
      difficulty: _difficulty,
      time: _time,
      calories: _calories,
      sort: _sort,
    );
    final catIndex = RecipeRepository.instance.db?.categories
            .indexWhere((c) => c.id == widget.category.id) ??
        0;
    final accent =
        categoryAccent(widget.category.id, catIndex < 0 ? 0 : catIndex);

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
                    child: DoodleIcons.categoryIcon(widget.category.id,
                        size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.category.name,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: RecipeFilterBar(
                difficulty: _difficulty,
                time: _time,
                calories: _calories,
                sort: _sort,
                resultCount: recipes.length,
                onDifficulty: (v) => setState(() => _difficulty = v),
                onTime: (v) => setState(() => _time = v),
                onCalories: (v) => setState(() => _calories = v),
                onSort: (v) => setState(() => _sort = v),
              ),
            ),
            Expanded(
              child: recipes.isEmpty
                  ? const Center(
                      child: Text(
                        '没有符合筛选的菜谱',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                      itemCount: recipes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = recipes[i];
                        return RecipeCard(
                          index: i + 1,
                          recipe: r,
                          accent: accent,
                          onTap: () => openRecipeDetail(context, recipe: r),
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
