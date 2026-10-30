import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _categoryIndex = 0;
  final _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = RecipeRepository.instance.db!;
    final cats = db.categories;
    final cat = cats[_categoryIndex];
    final recipes = RecipeRepository.instance.byCategory(cat.id)
      ..sort((a, b) => a.title.compareTo(b.title));
    final color = categoryColors[cat.id] ?? AppTheme.accent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('程序员做饭指南'),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _HeroBanner(total: db.recipes.length),
          Expanded(
            child: Row(
              children: [
                _CategorySidebar(
                  categories: cats,
                  selected: _categoryIndex,
                  onSelect: (i) {
                    setState(() => _categoryIndex = i);
                    if (_listController.hasClients) {
                      _listController.jumpTo(0);
                    }
                  },
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: CustomScrollView(
                      controller: _listController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  categoryEmojis[cat.id] ?? '📖',
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${recipes.length}',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          sliver: SliverList.separated(
                            itemCount: recipes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = recipes[i];
                              return RecipeCard(
                                index: i + 1,
                                recipe: r,
                                accent: color,
                                onTap: () => _open(r),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(Recipe r) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r)),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final int total;
  const _HeroBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A65), Color(0xFFE65100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE65100).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今天想吃什么？',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '离线菜谱 $total 道 · 灵感来自 HowToCook',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Text('👨‍🍳', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  final List<CategoryInfo> categories;
  final int selected;
  final ValueChanged<int> onSelect;

  const _CategorySidebar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      color: AppTheme.sidebarBg,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final c = categories[i];
          final active = i == selected;
          final color = categoryColors[c.id] ?? AppTheme.accent;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Material(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              elevation: active ? 1 : 0,
              shadowColor: color.withValues(alpha: 0.3),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Text(
                        categoryEmojis[c.id] ?? '📖',
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                          color: active ? color : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
