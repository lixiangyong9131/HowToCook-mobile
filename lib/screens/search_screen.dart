import 'package:flutter/material.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../routes/recipe_nav.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../utils/recipe_meta.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_filter_bar.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  List<Recipe> _raw = const [];
  DifficultyFilter _difficulty = DifficultyFilter.all;
  TimeFilter _time = TimeFilter.all;
  CalorieFilter _calories = CalorieFilter.all;
  RecipeSort _sort = RecipeSort.name;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch(widget.initialQuery!.trim(), persist: true);
      });
    }
  }

  void _runSearch(String value, {bool persist = false}) {
    setState(() => _raw = RecipeRepository.instance.search(value));
    if (persist && value.trim().isNotEmpty) {
      HistoryScope.of(context).addSearch(value.trim());
    }
  }

  void _onChanged(String value) {
    _runSearch(value, persist: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim();
    final results = applyRecipeFilters(
      _raw,
      difficulty: _difficulty,
      time: _time,
      calories: _calories,
      sort: _sort,
    );
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: (widget.initialQuery ?? '').isEmpty,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textInputAction: TextInputAction.search,
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
            onSubmitted: (v) => _runSearch(v, persist: true),
          ),
        ),
      ),
      body: q.isEmpty
          ? const _EmptyHint(text: '试试「番茄」「鸡蛋」「汤」')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: RecipeFilterBar(
                    difficulty: _difficulty,
                    time: _time,
                    calories: _calories,
                    sort: _sort,
                    resultCount: results.length,
                    onDifficulty: (v) => setState(() => _difficulty = v),
                    onTime: (v) => setState(() => _time = v),
                    onCalories: (v) => setState(() => _calories = v),
                    onSort: (v) => setState(() => _sort = v),
                  ),
                ),
                Expanded(
                  child: results.isEmpty
                      ? _EmptyHint(
                          text: _raw.isEmpty
                              ? '没有搜到与 “$q” 相关的菜谱'
                              : '没有符合筛选的结果',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [
                            for (var i = 0; i < results.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: RecipeCard(
                                  index: i + 1,
                                  recipe: results[i],
                                  accent: categoryAccent(
                                    results[i].categoryId,
                                    i,
                                  ),
                                  onTap: () => openRecipeDetail(
                                    context,
                                    recipe: results[i],
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
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
