import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

class RecipeCard extends StatelessWidget {
  final int index;
  final Recipe recipe;
  final Color accent;
  final VoidCallback onTap;
  final bool showCategory;

  const RecipeCard({
    super.key,
    required this.index,
    required this.recipe,
    required this.accent,
    required this.onTap,
    this.showCategory = false,
  });

  @override
  Widget build(BuildContext context) {
    final fav = FavoritesScope.of(context).isFavorite(recipe.id);
    final dark = isDarkCard(accent);
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: AppTheme.purple.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.purple.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.logoGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: dark ? Colors.white : AppTheme.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (showCategory || recipe.difficulty != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (showCategory) ...[
                                Text(
                                  categoryEmojis[recipe.categoryId] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  recipe.categoryName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (recipe.difficulty != null)
                                  const Text(
                                    ' · ',
                                    style: TextStyle(color: AppTheme.muted),
                                  ),
                              ],
                              if (recipe.difficulty != null)
                                Text(
                                  recipe.difficultyStars,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.coral,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (fav)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.favorite, size: 16, color: AppTheme.coral),
                  ),
                const Icon(Icons.north_east, size: 18, color: AppTheme.purple),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
