import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../services/process_image_service.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';
import '../utils/recipe_parser.dart';
import '../utils/servings_scale.dart';
import '../widgets/inertia_timer_picker.dart';
import '../widgets/linked_checklist.dart';
import '../widgets/dish_cover_thumb.dart';
import '../widgets/process_image_viewer.dart';
import '../widgets/snap_timeline.dart';
import '../widgets/squeeze_done_button.dart';
import '../widgets/video_recipes_sheet.dart';
import '../widgets/bili_tv_icon.dart';
import '../services/timer_alarm_service.dart';

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

  /// Immersive process image — chrome button opens fullscreen via this key.
  final GlobalKey<ProcessImageViewerState> _processViewerKey =
      GlobalKey<ProcessImageViewerState>();

  /// Step indices whose timer finished → stamped 「计时已完成」.
  final Set<int> _timerDoneSteps = {};

  /// Which step the running timer belongs to (null = app-bar / free timer).
  int? _activeTimerStep;

  /// 份数：原料用量按「计算」基准 × 此值。
  int _servings = 1;

  @override
  void initState() {
    super.initState();
    _parsed = parseRecipeMarkdown(widget.recipe.markdown);
    _mergedIngredients = _buildMergedIngredients();
    // Index is loaded in main(); sync check so 做法大图 is first when available.
    _hasProcessImage = ProcessImageService.instance.hasImage(widget.recipe);
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
      final scope = context.getInheritedWidgetOfExactType<HistoryScope>();
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

  RecipeSection? get _extraSection {
    for (final s in _parsed.sections) {
      if (s.title.contains('附加')) return s;
    }
    return null;
  }

  RecipeSection? get _scaledIngredients {
    final base = _mergedIngredients;
    if (base == null) return null;
    if (_servings <= 1) return base;
    return RecipeSection(
      title: base.title,
      body: base.body,
      items: scaleIngredientLines(base.items, _servings),
      isSteps: false,
    );
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
    tabs.add(const _DetailTab(label: '做法大图', kind: _TabKind.processImage));
    // 文字步骤 right after 做法大图.
    final steps = _stepsSection;
    if (steps != null && steps.items.isNotEmpty) {
      tabs.add(_DetailTab(label: '文字步骤', kind: _TabKind.steps, section: steps));
    }
    final ing = _mergedIngredients;
    if (ing != null) {
      tabs.add(
        _DetailTab(label: '必备原料和工具', kind: _TabKind.ingredients, section: ing),
      );
    }
    final extra = _extraSection;
    if (extra != null && _extrasParts(extra).isNotEmpty) {
      tabs.add(
        _DetailTab(label: '附加内容', kind: _TabKind.extras, section: extra),
      );
    }
    return tabs;
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(TimerAlarmService.instance.stop());
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
    unawaited(TimerAlarmService.instance.stop());
    _activeTimerStep = stepIndex;
    _totalN.value = d;
    _remainingN.value = d;
    final body = stepIndex != null
        ? '第 ${stepIndex + 1} 步计时结束，请回来查看'
        : '计时结束，请回来查看';
    unawaited(
      TimerAlarmService.instance.scheduleEndNotification(d, body: body),
    );
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
        final msg = step != null ? '⏰ 第 ${step + 1} 步计时完成' : '⏰ 计时结束！';
        unawaited(TimerAlarmService.instance.ringUntilDismissed(message: msg));
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
    unawaited(TimerAlarmService.instance.stop());
  }

  Future<void> _openTimerPicker([Duration? hint, int? stepIndex]) async {
    final d = await showInertiaTimerPicker(
      context,
      initial: hint ?? const Duration(seconds: 30),
    );
    if (d != null) _startTimer(d, stepIndex: stepIndex);
  }

  void _startStepTimer(int stepIndex, Duration hint) {
    _openTimerPicker(hint, stepIndex);
  }

  void _openVideo() {
    HapticFeedback.selectionClick();
    // Avoid gesture/route contention with an open immersive panel.
    final wasOpen = _panelOpenN.value;
    if (wasOpen) {
      _panelOpenN.value = false;
    }
    final dishName =
        _parsed.title.isNotEmpty ? _parsed.title : widget.recipe.title;
    Future<void>(() async {
      if (wasOpen) {
        // Let the panel reverse animation release the route/gesture arena.
        await Future<void>.delayed(const Duration(milliseconds: 280));
      } else {
        await Future<void>.delayed(Duration.zero);
      }
      if (!mounted) return;
      try {
        await showVideoRecipesSheet(context, dishName: dishName);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('网络不稳定，暂时打不开视频'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  String _formatCookTime(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m > 0 ? '$h 小时 $m 分钟' : '$h 小时';
    }
    return '${d.inMinutes} 分钟';
  }

  List<Widget> _metaChipList({required bool onDark}) {
    final fg = onDark
        ? Colors.white.withValues(alpha: 0.9)
        : AppTheme.ink.withValues(alpha: 0.85);
    final bg = onDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.7);
    final chips = <Widget>[];
    if (_parsed.calories != null) {
      chips.add(
        _MetaChip(
          icon: Icons.local_fire_department_outlined,
          label: '${_parsed.calories} 大卡',
          fg: fg,
          bg: bg,
        ),
      );
    }
    if (_parsed.cookTime != null) {
      chips.add(
        _MetaChip(
          icon: Icons.schedule_rounded,
          label: _formatCookTime(_parsed.cookTime!),
          fg: fg,
          bg: bg,
        ),
      );
    }
    return chips;
  }

  Widget? _metaBlock({required bool onDark, bool vertical = false}) {
    final chips = _metaChipList(onDark: onDark);
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


  /// Left-top meta column under difficulty: calories → time → 文字描述 → 必备原料.
  /// Vertical only; bili TV is a separate centered overlay, not part of this column.
  Widget _buildImmersiveMetaColumn() {
    final chips = _metaChipList(onDark: true);
    Widget? calorie;
    Widget? time;
    if (_parsed.calories != null && chips.isNotEmpty) {
      calorie = chips.first;
      if (_parsed.cookTime != null && chips.length > 1) {
        time = chips[1];
      }
    } else if (_parsed.cookTime != null && chips.isNotEmpty) {
      time = chips.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (calorie != null) ...[
          const SizedBox(height: 6),
          calorie,
        ],
        if (time != null) ...[
          const SizedBox(height: 6),
          time,
        ],
        const SizedBox(height: 6),
        ValueListenableBuilder<int?>(
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
                      _panelOpenN.value = false;
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
      ],
    );
  }

  /// Bili TV at the center of the *dish photo* (top band of the 9:16 process
  /// card), matching immersive [BoxFit.fitWidth] + vertically-centered image.
  /// White icon, no tinted circle plate; not part of the left meta column.
  Widget _buildImmersiveCenteredBiliTv() {
    // Process cards are authored ~720×1289; dish photo occupies roughly the
    // top third — its visual center sits near 15% down the card.
    const processAspect = 720 / 1289; // width / height
    const dishCenterAlongImage = 0.15;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final displayedH = w / processAspect;
        final imgTop = (h - displayedH) / 2;
        final dishCenterY = imgTop + displayedH * dishCenterAlongImage;
        // Whole TV mark enlarged (not just the ▶); hole stays transparent.
        const iconSize = 52.0;
        const pad = 10.0;
        const iconBox = iconSize + pad * 2;

        return Stack(
          children: [
            Positioned(
              top: dishCenterY - iconBox / 2,
              left: 0,
              right: 0,
              height: iconBox,
              child: Center(
                child: Tooltip(
                  message: 'B 站视频做法',
                  child: InkWell(
                    onTap: _openVideo,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(pad),
                      child: BiliTvIcon(
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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

  Widget _buildImmersiveProcessDetail(Recipe recipe, Color color) {
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
                viewerKey: _processViewerKey,
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
          // Dim full-bleed when panel open (no hard edge / dividing line).
          // Chrome + left meta + centered TV sit above this layer.
          Positioned.fill(
            child: ValueListenableBuilder<int?>(
              valueListenable: _immersivePanelN,
              builder: (context, panel, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _panelOpenN,
                  builder: (context, open, _) {
                    if (panel == null || !open) {
                      return const IgnorePointer(child: SizedBox.shrink());
                    }
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _panelOpenN.value = false;
                      },
                      child: const ColoredBox(color: Color(0x33000000)),
                    );
                  },
                );
              },
            ),
          ),
          // App chrome + title / difficulty / calories / cook time.
          // Above the dim so there is no gray band / seam under the status bar.
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
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '查看大图',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _processViewerKey.currentState?.openFullscreen();
                        },
                        icon: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                        ),
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
                        icon: const Icon(
                          Icons.timer_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                        // 难度正下方竖列：卡路里 → 时间 → 文字描述 → 必备原料
                        _buildImmersiveMetaColumn(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bili TV on the dish photo at the top of the process card
          // (not whole-screen center; not in the left meta column).
          Positioned.fill(
            child: _buildImmersiveCenteredBiliTv(),
          ),
          // Sliding content panel — can grow to near the top of the screen.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: topPad,
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
            child: Text('暂无文字描述', style: TextStyle(color: AppTheme.muted)),
          ),
        if (_extraSection case final extra?) ...[
          const SizedBox(height: 18),
          _ExtrasFold(section: extra),
        ],
      ],
    );
  }

  Widget _buildIngredientsPanel() {
    final ing = _scaledIngredients;
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
      servings: _servings,
      onServingsChanged: (v) => setState(() => _servings = v),
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
                      tooltip: 'B 站视频做法',
                      onPressed: _openVideo,
                      icon: const BiliTvIcon(size: 30, color: Colors.white),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
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
                      tabs: [for (final t in _detailTabs) Tab(text: t.label)],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabs,
              children: [for (final t in _detailTabs) _buildTabBody(t)],
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
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: AppTheme.muted,
                ),
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
          section: RecipeSection(
            title: t.section!.title,
            body: t.section!.body,
            items: scaleIngredientLines(t.section!.items, _servings),
            isSteps: false,
          ),
          isIngredient: true,
          isSteps: false,
          onPickTimer: _openTimerPicker,
          servings: _servings,
          onServingsChanged: (v) => setState(() => _servings = v),
          onAllIngredients: () {
            final idx = _detailTabs.indexWhere(
              (e) =>
                  e.kind == _TabKind.steps || e.kind == _TabKind.processImage,
            );
            if (idx >= 0) _tabs.animateTo(idx);
          },
        );
      case _TabKind.extras:
        return _ExtrasBody(section: t.section!);
      case _TabKind.empty:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: AppTheme.muted,
              ),
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

enum _TabKind { processImage, steps, ingredients, extras, empty }

class _DetailTab {
  final String label;
  final _TabKind kind;
  final RecipeSection? section;
  const _DetailTab({required this.label, required this.kind, this.section});
}

class _SectionBody extends StatelessWidget {
  final RecipeSection section;
  final bool isIngredient;
  final bool isSteps;
  final Future<void> Function([Duration? hint, int? stepIndex]) onPickTimer;
  final void Function(int stepIndex, Duration duration)? onStartStepTimer;
  final Set<int> timerCompletedSteps;
  final VoidCallback? onAllIngredients;
  final int servings;
  final ValueChanged<int>? onServingsChanged;

  const _SectionBody({
    required this.section,
    required this.isIngredient,
    required this.isSteps,
    required this.onPickTimer,
    this.onStartStepTimer,
    this.timerCompletedSteps = const {},
    this.onAllIngredients,
    this.servings = 1,
    this.onServingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isSteps && section.items.isNotEmpty) {
      return SnapTimeline(
        steps: section.items,
        durationOf: extractStepDuration,
        timerCompletedSteps: timerCompletedSteps,
        onStartTimer:
            onStartStepTimer ??
            (i, d) {
              onPickTimer(d, i);
            },
      );
    }

    if (isIngredient && section.items.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          if (onServingsChanged != null) ...[
            _ServingsStepper(servings: servings, onChanged: onServingsChanged!),
            const SizedBox(height: 12),
          ],
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppTheme.bg,
      child: Padding(padding: const EdgeInsets.only(top: 4), child: tabBar),
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

  const _ImmersiveTabPills({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget pill(int index, String label) {
      final on = selected == index;
      return Material(
        color: on ? AppTheme.navy : AppTheme.coral,
        borderRadius: BorderRadius.circular(999),
        elevation: on ? 3 : 2,
        child: InkWell(
          onTap: () => onSelect(index),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: on ? AppTheme.neon : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(0, '文字描述'),
        const SizedBox(height: 6),
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
  /// Fraction of the max panel area height (0 = closed, 1 = near screen top).
  static const _half = 0.52;
  static const _full = 1.0;
  static const _dismiss = 0.14;

  late final AnimationController _ctrl;
  /// Height fraction owned by a notifier so drag updates never fight the
  /// open/close AnimationController listener / setState path.
  final ValueNotifier<double> _heightFracN = ValueNotifier<double>(_half);
  bool _dragging = false;
  int? _dragPointer;
  double _lastDragY = 0;
  VelocityTracker? _velocityTracker;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 360),
      value: widget.open ? 0 : 1,
    );
    _ctrl.addStatusListener(_onStatus);
    if (widget.open) {
      _heightFracN.value = _half;
      _ctrl.forward();
    }
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
        _heightFracN.value = _half;
        _ctrl.forward(from: 0);
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    _heightFracN.dispose();
    super.dispose();
  }

  double _visualFrac() {
    final heightFrac = _heightFracN.value;
    if (_dragging) return heightFrac;
    return heightFrac * _ctrl.value;
  }

  void _onPointerDown(PointerDownEvent e) {
    _dragging = true;
    _dragPointer = e.pointer;
    _lastDragY = e.position.dy;
    _velocityTracker = VelocityTracker.withKind(e.kind);
    _velocityTracker!.addPosition(e.timeStamp, e.position);
    _ctrl.stop();
    if (_ctrl.value < 1) {
      _ctrl.value = 1;
    }
  }

  void _onPointerMove(PointerMoveEvent e, double maxH) {
    if (!_dragging || e.pointer != _dragPointer) return;
    _velocityTracker?.addPosition(e.timeStamp, e.position);
    if (maxH <= 0) return;
    final dy = e.position.dy - _lastDragY;
    _lastDragY = e.position.dy;
    final next = (_heightFracN.value - dy / maxH).clamp(0.0, 1.0);
    if (next != _heightFracN.value) {
      _heightFracN.value = next;
    }
  }

  void _onPointerEnd(PointerEvent e) {
    if (!_dragging || e.pointer != _dragPointer) return;
    final v = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    _dragging = false;
    _dragPointer = null;
    _velocityTracker = null;
    _snapAfterDrag(v);
  }

  void _snapAfterDrag(double velocityDy) {
    final heightFrac = _heightFracN.value;
    // Swipe / fling down → drop to bottom and close.
    if (velocityDy > 700 || heightFrac < _dismiss) {
      widget.onClose();
      return;
    }
    // Swipe / fling up → expand to near screen top (full available area).
    if (velocityDy < -500) {
      _heightFracN.value = _full;
      return;
    }
    // Otherwise keep whatever height the user dragged to (any position).
  }

  /// Full-width drag strip via [Listener] — skips the gesture arena so it
  /// does not lose to the immersive [InteractiveViewer] pan/scale below.
  Widget _dragStrip(double maxH) {
    // Larger hit target (~40dp) so the handle is easier to grab; visual bar
    // is only slightly thicker so it does not dominate the sheet chrome.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: (e) => _onPointerMove(e, maxH),
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: Center(
          child: Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.muted.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        return AnimatedBuilder(
          animation: Listenable.merge([_ctrl, _heightFracN]),
          builder: (context, _) {
            final frac = _visualFrac().clamp(0.0, 1.0);
            final h = (maxH * frac).clamp(0.0, maxH);
            final opacity = frac <= 0.02 ? 0.0 : (frac / 0.12).clamp(0.0, 1.0);
            // Below chrome height, only paint the drag bar — avoids Expanded
            // overflow yellow/black flash while the sheet is growing/shrinking.
            final showBody = h >= 132;

            return Align(
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: opacity,
                child: SizedBox(
                  height: h,
                  width: double.infinity,
                  child: Material(
                    color: AppTheme.bg,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: showBody
                        ? Column(
                            children: [
                              _dragStrip(maxH),
                              // Close stays tappable; strip above owns vertical drag.
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: '关闭',
                                  onPressed: widget.onClose,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                              Expanded(child: widget.child),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topCenter,
                            child: _dragStrip(maxH),
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
  final GlobalKey<ProcessImageViewerState> viewerKey;

  const _PinnedProcessImage({
    super.key,
    required this.recipe,
    required this.viewerKey,
  });

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
      key: widget.viewerKey,
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

class _ServingsStepper extends StatelessWidget {
  final int servings;
  final ValueChanged<int> onChanged;
  const _ServingsStepper({required this.servings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant_rounded, size: 18, color: AppTheme.coral),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '份数（按计算比例）',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          _RoundBtn(
            icon: Icons.remove_rounded,
            onTap: servings > 1 ? () => onChanged(servings - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$servings',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              ),
            ),
          ),
          _RoundBtn(
            icon: Icons.add_rounded,
            onTap: servings < 20 ? () => onChanged(servings + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null
          ? AppTheme.navy.withValues(alpha: 0.06)
          : AppTheme.neon.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppTheme.navy),
        ),
      ),
    );
  }
}

class _ExtrasBody extends StatelessWidget {
  final RecipeSection section;
  const _ExtrasBody({required this.section});

  @override
  Widget build(BuildContext context) {
    final parts = _extrasParts(section);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        const Text(
          '注意点 · 小技巧 · 参考',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 12),
        if (parts.isEmpty)
          const Text('暂无附加内容', style: TextStyle(color: AppTheme.muted))
        else
          _ExtrasContent(parts: parts, fontSize: 15),
      ],
    );
  }
}

class _ExtrasFold extends StatelessWidget {
  final RecipeSection section;
  const _ExtrasFold({required this.section});

  @override
  Widget build(BuildContext context) {
    final parts = _extrasParts(section);
    if (parts.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text(
          '附加内容',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        children: [_ExtrasContent(parts: parts, fontSize: 14)],
      ),
    );
  }
}

/// Coral-dot rows + optional prose — avoids flutter_markdown listIndent skew.
class _ExtrasContent extends StatelessWidget {
  final List<_ExtrasPart> parts;
  final double fontSize;
  const _ExtrasContent({required this.parts, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          if (parts[i].isBullet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: fontSize * 0.55),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    parts[i].text,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.5,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              parts[i].text,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.55,
                color: AppTheme.ink,
              ),
            ),
        ],
      ],
    );
  }
}

class _ExtrasPart {
  final String text;
  final bool isBullet;
  const _ExtrasPart(this.text, {required this.isBullet});
}

List<_ExtrasPart> _extrasParts(RecipeSection section) {
  final parts = <_ExtrasPart>[];
  final body = section.body.trim();
  if (body.isNotEmpty) {
    final cleaned = _stripHowtoCookContributionBoilerplate(body);
    final buf = <String>[];
    void flushProse() {
      final prose = buf.join('\n').trim();
      buf.clear();
      if (prose.isNotEmpty) {
        parts.add(_ExtrasPart(prose, isBullet: false));
      }
    }

    for (final raw in cleaned.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushProse();
        continue;
      }
      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flushProse();
        final text = bullet.group(1)!.trim();
        if (text.isEmpty) continue;
        if (_isHowtoCookContributionLine(text)) continue;
        parts.add(_ExtrasPart(text, isBullet: true));
      } else {
        buf.add(trimmed);
      }
    }
    flushProse();
  }
  for (final item in section.items) {
    final itemText = item.trim();
    if (itemText.isEmpty) continue;
    if (_isHowtoCookContributionLine(itemText)) continue;
    parts.add(_ExtrasPart(itemText, isBullet: true));
  }
  return parts;
}

/// Build extras markdown and strip HowToCook upstream contribution boilerplate.
String extrasMarkdownOf(RecipeSection section) {
  final buf = StringBuffer();
  if (section.body.trim().isNotEmpty) {
    buf.writeln(section.body.trim());
  }
  for (final item in section.items) {
    final itemText = item.trim();
    if (_isHowtoCookContributionLine(itemText)) continue;
    buf.writeln('- $item');
  }
  return _stripHowtoCookContributionBoilerplate(buf.toString()).trim();
}

bool _isHowtoCookContributionLine(String t) {
  if (!t.contains('如果您遵循本指南')) return false;
  return t.contains('Issue') ||
      t.contains('Pull request') ||
      t.contains('pull request') ||
      t.contains('Pull Request') ||
      t.contains('PR');
}

String _stripHowtoCookContributionBoilerplate(String text) {
  final lines = text.split('\n');
  final kept = <String>[];
  for (final line in lines) {
    final t = line.trim();
    // Whole-line / bullet contribution CTA from upstream recipes.
    if (_isHowtoCookContributionLine(
      t.replaceFirst(RegExp(r'^[-*+]\s+'), ''),
    )) {
      continue;
    }
    if (_isHowtoCookContributionLine(t)) continue;
    kept.add(line);
  }
  var out = kept.join('\n');
  // Paragraph form that may span one long line.
  out = out.replaceAll(
    RegExp(
      r'如果您遵循本指南[^\n]*?(?:Issue|issue)[^\n]*?(?:Pull\s*[Rr]equest|pull\s*request|PR)[^\n]*',
    ),
    '',
  );
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return out.trim();
}
