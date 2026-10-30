import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../services/process_image_service.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';
import '../utils/recipe_parser.dart';
import '../widgets/inertia_timer_picker.dart';
import '../widgets/linked_checklist.dart';
import '../widgets/dish_cover_thumb.dart';
import '../widgets/process_image_viewer.dart';
import '../widgets/snap_timeline.dart';
import '../widgets/squeeze_done_button.dart';
import '../widgets/video_recipes_sheet.dart';

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
  late final List<_DetailTab> _detailTabs;
  late final RecipeSection? _mergedIngredients;
  Timer? _timer;
  Duration? _remaining;
  Duration? _total;
  double _favScale = 1;
  bool _hasProcessImage = false;
  /// When true and a process image exists, show text steps instead.
  bool _showTextSteps = false;
  /// Step indices whose timer finished → stamped 「计时已完成」.
  final Set<int> _timerDoneSteps = {};
  /// Which step the running timer belongs to (null = app-bar / free timer).
  int? _activeTimerStep;

  @override
  void initState() {
    super.initState();
    _parsed = parseRecipeMarkdown(widget.recipe.markdown);
    _mergedIngredients = _buildMergedIngredients();
    _detailTabs = _computeTabs();
    _tabs = TabController(length: _detailTabs.length, vsync: this);
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging) setState(() {});
    });
    // Index is loaded in main(); sync check so Module1 does not flash 步骤
    // then swap — that swap broke 做法大图 on the 最近浏览 cold path.
    _hasProcessImage =
        ProcessImageService.instance.hasImage(widget.recipe);
    if (!_hasProcessImage) {
      ProcessImageService.instance.ensureLoaded().then((_) {
        if (!mounted) return;
        final has = ProcessImageService.instance.hasImage(widget.recipe);
        if (has != _hasProcessImage) {
          setState(() => _hasProcessImage = has);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = widget.recipe;
      // Use maybeOf-style access after first frame; avoid depending on
      // HistoryScope during build so addBrowse notify does not rebuild
      // this detail (which previously tore down ProcessImageViewer).
      final scope =
          context.getInheritedWidgetOfExactType<HistoryScope>();
      scope?.notifier?.addBrowse(
        id: r.id,
        title: r.title,
        categoryId: r.categoryId,
        categoryName: r.categoryName,
      );
    });
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

  RecipeSection? get _calcSection {
    for (final s in _parsed.sections) {
      if (s.title.contains('计算')) return s;
    }
    return null;
  }

  /// Merge calc amounts into each ingredient line (鸡蛋 2 个), not dumped below.
  RecipeSection? _buildMergedIngredients() {
    final ing = _ingredientSection;
    final calc = _calcSection;
    if (ing == null && calc == null) return null;

    final calcLines = <String>[];
    if (calc != null) {
      calcLines.addAll(calc.items);
      final body = calc.body.trim();
      if (body.isNotEmpty) {
        for (final line in body.split('\n')) {
          final t = line.trim();
          if (t.isNotEmpty) calcLines.add(t);
        }
      }
    }

    if (ing == null) {
      final fused = fuseIngredientsWithAmounts(
        ingredients: const [],
        calcLines: calcLines,
      );
      return RecipeSection(
        title: '必备原料和工具',
        body: '',
        items: fused.isNotEmpty ? fused : calc!.items,
        isSteps: false,
      );
    }

    if (calcLines.isEmpty) return ing;

    final fused = fuseIngredientsWithAmounts(
      ingredients: ing.items,
      calcLines: calcLines,
    );
    return RecipeSection(
      title: ing.title.isNotEmpty ? ing.title : '必备原料和工具',
      body: '',
      items: fused,
      isSteps: false,
    );
  }

  List<_DetailTab> _computeTabs() {
    final tabs = <_DetailTab>[];
    // Module 1 = 做法大图 (process image / steps fallback)
    tabs.add(_DetailTab(
      label: '做法大图',
      kind: _TabKind.cook,
      section: _stepsSection,
    ));
    // Module 2 = 必备原料和工具 (with calc merged)
    final ing = _mergedIngredients;
    if (ing != null) {
      tabs.add(_DetailTab(
        label: '必备原料和工具',
        kind: _TabKind.ingredients,
        section: ing,
      ));
    }
    // Intentionally omit 「计算」「附加内容」 and other misc sections.
    return tabs;
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

  void _startTimer(Duration d, {int? stepIndex}) {
    _timer?.cancel();
    setState(() {
      _total = d;
      _remaining = d;
      _activeTimerStep = stepIndex;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining == null) return;
      if (_remaining!.inSeconds <= 1) {
        t.cancel();
        final step = _activeTimerStep;
        setState(() {
          _remaining = Duration.zero;
          if (step != null) {
            _timerDoneSteps.add(step);
            _activeTimerStep = null;
          }
        });
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                step != null ? '⏰ 第 ${step + 1} 步计时完成' : '⏰ 计时结束！',
              ),
            ),
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
      _activeTimerStep = null;
    });
  }

  Future<void> _openTimerPicker([Duration? hint, int? stepIndex]) async {
    final d = await showInertiaTimerPicker(
      context,
      initial: hint ?? const Duration(minutes: 5),
    );
    if (d != null) _startTimer(d, stepIndex: stepIndex);
  }

  void _startStepTimer(int stepIndex, Duration hint) {
    _openTimerPicker(hint, stepIndex);
  }

  void _openVideo() {
    HapticFeedback.selectionClick();
    showVideoRecipesSheet(
      context,
      dishName: _parsed.title.isNotEmpty ? _parsed.title : widget.recipe.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = categoryColors[recipe.categoryId] ?? AppTheme.neon;
    final fav = FavoritesScope.of(context).isFavorite(recipe.id);

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
                  expandedHeight: 210,
                  actions: [
                    IconButton(
                      tooltip: '视频做法',
                      onPressed: _openVideo,
                      icon: const Icon(Icons.smart_display_outlined),
                    ),
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
                      padding: const EdgeInsets.fromLTRB(20, 88, 20, 20),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DoodleIcons.categoryIcon(
                                  recipe.categoryId,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  recipe.categoryName,
                                  style: TextStyle(
                                    color: isDarkCard(color)
                                        ? Colors.white
                                        : AppTheme.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Dish logo/cover in navy header (beside title), not a process strip.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DishCoverThumb(
                                recipe: recipe,
                                size: 64,
                                borderRadius: BorderRadius.circular(16),
                                fallbackColor: color.withValues(alpha: 0.35),
                                fallback: Container(
                                  alignment: Alignment.center,
                                  color: color.withValues(alpha: 0.35),
                                  child: DoodleIcons.categoryIcon(
                                    recipe.categoryId,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _parsed.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
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
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: const Icon(
                          Icons.smart_display_rounded,
                          size: 18,
                          color: AppTheme.coral,
                        ),
                        label: const Text('视频做法'),
                        onPressed: _openVideo,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: AppTheme.coral.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_parsed.intro.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                        for (final t in _detailTabs) Tab(text: t.label),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabs,
              children: [
                for (final t in _detailTabs) _buildTabBody(t),
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

  Widget _buildTabBody(_DetailTab t) {
    switch (t.kind) {
      case _TabKind.cook:
        // Module 1: process image when available; otherwise text steps.
        // With image: floating 文字步骤 / 做法大图 toggle.
        final steps = t.section;
        final hasSteps = steps != null && steps.items.isNotEmpty;
        if (_hasProcessImage && !_showTextSteps) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ProcessImageViewer(
                key: ValueKey('process-${widget.recipe.id}'),
                loader: () =>
                    ProcessImageService.instance.loadFor(widget.recipe),
                remoteUrl:
                    ProcessImageService.instance.remoteUrlFor(widget.recipe),
              ),
              if (hasSteps)
                Positioned(
                  right: 14,
                  bottom: 18,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showTextSteps = true);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notes_rounded,
                                size: 18, color: AppTheme.navy),
                            SizedBox(width: 6),
                            Text(
                              '文字步骤',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        if (steps != null && steps.items.isNotEmpty) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _SectionBody(
                section: steps,
                isIngredient: false,
                isSteps: true,
                onPickTimer: _openTimerPicker,
                onStartStepTimer: _startStepTimer,
                timerCompletedSteps: _timerDoneSteps,
              ),
              if (_hasProcessImage)
                Positioned(
                  right: 14,
                  bottom: 18,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(999),
                    color: AppTheme.navy,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showTextSteps = false);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 18, color: AppTheme.cream),
                            SizedBox(width: 6),
                            Text(
                              '做法大图',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.cream,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined,
                  size: 48, color: AppTheme.muted),
              SizedBox(height: 12),
              Text(
                '暂无步骤',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '该菜谱暂无整图做法与文字步骤',
                style: TextStyle(fontSize: 13, color: AppTheme.muted),
              ),
            ],
          ),
        );
      case _TabKind.ingredients:
        return _SectionBody(
          section: t.section!,
          isIngredient: true,
          isSteps: false,
          onPickTimer: _openTimerPicker,
          onAllIngredients: () {
            final idx =
                _detailTabs.indexWhere((e) => e.kind == _TabKind.cook);
            if (idx >= 0) _tabs.animateTo(idx);
          },
        );
    }
  }
}

enum _TabKind { ingredients, cook }

class _DetailTab {
  final String label;
  final _TabKind kind;
  final RecipeSection? section;
  const _DetailTab({
    required this.label,
    required this.kind,
    this.section,
  });
}

class _SectionBody extends StatelessWidget {
  final RecipeSection section;
  final bool isIngredient;
  final bool isSteps;
  final Future<void> Function([Duration? hint, int? stepIndex]) onPickTimer;
  final void Function(int stepIndex, Duration duration)? onStartStepTimer;
  final Set<int> timerCompletedSteps;
  final VoidCallback? onAllIngredients;

  const _SectionBody({
    required this.section,
    required this.isIngredient,
    required this.isSteps,
    required this.onPickTimer,
    this.onStartStepTimer,
    this.timerCompletedSteps = const {},
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
          timerCompletedSteps: timerCompletedSteps,
          onStartTimer: onStartStepTimer ??
              (i, d) {
                onPickTimer(d, i);
              },
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
