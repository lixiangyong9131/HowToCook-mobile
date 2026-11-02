import 'package:flutter/material.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../routes/recipe_nav.dart';
import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../utils/recipe_meta.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_filter_bar.dart';

/// 常用搜索词（菜名 / 原料 / 做法），贴合菜谱 App。
const kCommonSearchTerms = <String>[
  '鸡蛋',
  '番茄',
  '土豆',
  '米饭',
  '炒菜',
  '汤',
  '豆腐',
  '鸡肉',
  '青椒',
  '茄子',
  '牛肉',
  '面条',
];

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
  RecipeSort _sort = RecipeSort.relevance;

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

  void _applyChip(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _runSearch(term, persist: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim();
    final history = HistoryScope.of(context);
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
          ? ListenableBuilder(
              listenable: history,
              builder: (context, _) => _SearchLanding(
                searches: history.searches,
                onClearHistory: () => history.clearSearches(),
                onPick: _applyChip,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: RecipeFilterBar(
                    difficulty: _difficulty,
                    time: _time,
                    calories: _calories,
                    sort: _sort,
                    defaultSort: RecipeSort.relevance,
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

class _SearchLanding extends StatelessWidget {
  final List<String> searches;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onPick;

  const _SearchLanding({
    required this.searches,
    required this.onClearHistory,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (searches.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClearHistory,
                child: const Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.coral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in searches.take(20))
                ActionChip(
                  label: Text(q),
                  backgroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: AppTheme.coral.withValues(alpha: 0.28),
                  ),
                  avatar: const Icon(
                    Icons.history,
                    size: 16,
                    color: AppTheme.coral,
                  ),
                  onPressed: () => onPick(q),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        const Text(
          '常用词',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in kCommonSearchTerms)
              ActionChip(
                label: Text(term),
                backgroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: AppTheme.purple.withValues(alpha: 0.22),
                ),
                avatar: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: AppTheme.purple,
                ),
                onPressed: () => onPick(term),
              ),
          ],
        ),
        if (searches.isEmpty) ...[
          const SizedBox(height: 28),
          const Text(
            '点选常用词，或直接输入菜名 / 原料搜索',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
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
