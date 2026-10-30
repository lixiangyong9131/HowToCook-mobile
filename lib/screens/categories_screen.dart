import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/stacked_category_cards.dart';
import 'category_recipes_screen.dart';

/// Dedicated page so 叠卡展开 is impossible to miss (auto-expands on open).
class CategoriesScreen extends StatefulWidget {
  final String? highlightId;
  const CategoriesScreen({super.key, this.highlightId});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final db = RecipeRepository.instance.db!;
    final cats = db.categories;
    final counts = <String, int>{
      for (final c in cats)
        c.id: RecipeRepository.instance.byCategory(c.id).length,
    };

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                '叠卡会自动展开 — 点卡片进入该类菜谱',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: StackedCategoryCards(
                  categories: cats,
                  counts: counts,
                  initiallyExpanded: true,
                  autoFanOnMount: true,
                  onOpen: (CategoryInfo cat) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryRecipesScreen(category: cat),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
