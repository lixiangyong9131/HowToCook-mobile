import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../utils/recipe_parser.dart';
import '../widgets/inertia_timer_picker.dart';
import '../widgets/linked_checklist.dart';
import '../widgets/snap_timeline.dart';
import '../widgets/squeeze_done_button.dart';

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
  Timer? _timer;
  Duration? _remaining;
  Duration? _total;
  double _favScale = 1;

  @override
  void initState() {
    super.initState();
    _parsed = parseRecipeMarkdown(widget.recipe.markdown);
    final len = _parsed.sections.isEmpty ? 1 : _parsed.sections.length;
    _tabs = TabController(length: len, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = widget.recipe;
      HistoryScope.of(context).addBrowse(
        id: r.id,
        title: r.title,
        categoryId: r.categoryId,
        categoryName: r.categoryName,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    setState(() => _favScale = 1.35);
    await FavoritesScope.of(context).toggle(widget.recipe.id);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (mounted) setState(() => _favScale = 1);
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
          HapticFeedback.heavyImpact();
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

  Future<void> _openTimerPicker([Duration? hint]) async {
    final d = await showInertiaTimerPicker(
      context,
      initial: hint ?? const Duration(minutes: 5),
    );
    if (d != null) _startTimer(d);
  }

  RecipeSection? get _ingredientSection {
    for (final s in _parsed.sections) {
      if (s.title.contains('原料') || s.title.contains('用料')) return s;
    }
    return null;
  }

  RecipeSection? get _stepsSection {
    for (final s in _parsed.sections) {
      if (s.isSteps) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = categoryColors[recipe.categoryId] ?? AppTheme.neon;
    final fav = FavoritesScope.of(context).isFavorite(recipe.id);
    final sections = _parsed.sections;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, inner) {
              return [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppTheme.blackCard,
                  foregroundColor: Colors.white,
                  iconTheme: const IconThemeData(color: Colors.white),
                  expandedHeight: 200,
                  actions: [
                    IconButton(
                      tooltip: fav ? '取消收藏' : '收藏',
                      onPressed: _toggleFavorite,
                      icon: AnimatedScale(
                        scale: _favScale,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          fav ? Icons.favorite : Icons.favorite_border,
                          color: fav ? AppTheme.coral : Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '计时',
                      onPressed: () => _openTimerPicker(),
                      icon: const Icon(Icons.timer_outlined),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: AppTheme.blackCard,
                      padding: const EdgeInsets.fromLTRB(20, 88, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${categoryEmojis[recipe.categoryId] ?? ''} ${recipe.categoryName}',
                              style: TextStyle(
                                color: isDarkCard(color)
                                    ? Colors.white
                                    : AppTheme.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _parsed.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              height: 1.1,
                            ),
                          ),
                          if (_parsed.difficulty != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '难度 ${'★' * _parsed.difficulty!}${'☆' * (5 - _parsed.difficulty!)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
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
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Text(
                        _parsed.intro
                            .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
                            .trim(),
                        style: const TextStyle(
                          height: 1.55,
                          color: AppTheme.ink,
                          fontSize: 15,
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
                        labelColor: AppTheme.ink,
                        unselectedLabelColor: AppTheme.muted,
                        indicatorColor: AppTheme.neon,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
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
                      for (final s in sections)
                        _SectionBody(
                          section: s,
                          isIngredient: identical(s, _ingredientSection) ||
                              s.title.contains('原料') ||
                              s.title.contains('用料'),
                          isSteps: s.isSteps,
                          onPickTimer: _openTimerPicker,
                          onAllIngredients: () {
                            // Celebrate with squeeze button overlay snack via messenger is enough;
                            // also jump toward steps if present.
                            final steps = _stepsSection;
                            if (steps != null) {
                              final idx = sections.indexOf(steps);
                              if (idx >= 0) _tabs.animateTo(idx);
                            }
                          },
                        ),
                    ],
                  ),
          ),
          if (_remaining != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RunningTimerBar(
                remaining: _remaining!,
                total: _total ?? _remaining!,
                onClose: _closeTimer,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final RecipeSection section;
  final bool isIngredient;
  final bool isSteps;
  final Future<void> Function([Duration? hint]) onPickTimer;
  final VoidCallback? onAllIngredients;

  const _SectionBody({
    required this.section,
    required this.isIngredient,
    required this.isSteps,
    required this.onPickTimer,
    this.onAllIngredients,
  });

  @override
  Widget build(BuildContext context) {
    if (isSteps && section.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        child: SnapTimeline(
          steps: section.items,
          durationOf: extractStepDuration,
          onPickTimer: (d) => onPickTimer(d),
        ),
      );
    }

    if (isIngredient && section.items.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          LinkedChecklist(
            items: section.items,
            title: '原料进度',
            onAllDone: (_) {
              HapticFeedback.mediumImpact();
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.blackCard,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '原料已备齐',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '可以开始操作了',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 180,
                          child: SqueezeDoneButton(
                            label: '去烹饪',
                            resettable: false,
                            onCompleted: () {
                              Navigator.pop(ctx);
                              onAllIngredients?.call();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
    }

    if (section.items.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        itemCount: section.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8E8ED)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.neon,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Text(
        section.body,
        style: const TextStyle(height: 1.55, fontSize: 15),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 8;
  @override
  double get maxExtent => tabBar.preferredSize.height + 8;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: AppTheme.bg,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
