import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../services/process_image_service.dart';
import '../theme/app_theme.dart';
import 'dish_cover_thumb.dart';

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
    final hasImg = ProcessImageService.instance.hasImage(recipe);
    final darkFallback = isDarkCard(accent);
    final fg = hasImg
        ? Colors.white
        : (darkFallback ? Colors.white : AppTheme.navy);
    final mutedFg = fg.withValues(alpha: 0.82);

    return Material(
      color: Colors.transparent,
      elevation: 2,
      shadowColor: AppTheme.navy.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: DishCoverRowBackground(
          recipe: recipe,
          fallbackColor: accent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        shadows: hasImg
                            ? const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
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
                                  color: mutedFg,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (recipe.difficulty != null)
                                Text(
                                  ' · ',
                                  style: TextStyle(color: mutedFg),
                                ),
                            ],
                            if (recipe.difficulty != null)
                              Text(
                                recipe.difficultyStars,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasImg
                                      ? AppTheme.softCoral
                                      : AppTheme.coral,
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
              Icon(Icons.north_east, size: 18, color: mutedFg),
            ],
          ),
        ),
      ),
    );
  }
}
