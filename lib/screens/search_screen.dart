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

  /// Tracks the last query we already wrote to HistoryStore this session,
  /// so reopen/detail-return paths stay idempotent without spamming prefs.
  String? _lastPersisted;

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

  void _persistQuery(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    if (_lastPersisted != null &&
        _lastPersisted!.toLowerCase() == q.toLowerCase()) {
      return;
    }
    _lastPersisted = q;
    HistoryScope.of(context).addSearch(q);
  }

  void _runSearch(String value, {bool persist = false}) {
    setState(() => _raw = RecipeRepository.instance.search(value));
    if (persist) {
      _persistQuery(value);
    }
  }

  void _onChanged(String value) {
    // Live filter only — do not write partial keystrokes into history.
    _runSearch(value, persist: false);
  }

  /// Explicit submit: keyboard search / 搜索按钮 / chip / history pick.
  void _submitQuery(String value) {
    final q = value.trim();
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _runSearch(q, persist: true);
  }

  void _applyChip(String term) {
    _submitQuery(term);
  }

  void _openRecipe(Recipe recipe) {
    // Typing + tapping a result is a committed search; record before leaving.
    _persistQuery(_controller.text);
    openRecipeDetail(context, recipe: recipe);
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Leaving search with a non-empty query also counts as a search.
        final leaving = _controller.text.trim();
        if (leaving.isNotEmpty) {
          // Avoid depending on context after pop; HistoryScope is above this route.
          history.addSearch(leaving);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _SearchField(
              controller: _controller,
              autofocus: (widget.initialQuery ?? '').isEmpty,
              hasQuery: q.isNotEmpty,
              onChanged: _onChanged,
              onSubmitted: _submitQuery,
              onClear: () {
                _controller.clear();
                _onChanged('');
              },
              onSearchTap: () => _submitQuery(_controller.text),
            ),
          ),
        ),
        body: q.isEmpty
            ? ListenableBuilder(
                listenable: history,
                builder: (context, _) => _SearchLanding(
                  searches: history.searches,
                  onClearHistory: () => history.clearSearches(),
                  onRemoveHistory: (term) => history.removeSearch(term),
                  onPick: _applyChip,
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: DecoratedBox(
                      decoration: AppTheme.logoCard(radius: AppTheme.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? _EmptyHint(
                            icon: Icons.search_off_rounded,
                            text: _raw.isEmpty
                                ? '没有搜到与 “$q” 相关的菜谱'
                                : '没有符合筛选的结果',
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  '找到 ${results.length} 道菜',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
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
                                    onTap: () => _openRecipe(results[i]),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool autofocus;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onSearchTap;

  const _SearchField({
    required this.controller,
    required this.autofocus,
    required this.hasQuery,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
        border: Border.all(color: AppTheme.coral.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.ink,
              ),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索菜名或原料…',
                hintStyle: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                isDense: true,
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          if (hasQuery)
            IconButton(
              tooltip: '清除',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppTheme.muted,
              onPressed: onClear,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: AppTheme.coral,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onSearchTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded, size: 16, color: AppTheme.cream),
                      SizedBox(width: 4),
                      Text(
                        '搜索',
                        style: TextStyle(
                          color: AppTheme.cream,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
  final ValueChanged<String> onRemoveHistory;
  final ValueChanged<String> onPick;

  const _SearchLanding({
    required this.searches,
    required this.onClearHistory,
    required this.onRemoveHistory,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (searches.isNotEmpty) ...[
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  icon: Icons.history_rounded,
                  title: '搜索历史',
                  actionLabel: '清空',
                  onAction: onClearHistory,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final q in searches.take(20))
                      _HistoryChip(
                        label: q,
                        onTap: () => onPick(q),
                        onDelete: () => onRemoveHistory(q),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.local_fire_department_rounded,
                title: '常用词',
                subtitle: '点一下直接搜',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                alignment: WrapAlignment.start,
                children: [
                  for (final term in kCommonSearchTerms)
                    _CommonChip(
                      label: term,
                      onTap: () => onPick(term),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (searches.isEmpty) ...[
          const SizedBox(height: 20),
          const _EmptyHint(
            icon: Icons.restaurant_menu_rounded,
            text: '点选常用词，或直接输入菜名 / 原料搜索',
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: AppTheme.logoCard(radius: AppTheme.radius),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppTheme.logoGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: AppTheme.coral),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              subtitle!,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.coral,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

/// History chip: coral outline + history icon + trailing delete.
class _HistoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryChip({
    required this.label,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.softCoral.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.coral.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, size: 15, color: AppTheme.coral),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(width: 2),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppTheme.muted,
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

/// Common-term chip: cream/white fill, navy text, even padding.
class _CommonChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CommonChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.navy.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.navy.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;
  const _EmptyHint({required this.text, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: AppTheme.logoCard(radius: AppTheme.radius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: AppTheme.coral.withValues(alpha: 0.85)),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
