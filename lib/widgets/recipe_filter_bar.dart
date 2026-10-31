import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/recipe_meta.dart';

/// Compact chip row for difficulty / time / calories / sort.
class RecipeFilterBar extends StatelessWidget {
  final DifficultyFilter difficulty;
  final TimeFilter time;
  final CalorieFilter calories;
  final RecipeSort sort;
  final ValueChanged<DifficultyFilter> onDifficulty;
  final ValueChanged<TimeFilter> onTime;
  final ValueChanged<CalorieFilter> onCalories;
  final ValueChanged<RecipeSort> onSort;
  final int resultCount;

  const RecipeFilterBar({
    super.key,
    required this.difficulty,
    required this.time,
    required this.calories,
    required this.sort,
    required this.onDifficulty,
    required this.onTime,
    required this.onCalories,
    required this.onSort,
    required this.resultCount,
  });

  bool get _active =>
      difficulty != DifficultyFilter.all ||
      time != TimeFilter.all ||
      calories != CalorieFilter.all ||
      sort != RecipeSort.name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip(
                label: _diffLabel(difficulty),
                active: difficulty != DifficultyFilter.all,
                onTap: () => _pickDifficulty(context),
              ),
              const SizedBox(width: 8),
              _chip(
                label: _timeLabel(time),
                active: time != TimeFilter.all,
                onTap: () => _pickTime(context),
              ),
              const SizedBox(width: 8),
              _chip(
                label: _calLabel(calories),
                active: calories != CalorieFilter.all,
                onTap: () => _pickCalories(context),
              ),
              const SizedBox(width: 8),
              _chip(
                label: _sortLabel(sort),
                active: sort != RecipeSort.name,
                onTap: () => _pickSort(context),
                icon: Icons.sort_rounded,
              ),
              if (_active) ...[
                const SizedBox(width: 8),
                _chip(
                  label: '重置',
                  active: false,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onDifficulty(DifficultyFilter.all);
                    onTime(TimeFilter.all);
                    onCalories(CalorieFilter.all);
                    onSort(RecipeSort.name);
                  },
                  icon: Icons.refresh_rounded,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '共 $resultCount 道',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: active ? AppTheme.navy : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppTheme.navy
                  : AppTheme.navy.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: active ? AppTheme.neon : AppTheme.muted,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppTheme.ink,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 14,
                color: active ? Colors.white70 : AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDifficulty(BuildContext context) async {
    final v = await _sheet<DifficultyFilter>(
      context,
      title: '难度',
      options: const [
        (DifficultyFilter.all, '全部难度'),
        (DifficultyFilter.easy, '简单 ★～★★'),
        (DifficultyFilter.medium, '中等 ★★★'),
        (DifficultyFilter.hard, '较难 ★★★★～★★★★★'),
      ],
      current: difficulty,
    );
    if (v != null) onDifficulty(v);
  }

  Future<void> _pickTime(BuildContext context) async {
    final v = await _sheet<TimeFilter>(
      context,
      title: '预计时间',
      options: const [
        (TimeFilter.all, '全部时间'),
        (TimeFilter.le15, '≤ 15 分钟'),
        (TimeFilter.le30, '≤ 30 分钟'),
        (TimeFilter.le60, '≤ 60 分钟'),
        (TimeFilter.over60, '> 60 分钟'),
        (TimeFilter.unknown, '文中未写时间'),
      ],
      current: time,
    );
    if (v != null) onTime(v);
  }

  Future<void> _pickCalories(BuildContext context) async {
    final v = await _sheet<CalorieFilter>(
      context,
      title: '热量',
      options: const [
        (CalorieFilter.all, '全部热量'),
        (CalorieFilter.le300, '≤ 300 大卡'),
        (CalorieFilter.le600, '≤ 600 大卡'),
        (CalorieFilter.le1000, '≤ 1000 大卡'),
        (CalorieFilter.over1000, '> 1000 大卡'),
        (CalorieFilter.unknown, '文中未写热量'),
      ],
      current: calories,
    );
    if (v != null) onCalories(v);
  }

  Future<void> _pickSort(BuildContext context) async {
    final v = await _sheet<RecipeSort>(
      context,
      title: '排序',
      options: const [
        (RecipeSort.name, '按名称'),
        (RecipeSort.difficultyAsc, '难度从低到高'),
        (RecipeSort.difficultyDesc, '难度从高到低'),
        (RecipeSort.timeAsc, '时间从短到长'),
        (RecipeSort.caloriesAsc, '热量从低到高'),
      ],
      current: sort,
    );
    if (v != null) onSort(v);
  }

  Future<T?> _sheet<T>(
    BuildContext context, {
    required String title,
    required List<(T, String)> options,
    required T current,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                for (final (value, label) in options)
                  ListTile(
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: value == current
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: value == current
                        ? const Icon(Icons.check_rounded, color: AppTheme.coral)
                        : null,
                    onTap: () => Navigator.pop(ctx, value),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _diffLabel(DifficultyFilter f) => switch (f) {
        DifficultyFilter.all => '难度',
        DifficultyFilter.easy => '简单',
        DifficultyFilter.medium => '中等',
        DifficultyFilter.hard => '较难',
      };

  static String _timeLabel(TimeFilter f) => switch (f) {
        TimeFilter.all => '时间',
        TimeFilter.le15 => '≤15分',
        TimeFilter.le30 => '≤30分',
        TimeFilter.le60 => '≤60分',
        TimeFilter.over60 => '>60分',
        TimeFilter.unknown => '无时间',
      };

  static String _calLabel(CalorieFilter f) => switch (f) {
        CalorieFilter.all => '热量',
        CalorieFilter.le300 => '≤300卡',
        CalorieFilter.le600 => '≤600卡',
        CalorieFilter.le1000 => '≤1000卡',
        CalorieFilter.over1000 => '>1000卡',
        CalorieFilter.unknown => '无热量',
      };

  static String _sortLabel(RecipeSort s) => switch (s) {
        RecipeSort.name => '排序',
        RecipeSort.difficultyAsc => '难度↑',
        RecipeSort.difficultyDesc => '难度↓',
        RecipeSort.timeAsc => '时间↑',
        RecipeSort.caloriesAsc => '热量↑',
      };
}
