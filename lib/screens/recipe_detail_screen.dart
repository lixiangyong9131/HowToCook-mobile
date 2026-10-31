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
  /// Isolated from setState so process image / header do not rebuild every tick.
  final ValueNotifier<Duration?> _remainingN = ValueNotifier<Duration?>(null);
  final ValueNotifier<Duration?> _totalN = ValueNotifier<Duration?>(null);
  final ValueNotifier<double> _favScaleN = ValueNotifier<double>(1);
  bool _hasProcessImage = false;
  /// Immersive side tabs: null = image only, 0 = 文字描述, 1 = 必备原料.
  /// ValueNotifier so toggling panels / 喜欢 chrome never setStates this
  /// screen (which used to recreate ProcessImageViewer loader → flicker).
  final ValueNotifier<int?> _immersivePanelN = ValueNotifier<int?>(null);
  /// Drives slide; kept true until exit animation finishes.
  final ValueNotifier<bool> _panelOpenN = ValueNotifier<bool>(false);
  /// Step indices whose timer finished → stamped 「计时已完成」.
  final Set<int> _timerDoneSteps = {};
  /// Which step the running timer belongs to (null = app-bar / free timer).
  int? _activeTimerStep;

  @override
  void initState() {
    super.initState();
    _parsed = parseRecipeMarkdown(widget.recipe.markdown);
    _mergedIngredients = _buildMergedIngredients();
    // Index is loaded in main(); sync check so 做法大图 is first when available.
    _hasProcessImage =
        ProcessImageService.instance.hasImage(widget.recipe);
    _detailTabs = _computeTabs();
    _tabs = TabController(length: _detailTabs.length, vsync: this);
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging) setState(() {});
    });
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
    // 做法大图 always first (image viewer or empty placeholder).
    tabs.add(const _DetailTab(
      label: '做法大图',
      kind: _TabKind.processImage,
    ));
    // 文字步骤 right after 做法大图.
    final steps = _stepsSection;
    if (steps != null && steps.items.isNotEmpty) {
      tabs.add(_DetailTab(
        label: '文字步骤',
        kind: _TabKind.steps,
        section: steps,
      ));
    }
    final ing = _mergedIngredients;
    if (ing != null) {
      tabs.add(_DetailTab(
        label: '必备原料和工具',
        kind: _TabKind.ingredients,
        section: ing,
      ));
    }
    return tabs;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingN.dispose();
    _favScaleN.dispose();
    _totalN.dispose();
    _immersivePanelN.dispose();
    _panelOpenN.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    _favScaleN.value = 1.35;
    await FavoritesScope.of(context).toggle(widget.recipe.id);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (mounted) _favScaleN.value = 1;
  }

  void _startTimer(Duration d, {int? stepIndex}) {
    _timer?.cancel();
    _activeTimerStep = stepIndex;
    _totalN.value = d;
    _remainingN.value = d;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final rem = _remainingN.value;
      if (rem == null) return;
      if (rem.inSeconds <= 1) {
        t.cancel();
        final step = _activeTimerStep;
        _remainingN.value = Duration.zero;
        if (step != null) {
          _activeTimerStep = null;
          // Stamp only — avoids rebuilding process image every tick.
          if (mounted) {
            setState(() => _timerDoneSteps.add(step));
          }
        }
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
        _remainingN.value = rem - const Duration(seconds: 1);
      }
    });
  }

  void _closeTimer() {
    _timer?.cancel();
    _activeTimerStep = null;
    _remainingN.value = null;
    _totalN.value = null;
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

  String _formatCookTime(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m > 0 ? '$h 小时 $m 分钟' : '$h 小时';
    }
    return '${d.inMinutes} 分钟';
  }

  Widget? _metaBlock({required bool onDark, bool vertical = false}) {
    final fg = onDark
        ? Colors.white.withValues(alpha: 0.9)
        : AppTheme.ink.withValues(alpha: 0.85);
    final bg = onDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.7);
    final chips = <Widget>[];
    if (_parsed.calories != null) {
      chips.add(_MetaChip(
        icon: Icons.local_fire_department_outlined,
        label: '${_parsed.calories} 大卡',
        fg: fg,
        bg: bg,
      ));
    }
    if (_parsed.cookTime != null) {
      chips.add(_MetaChip(
        icon: Icons.schedule_rounded,
        label: _formatCookTime(_parsed.cookTime!),
        fg: fg,
        bg: bg,
      ));
    }
    if (chips.isEmpty) return null;
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            chips[i],
          ],
        ],
      );
    }
    return Wrap(spacing: 8, runSpacing: 6, children: chips);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = categoryColors[recipe.categoryId] ?? AppTheme.neon;
    // FavoritesScope is read only in [_FavoriteActionButton] so toggling
    // 喜欢 does not rebuild ProcessImageViewer (avoids immersive flicker).

    if (_hasProcessImage) {
      return _buildImmersiveProcessDetail(recipe, color);
    }
    return _buildClassicDetail(recipe, color);
  }

  Widget _buildImmersiveProcessDetail(
    Recipe recipe,
    Color color,
  ) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-page process image — pinned so chrome setState / fav
          // InheritedNotifier updates do not repaint this layer.
          Positioned.fill(
            child: RepaintBoundary(
              child: _PinnedProcessImage(
                key: ValueKey('process-pinned-${recipe.id}'),
                recipe: recipe,
              ),
            ),
          ),
          // Light top scrim only — image fills the page (no letterbox bars).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // App chrome + title / difficulty / calories / cook time.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '视频做法',
                        onPressed: _openVideo,
                        icon: const Icon(Icons.smart_display_outlined,
                            color: Colors.white),
                      ),
                      _FavoriteActionButton(
                        recipeId: recipe.id,
                        scaleListenable: _favScaleN,
                        onToggle: _toggleFavorite,
                        lightChrome: true,
                      ),
                      IconButton(
                        tooltip: '计时',
                        onPressed: () => _openTimerPicker(),
                        icon: const Icon(Icons.timer_outlined,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 118, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
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
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                recipe.categoryName,
                                style: TextStyle(
                                  color: isDarkCard(color)
                                      ? Colors.white
                                      : AppTheme.ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _parsed.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            height: 1.12,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        if (_parsed.difficulty != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '难度 ${'★' * _parsed.difficulty!}${'☆' * (5 - _parsed.difficulty!)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_metaBlock(onDark: true, vertical: true)
                            case final meta?) ...[
                          const SizedBox(height: 8),
                          meta,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tabs + panel listen via ValueNotifier — parent setState not used,
          // so the pinned process image subtree is not rebuilt.
          Positioned(
            top: topPad + 52,
            right: 12,
            child: ValueListenableBuilder<int?>(
              valueListenable: _immersivePanelN,
              builder: (context, panel, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _panelOpenN,
                  builder: (context, open, _) {
                    return _ImmersiveTabPills(
                      selected: open ? panel : null,
                      onSelect: (i) {
                        HapticFeedback.selectionClick();
                        if (panel == i && open) {
                          _panelOpenN.value = false; // animate closed
                        } else {
                          _immersivePanelN.value = i;
                          _panelOpenN.value = true;
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Sliding content panel — Positioned must stay a direct Stack child.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.sizeOf(context).height * 0.32,
            child: ValueListenableBuilder<int?>(
              valueListenable: _immersivePanelN,
              builder: (context, panel, _) {
                if (panel == null) {
                  return const IgnorePointer(child: SizedBox.shrink());
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: _panelOpenN,
                  builder: (context, open, _) {
                    return _ImmersiveContentPanel(
                      open: open,
                      onClose: () => _panelOpenN.value = false,
                      onClosed: () {
                        if (!mounted) return;
                        _immersivePanelN.value = null;
                        _panelOpenN.value = false;
                      },
                      child: panel == 0
                          ? _buildDescPanel()
                          : _buildIngredientsPanel(),
                    );
                  },
                );
              },
            ),
          ),
          ValueListenableBuilder<Duration?>(
            valueListenable: _remainingN,
            builder: (context, remaining, _) {
              if (remaining == null) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RunningTimerBar(
                  remaining: remaining,
                  total: _totalN.value ?? remaining,
                  onClose: _closeTimer,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDescPanel() {
    final intro = _parsed.intro
        .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
        .trim();
    final steps = _stepsSection;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        const Text(
          '文字描述',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        if (intro.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            intro,
            style: const TextStyle(
              height: 1.55,
              color: AppTheme.ink,
              fontSize: 15,
            ),
          ),
        ],
        if (steps != null && steps.items.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            '文字步骤',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          // Reuse timeline but unconstrained height via shrink-wrap list.
          ...[
            for (var i = 0; i < steps.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E8ED)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.neon.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          steps.items[i],
                          style: const TextStyle(height: 1.45, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
        if (intro.isEmpty && (steps == null || steps.items.isEmpty))
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              '暂无文字描述',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
      ],
    );
  }

  Widget _buildIngredientsPanel() {
    final ing = _mergedIngredients;
    if (ing == null) {
      return const Center(
        child: Text('暂无原料信息', style: TextStyle(color: AppTheme.muted)),
      );
    }
    return _SectionBody(
      section: ing,
      isIngredient: true,
      isSteps: false,
      onPickTimer: _openTimerPicker,
    );
  }

  Widget _buildClassicDetail(Recipe recipe, Color color) {
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
                  expandedHeight: 248,
                  actions: [
                    IconButton(
                      tooltip: '视频做法',
                      onPressed: _openVideo,
                      icon: const Icon(Icons.smart_display_outlined),
                    ),
                    _FavoriteActionButton(
                      recipeId: recipe.id,
                      scaleListenable: _favScaleN,
                      onToggle: _toggleFavorite,
                      lightChrome: true,
                    ),
                    IconButton(
                      tooltip: '计时',
                      onPressed: () => _openTimerPicker(),
                      icon: const Icon(Icons.timer_outlined),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        DishHeaderBackdrop(
                          recipe: recipe,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 88, 20, 56),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (_metaBlock(onDark: true, vertical: true)
                                    case final meta?) ...[
                                  const SizedBox(height: 8),
                                  meta,
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
          ValueListenableBuilder<Duration?>(
            valueListenable: _remainingN,
            builder: (context, remaining, _) {
              if (remaining == null) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RunningTimerBar(
                  remaining: remaining,
                  total: _totalN.value ?? remaining,
                  onClose: _closeTimer,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(_DetailTab t) {
    switch (t.kind) {
      case _TabKind.processImage:
        if (!_hasProcessImage) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 48, color: AppTheme.muted),
                SizedBox(height: 12),
                Text(
                  '暂无做法大图',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '可切换到「文字步骤」查看做法',
                  style: TextStyle(fontSize: 13, color: AppTheme.muted),
                ),
              ],
            ),
          );
        }
        return ProcessImageViewer(
          key: ValueKey('process-${widget.recipe.id}'),
          loader: () => ProcessImageService.instance.loadFor(widget.recipe),
          remoteUrl: ProcessImageService.instance.remoteUrlFor(widget.recipe),
        );
      case _TabKind.steps:
        return _SectionBody(
          section: t.section!,
          isIngredient: false,
          isSteps: true,
          onPickTimer: _openTimerPicker,
          onStartStepTimer: _startStepTimer,
          timerCompletedSteps: _timerDoneSteps,
        );
      case _TabKind.ingredients:
        return _SectionBody(
          section: t.section!,
          isIngredient: true,
          isSteps: false,
          onPickTimer: _openTimerPicker,
          onAllIngredients: () {
            final idx = _detailTabs.indexWhere(
              (e) =>
                  e.kind == _TabKind.steps || e.kind == _TabKind.processImage,
            );
            if (idx >= 0) _tabs.animateTo(idx);
          },
        );
      case _TabKind.empty:
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
    }
  }
}

enum _TabKind { processImage, steps, ingredients, empty }

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
      return SnapTimeline(
        steps: section.items,
        durationOf: extractStepDuration,
        timerCompletedSteps: timerCompletedSteps,
        onStartTimer: onStartStepTimer ??
            (i, d) {
              onPickTimer(d, i);
            },
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


class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveTabPills extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelect;

  const _ImmersiveTabPills({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill(int index, String label) {
      final on = selected == index;
      return GestureDetector(
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: on ? 0 : 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? AppTheme.ink : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        pill(0, '文字描述'),
        const SizedBox(height: 8),
        pill(1, '必备原料'),
      ],
    );
  }
}

class _ImmersiveContentPanel extends StatefulWidget {
  final Widget child;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onClosed;

  const _ImmersiveContentPanel({
    required this.child,
    required this.open,
    required this.onClose,
    required this.onClosed,
  });

  @override
  State<_ImmersiveContentPanel> createState() => _ImmersiveContentPanelState();
}

class _ImmersiveContentPanelState extends State<_ImmersiveContentPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 420),
      value: widget.open ? 0 : 1,
    );
    _t = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    if (widget.open) {
      _ctrl.forward();
    }
    _ctrl.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.dismissed) {
      widget.onClosed();
    }
  }

  @override
  void didUpdateWidget(covariant _ImmersiveContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 56),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, color: AppTheme.muted),
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}


/// Owns [FavoritesScope] subscription so parent detail does not rebuild
/// (and flicker) the process-image layer when 喜欢 is toggled.
class _FavoriteActionButton extends StatelessWidget {
  final String recipeId;
  final ValueNotifier<double> scaleListenable;
  final Future<void> Function() onToggle;
  final bool lightChrome;

  const _FavoriteActionButton({
    required this.recipeId,
    required this.scaleListenable,
    required this.onToggle,
    this.lightChrome = false,
  });

  @override
  Widget build(BuildContext context) {
    final fav = FavoritesScope.of(context).isFavorite(recipeId);
    final idleColor = lightChrome ? Colors.white : AppTheme.ink;
    return ValueListenableBuilder<double>(
      valueListenable: scaleListenable,
      builder: (context, scale, _) {
        return IconButton(
          tooltip: fav ? '取消收藏' : '收藏',
          onPressed: onToggle,
          icon: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? AppTheme.coral : idleColor,
            ),
          ),
        );
      },
    );
  }
}

/// Keeps [ProcessImageViewer] state stable across parent chrome rebuilds.
class _PinnedProcessImage extends StatefulWidget {
  final Recipe recipe;

  const _PinnedProcessImage({super.key, required this.recipe});

  @override
  State<_PinnedProcessImage> createState() => _PinnedProcessImageState();
}

class _PinnedProcessImageState extends State<_PinnedProcessImage>
    with AutomaticKeepAliveClientMixin {
  late final Future<ProcessImageBytes?> Function() _loader;
  late final String? _remoteUrl;
  late final Widget _viewer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    // Freeze loader / viewer so parent rebuilds cannot swap closures and
    // trigger ProcessImageViewer.didUpdateWidget → image reload flicker.
    _loader = () => ProcessImageService.instance.loadFor(recipe);
    _remoteUrl = ProcessImageService.instance.remoteUrlFor(recipe);
    _viewer = ProcessImageViewer(
      key: ValueKey('process-immersive-${recipe.id}'),
      immersive: true,
      loader: _loader,
      remoteUrl: _remoteUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _viewer;
  }
}
