import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../routes/circular_reveal_route.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/stacked_category_cards.dart';
import 'category_recipes_screen.dart';
import 'recipe_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Text(
                            '今天吃什么',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                              height: 1.05,
                            ),
                          ),
                        ),
                        Text(
                          '${_weekday()} · ${_md()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SearchPill(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _RandomHero(
                      total: db.recipes.length,
                      onTap: (origin) {
                        final list = db.recipes;
                        if (list.isEmpty) return;
                        final r = list[math.Random().nextInt(list.length)];
                        CircularRevealRoute.open(
                          context,
                          page: RecipeDetailScreen(recipe: r),
                          from: origin,
                          veilColor: AppTheme.blackCard,
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    StackedCategoryCards(
                      categories: cats,
                      counts: counts,
                      onOpen: (cat) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryRecipesScreen(category: cat),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      '随便看看',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '从全部 ${db.recipes.length} 道里挑几道',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
              sliver: SliverList.separated(
                itemCount: math.min(8, db.recipes.length),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  // stable-ish sample
                  final r = db.recipes[(i * 37) % db.recipes.length];
                  return _SoftRecipeRow(
                    recipe: r,
                    index: i + 1,
                    onTap: (origin) {
                      CircularRevealRoute.open(
                        context,
                        page: RecipeDetailScreen(recipe: r),
                        from: origin,
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

  String _weekday() {
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return names[DateTime.now().weekday - 1];
  }

  String _md() {
    final n = DateTime.now();
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[n.month - 1]} ${n.day.toString().padLeft(2, '0')}';
  }
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppTheme.muted),
              SizedBox(width: 10),
              Text(
                '搜索菜名或原料…',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RandomHero extends StatelessWidget {
  final int total;
  final void Function(Offset globalOrigin) onTap;
  const _RandomHero({required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) => onTap(d.globalPosition),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.blackCard,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: AppTheme.softShadow(opacity: 0.18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RANDOM · $total DISHES',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '随便做一道',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'One dish at a time',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.lime,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '抽一道 →',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftRecipeRow extends StatelessWidget {
  final Recipe recipe;
  final int index;
  final void Function(Offset origin) onTap;

  const _SoftRecipeRow({
    required this.recipe,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = categoryColors[recipe.categoryId] ?? AppTheme.lime;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTapDown: (d) => onTap(d.globalPosition),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDarkCard(accent) ? 1 : 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  categoryEmojis[recipe.categoryId] ?? '📖',
                  style: const TextStyle(fontSize: 22),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recipe.categoryName,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppTheme.ink.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
