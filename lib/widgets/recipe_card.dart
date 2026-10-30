import 'package:flutter/material.dart';

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
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8E8ED)),
          ),
          child: Row(
            children: [
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
                    color: dark ? Colors.white : AppTheme.ink,
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
                                const Text(' · ',
                                    style: TextStyle(color: AppTheme.muted)),
                            ],
                            if (recipe.difficulty != null)
                              Text(
                                recipe.difficultyStars,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.orange,
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
                  child: Icon(Icons.favorite, size: 16, color: AppTheme.orange),
                ),
              const Icon(Icons.north_east, size: 18, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
