import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../routes/circular_reveal_route.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Recipe> _results = const [];

  void _onChanged(String value) {
    setState(() => _results = RecipeRepository.instance.search(value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '搜索菜名或原料…',
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              suffixIcon: q.isEmpty
                  ? const Icon(Icons.search, color: AppTheme.muted)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
            onChanged: _onChanged,
          ),
        ),
      ),
      body: q.isEmpty
          ? const _EmptyHint(text: '试试「番茄」「鸡蛋」「汤」')
          : _results.isEmpty
              ? _EmptyHint(text: '没有搜到与 “$q” 相关的菜谱')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: Text(
                        '找到 ${_results.length} 个结果',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ..._results.asMap().entries.map((e) {
                      final r = e.value;
                      final color =
                          categoryColors[r.categoryId] ?? AppTheme.lime;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Builder(
                          builder: (ctx) {
                            return RecipeCard(
                              index: e.key + 1,
                              recipe: r,
                              accent: color,
                              showCategory: true,
                              onTap: () {
                                final box =
                                    ctx.findRenderObject() as RenderBox?;
                                final origin = box?.localToGlobal(
                                      box.size.center(Offset.zero),
                                    );
                                CircularRevealRoute.open(
                                  context,
                                  page: RecipeDetailScreen(recipe: r),
                                  from: origin,
                                );
                              },
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.lavender,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, size: 28),
          ),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }
}
