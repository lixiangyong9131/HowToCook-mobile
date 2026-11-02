import 'package:flutter/material.dart';

import '../main.dart';
import '../routes/recipe_nav.dart';
import '../services/history_store.dart';
import '../services/process_image_service.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/dish_cover_thumb.dart';
import '../widgets/stacked_category_cards.dart';
import 'category_recipes_screen.dart';
import 'search_screen.dart';

/// Home = search pill → Wallet 分类叠卡 → 最近浏览（搜索历史在 SearchScreen）.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = HistoryScope.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: history,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/branding/app_icon_512.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '程序员做饭指南',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SearchPill(
                          onOpen: () => _openSearch(context),
                        ),
                        const SizedBox(height: 22),
                        // Wallet-style folded category stack on home
                        Builder(
                          builder: (context) {
                            final db = RecipeRepository.instance.db;
                            if (db == null || db.categories.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final cats = db.categories;
                            final counts = <String, int>{
                              for (final c in cats)
                                c.id: RecipeRepository.instance
                                    .byCategory(c.id)
                                    .length,
                            };
                            return StackedCategoryCards(
                              categories: cats,
                              counts: counts,
                              initiallyExpanded: false,
                              autoFanOnMount: false,
                              openOnSwipeSettle: false,
                              showExpandButton: true,
                              onOpen: (cat) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CategoryRecipesScreen(category: cat),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 26),
                        _SectionHeader(
                          title: '最近浏览',
                          subtitle: '最多 20 条 · 最新在上',
                          action: history.browses.isEmpty ? null : '清空',
                          onAction: history.browses.isEmpty
                              ? null
                              : () => history.clearBrowses(),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (history.browses.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
                      child: _EmptyHint(text: '打开一道菜谱后会出现在这里'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList.separated(
                      itemCount: history.browses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final e = history.browses[i];
                        return _BrowseRow(
                          entry: e,
                          onTap: () => openRecipeDetail(
                            context,
                            browse: e,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openSearch(BuildContext context, {String? initial}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: initial),
      ),
    );
  }
}



/// 首页搜索入口：点击 / 聚焦即进入独立搜索页（不在首页输入或展示历史）。
class _SearchPill extends StatelessWidget {
  final VoidCallback onOpen;
  const _SearchPill({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppTheme.softShadow(opacity: 0.10),
            border: Border.all(color: AppTheme.coral.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppTheme.coral),
                      SizedBox(width: 12),
                      Text(
                        '搜索菜名或原料…',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: AppTheme.coral,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(
                      '搜索',
                      style: TextStyle(
                        color: AppTheme.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(
            gradient: AppTheme.logoGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.coral,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.purple.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _BrowseRow extends StatelessWidget {
  final BrowseEntry entry;
  final VoidCallback onTap;
  const _BrowseRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = categoryColors[entry.categoryId] ?? categoryCardPalette[0];
    final recipe = RecipeRepository.instance.resolveBrowse(entry);
    final hasImg =
        recipe != null && ProcessImageService.instance.hasImage(recipe);
    final dark = isDarkCard(color);
    final fg = hasImg
        ? Colors.white
        : (dark ? Colors.white : AppTheme.navy);
    return Material(
      color: Colors.transparent,
      elevation: 2,
      shadowColor: AppTheme.navy.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: DishCoverRowBackground(
          recipe: recipe,
          fallbackColor: color,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
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
                    const SizedBox(height: 2),
                    Text(
                      entry.categoryName,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.north_east_rounded,
                  size: 18, color: fg.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

