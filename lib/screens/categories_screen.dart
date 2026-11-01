import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';
import 'category_recipes_screen.dart';

/// Plain category list. Opens [CategoryRecipesScreen] for one category.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  void _openCategory(BuildContext context, CategoryInfo cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryRecipesScreen(category: cat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = RecipeRepository.instance.db!;
    final cats = db.categories;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      '分类浏览',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.logoGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${cats.length} 类',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Text(
                '点一行进入该类菜谱',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final cat = cats[i];
                  final count = RecipeRepository.instance
                      .byCategory(cat.id)
                      .length;
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      onTap: () => _openCategory(context, cat),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            DoodleIcons.categoryIcon(cat.id, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '$count 道',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
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
