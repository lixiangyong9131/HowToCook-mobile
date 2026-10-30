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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (recipe.difficulty != null)
                                const Text(' · ',
                                    style: TextStyle(color: Colors.grey)),
                            ],
                            if (recipe.difficulty != null)
                              Text(
                                recipe.difficultyStars,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFF8F00),
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
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.favorite, size: 16, color: Colors.redAccent),
                ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
