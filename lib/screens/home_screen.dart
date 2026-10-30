import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import 'about_screen.dart';
import 'category_recipes_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<RecipeDatabase> _future;

  static const _icons = <String, IconData>{
    'aquatic': Icons.set_meal,
    'breakfast': Icons.free_breakfast,
    'condiment': Icons.spa,
    'dessert': Icons.cake,
    'drink': Icons.local_cafe,
    'meat_dish': Icons.kebab_dining,
    'semi-finished': Icons.kitchen,
    'soup': Icons.soup_kitchen,
    'staple': Icons.rice_bowl,
    'vegetable_dish': Icons.eco,
  };

  @override
  void initState() {
    super.initState();
    _future = RecipeRepository.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('程序员做饭指南'),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            tooltip: '关于',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<RecipeDatabase>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('加载失败：${snap.error}'));
          }
          final db = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '离线菜谱 · ${db.recipes.length} 道',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        db.attribution,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('分类', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...db.categories.map((c) {
                final count = db.recipes
                    .where((r) => r.categoryId == c.id)
                    .length;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_icons[c.id] ?? Icons.restaurant),
                    ),
                    title: Text(c.name),
                    subtitle: Text('$count 道菜'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryRecipesScreen(category: c),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
