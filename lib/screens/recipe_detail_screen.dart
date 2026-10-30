import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../utils/recipe_parser.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late final ParsedRecipe _parsed;
  late final TabController _tabs;
  int _stepIndex = 0;
  Timer? _timer;
  Duration? _remaining;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _parsed = parseRecipeMarkdown(widget.recipe.markdown);
    final len = _parsed.sections.isEmpty ? 1 : _parsed.sections.length;
    _tabs = TabController(length: len, vsync: this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    FavoritesScope.of(context).toggle(widget.recipe.id);
  }

  void _startTimer(Duration d) {
    _timer?.cancel();
    setState(() {
      _total = d;
      _remaining = d;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining == null) return;
      if (_remaining!.inSeconds <= 1) {
        t.cancel();
        setState(() => _remaining = Duration.zero);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⏰ 计时结束！')),
          );
        }
      } else {
        setState(() => _remaining = _remaining! - const Duration(seconds: 1));
      }
    });
  }

  void _closeTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = null;
      _total = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = categoryColors[recipe.categoryId] ?? AppTheme.accent;
    final fav = FavoritesScope.of(context).isFavorite(recipe.id);
    final sections = _parsed.sections;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 168,
              actions: [
                IconButton(
                  tooltip: fav ? '取消收藏' : '收藏',
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    fav ? Icons.favorite : Icons.favorite_border,
                    color: fav ? Colors.redAccent : null,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.95),
                        color.withValues(alpha: 0.65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${categoryEmojis[recipe.categoryId] ?? ''} ${recipe.categoryName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _parsed.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_parsed.difficulty != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '难度 ${'★' * _parsed.difficulty!}${'☆' * (5 - _parsed.difficulty!)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_parsed.intro.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    _parsed.intro.replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '').trim(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                          color: Colors.black87,
                        ),
                  ),
                ),
              ),
            if (sections.isNotEmpty)
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: color,
                    indicatorColor: color,
                    tabs: [
                      for (final s in sections) Tab(text: s.title),
                    ],
                  ),
                ),
              ),
          ];
        },
        body: sections.isEmpty
            ? const Center(child: Text('暂无分节内容'))
            : TabBarView(
                controller: _tabs,
                children: [
                  for (final s in sections) _SectionView(
                    section: s,
                    accent: color,
                    stepIndex: _stepIndex,
                    onStepChanged: (i) => setState(() => _stepIndex = i),
                    onStartTimer: _startTimer,
                  ),
                ],
              ),
      ),
      bottomSheet: _remaining == null
          ? null
          : _TimerBar(
              remaining: _remaining!,
              total: _total ?? _remaining!,
              onClose: _closeTimer,
              color: color,
            ),
    );
  }
}

class _SectionView extends StatelessWidget {
  final RecipeSection section;
  final Color accent;
  final int stepIndex;
  final ValueChanged<int> onStepChanged;
  final ValueChanged<Duration> onStartTimer;

  const _SectionView({
    required this.section,
    required this.accent,
    required this.stepIndex,
    required this.onStepChanged,
    required this.onStartTimer,
  });

  @override
  Widget build(BuildContext context) {
    if (section.isSteps && section.items.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: section.items.length,
        itemBuilder: (context, i) {
          final step = section.items[i];
          final active = i == stepIndex;
          final done = i < stepIndex;
          final duration = extractStepDuration(step);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? accent : const Color(0xFFFFE0B2),
                  width: active ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: done
                            ? Colors.green
                            : active
                                ? accent
                                : Colors.grey.shade300,
                        child: done
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: active ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '').trim(),
                          style: TextStyle(
                            height: 1.5,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (active) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (i < section.items.length - 1)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                            ),
                            onPressed: () => onStepChanged(i + 1),
                            child: const Text('下一步'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => onStepChanged(0),
                            child: const Text('重新做一次'),
                          ),
                        if (duration != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => onStartTimer(duration),
                            icon: const Icon(Icons.hourglass_bottom, size: 18),
                            label: Text(_fmt(duration)),
                          ),
                        ],
                      ],
                    ),
                  ] else if (!done)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => onStepChanged(i),
                        child: const Text('跳到此步'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (section.items.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: section.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 8, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.items[i],
                    style: const TextStyle(height: 1.45, fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Text(
        section.body,
        style: const TextStyle(height: 1.55, fontSize: 15),
      ),
    );
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) return '${d.inHours}小时';
    if (d.inMinutes > 0) return '${d.inMinutes}分钟';
    return '${d.inSeconds}秒';
  }
}

class _TimerBar extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final VoidCallback onClose;
  final Color color;

  const _TimerBar({
    required this.remaining,
    required this.total,
    required this.onClose,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds == 0
        ? 0.0
        : 1 - remaining.inMilliseconds / total.inMilliseconds;
    final mm = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = remaining.inHours;
    final label = hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';

    return Material(
      elevation: 12,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(Icons.timer, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('倒计时  $label',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onClose, child: const Text('关闭')),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(color: AppTheme.cream, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
