import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Apple Wallet–style category stack.
///
/// **Folded:** custom inertia wheel (NOT PageView). Drag + fling uses
/// [FrictionSimulation] so velocity can coast across **many** cards, then
/// spring-snaps to the nearest index. Avoids PageView's forced
/// [PageScrollPhysics] (±1 page) and nested-CustomScrollView fights.
/// Center card sharp/larger; neighbors blur/fade (name readable).
///
/// **Expanded:** fan-out with the same slow easeOutCubic as collapse.
class StackedCategoryCards extends StatefulWidget {
  final List<CategoryInfo> categories;
  final Map<String, int> counts;
  final ValueChanged<CategoryInfo> onOpen;
  final bool initiallyExpanded;
  final bool autoFanOnMount;
  final bool openOnSwipeSettle;
  final bool showExpandButton;

  const StackedCategoryCards({
    super.key,
    required this.categories,
    required this.counts,
    required this.onOpen,
    this.initiallyExpanded = false,
    this.autoFanOnMount = false,
    this.openOnSwipeSettle = false,
    this.showExpandButton = true,
  });

  @override
  State<StackedCategoryCards> createState() => _StackedCategoryCardsState();
}

class _StackedCategoryCardsState extends State<StackedCategoryCards>
    with TickerProviderStateMixin {
  static const _cardH = 104.0;
  static const _gap = 12.0;
  static const _peek = 28.0;
  /// Pixels of drag ≈ one card step (folded wheel).
  static const _itemExtent = 92.0;
  static const _fanDuration = Duration(milliseconds: 480);
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 20,
  );

  late bool _expanded;
  late final AnimationController _fanCtrl;
  late final CurvedAnimation _fanCurve;

  /// Fractional focus index (0 … n-1). Drives folded wheel.
  double _page = 0;
  int _settledFocus = 0;

  AnimationController? _ballisticCtrl;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && !widget.autoFanOnMount;
    _fanCtrl = AnimationController(
      vsync: this,
      duration: _fanDuration,
      value: _expanded ? 1 : 0,
    );
    _fanCurve = CurvedAnimation(
      parent: _fanCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    if (widget.autoFanOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        _expand();
      });
    }
  }

  @override
  void didUpdateWidget(covariant StackedCategoryCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories.length != widget.categories.length) {
      final max = (widget.categories.length - 1).clamp(0, 9999).toDouble();
      _page = _page.clamp(0.0, max);
      _settledFocus = _page.round().clamp(0, widget.categories.length - 1);
    }
  }

  @override
  void dispose() {
    _stopBallistic();
    _fanCurve.dispose();
    _fanCtrl.dispose();
    super.dispose();
  }

  int get _n => widget.categories.length;

  void _stopBallistic() {
    _ballisticCtrl?.dispose();
    _ballisticCtrl = null;
  }

  Future<void> _expand() async {
    if (_expanded && _fanCtrl.value >= 1) return;
    _stopBallistic();
    HapticFeedback.mediumImpact();
    setState(() => _expanded = true);
    await _fanCtrl.forward();
  }

  Future<void> _collapse() async {
    if (!_expanded && _fanCtrl.value <= 0) return;
    HapticFeedback.selectionClick();
    await _fanCtrl.reverse();
    if (!mounted) return;
    setState(() => _expanded = false);
  }

  void _toggle() => _expanded ? _collapse() : _expand();

  int _paletteIndex(CategoryInfo cat) {
    final i = widget.categories.indexWhere((c) => c.id == cat.id);
    return i < 0 ? 0 : i;
  }

  void _onSettled(int i) {
    if (i == _settledFocus) return;
    HapticFeedback.selectionClick();
    _settledFocus = i;
    if (widget.openOnSwipeSettle && _n > 0) {
      widget.onOpen(widget.categories[i]);
    }
  }

  void _onWheelDragUpdate(DragUpdateDetails d) {
    if (_n < 2) return;
    _stopBallistic();
    // Finger up (negative dy) → next cards (page increases).
    setState(() {
      _page = (_page - d.delta.dy / _itemExtent).clamp(0.0, (_n - 1).toDouble());
    });
  }

  void _onWheelDragEnd(DragEndDetails d) {
    if (_n < 2) return;
    final pxPerSec = -(d.primaryVelocity ?? 0);
    // Convert px/s → pages/s. High fling ⇒ many cards of coast.
    final pagesPerSec = pxPerSec / _itemExtent;
    _startBallistic(pagesPerSec);
  }

  /// Friction coast (can pass many cards) → spring snap to nearest index.
  void _startBallistic(double velocityPagesPerSec) {
    _stopBallistic();
    final maxPage = (_n - 1).toDouble();

    final friction = FrictionSimulation(
      0.085, // low drag ⇒ long multi-card coast
      _page,
      velocityPagesPerSec,
    );
    var coastEnd = friction.x(double.infinity);
    if (velocityPagesPerSec.abs() < 0.35) {
      coastEnd = _page;
    }
    final target = coastEnd.clamp(0.0, maxPage).roundToDouble();

    final useFriction =
        (coastEnd - _page).abs() > 0.55 && velocityPagesPerSec.abs() >= 0.35;

    if (!useFriction) {
      _springTo(target, velocityPagesPerSec);
      return;
    }

    final settleSecs = _frictionSettleSeconds(friction).clamp(0.08, 2.2);
    var handedOff = false;

    _ballisticCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (settleSecs * 1000).round()),
    );
    _ballisticCtrl!.addListener(() {
      if (!mounted || handedOff) return;
      final t = _ballisticCtrl!.value * settleSecs;
      final x = friction.x(t).clamp(0.0, maxPage);
      final v = friction.dx(t);
      setState(() => _page = x);
      final crossed = (velocityPagesPerSec > 0 && x >= target - 0.08) ||
          (velocityPagesPerSec < 0 && x <= target + 0.08) ||
          v.abs() < 0.45;
      if (crossed || _ballisticCtrl!.isCompleted) {
        handedOff = true;
        final vel = v;
        // Defer so we do not dispose the controller inside its listener.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _springTo(target, vel);
        });
        _ballisticCtrl?.stop();
      }
    });
    _ballisticCtrl!.forward();
  }

  double _frictionSettleSeconds(FrictionSimulation f) {
    var lo = 0.0, hi = 3.0;
    final end = f.x(double.infinity);
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if ((f.x(mid) - end).abs() < 0.02 && f.dx(mid).abs() < 0.08) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi;
  }

  void _springTo(double target, double velocityPagesPerSec) {
    final startPage = _page;
    _stopBallistic();
    final springSim = SpringSimulation(
      _spring,
      startPage,
      target,
      velocityPagesPerSec,
    );
    var secs = 0.12;
    for (var t = 0.0; t < 2.0; t += 0.016) {
      secs = t;
      if ((springSim.x(t) - target).abs() < 0.01 &&
          springSim.dx(t).abs() < 0.05) {
        break;
      }
    }
    _ballisticCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (secs * 1000).clamp(80, 900).round()),
    );
    _ballisticCtrl!.addListener(() {
      if (!mounted) return;
      final t = _ballisticCtrl!.value * secs;
      setState(() => _page = springSim.x(t));
    });
    _ballisticCtrl!.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _page = target);
        _onSettled(target.round());
        _stopBallistic();
      }
    });
    _ballisticCtrl!.forward();
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    if (n == 0) return const SizedBox.shrink();

    final foldedH = _cardH / 0.42 + 12;
    final expandedH = n * (_cardH + _gap) - _gap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              '分类浏览',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            Text(
              '${cats.length} 类 · ${widget.counts.values.fold<int>(0, (a, b) => a + b)} 道',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
            if (widget.showExpandButton) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _toggle,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: AppTheme.cream,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _fanCtrl,
                  builder: (context, _) {
                    final open = _fanCtrl.value > 0.5;
                    return Text(
                      open ? '叠起 ↑' : '展开 ↓',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _fanCtrl,
          builder: (context, _) {
            if (_fanCtrl.value > 0.02) return const SizedBox.shrink();
            return Text(
              widget.openOnSwipeSettle
                  ? '甩动可跨多张 · 停稳打开 · 点按打开当前'
                  : '甩动可跨多张再吸附 · 点按打开',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _fanCurve,
          builder: (context, _) {
            final t = _fanCurve.value;
            final height = foldedH + (expandedH - foldedH) * t;
            final showFan = _expanded || t > 0.001;
            return SizedBox(
              height: height + 8,
              child: showFan ? _buildFan(n, t) : _buildInertiaWheel(n),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFan(int n, double t) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < n; i++) _buildFanCard(i, n, t),
      ],
    );
  }

  Widget _buildFanCard(int i, int n, double t) {
    final start = (i / n) * 0.35;
    final end = (start + 0.65).clamp(0.0, 1.0);
    final local =
        ((t - start) / (end - start).clamp(0.001, 1.0)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    final stackTop = i * _peek * 0.55;
    final listTop = i * (_cardH + _gap);
    final top = stackTop + (listTop - stackTop) * eased;
    final opacity = 0.55 + 0.45 * eased;

    return Positioned(
      key: ValueKey('fan-${widget.categories[i].id}'),
      top: top,
      left: 0,
      right: 0,
      height: _cardH,
      child: Opacity(
        opacity: opacity,
        child: RepaintBoundary(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onOpen(widget.categories[i]);
            },
            child: _CategoryCard(
              cat: widget.categories[i],
              count: widget.counts[widget.categories[i].id] ?? 0,
              paletteIndex: i,
              emphasis: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// Folded inertia wheel — gesture-driven, no PageView.
  Widget _buildInertiaWheel(int n) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cream.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: AppTheme.coral.withValues(alpha: 0.22),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      // Claim vertical drags so home CustomScrollView does not steal flings.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _stopBallistic(),
        onVerticalDragUpdate: _onWheelDragUpdate,
        onVerticalDragEnd: _onWheelDragEnd,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final focusTop = ((h - _cardH) / 2).clamp(0.0, h);
            // Draw neighbors around focus (±3).
            final center = _page;
            final first = (center.floor() - 3).clamp(0, n - 1);
            final last = (center.ceil() + 3).clamp(0, n - 1);
            final indices = [for (var i = first; i <= last; i++) i];

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final i in indices)
                  _buildWheelCard(
                    index: i,
                    focusTop: focusTop,
                    page: center,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWheelCard({
    required int index,
    required double focusTop,
    required double page,
  }) {
    final cat = widget.categories[index];
    final dist = (page - index).abs();
    final focusT = (1.0 - dist).clamp(0.0, 1.0);
    final sigma = lerpDouble(0, 6.5, (dist).clamp(0.0, 1.4) / 1.4)!;
    final opacity = lerpDouble(0.42, 1.0, focusT)!;
    final scale = lerpDouble(0.88, 1.06, focusT)!;
    final top = focusTop + (index - page) * _itemExtent;

    Widget card = RepaintBoundary(
      child: _CategoryCard(
        cat: cat,
        count: widget.counts[cat.id] ?? 0,
        paletteIndex: _paletteIndex(cat),
        emphasis: 1,
        showFocusRing: false,
      ),
    );
    if (focusT > 0.85) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.coral, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coral.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: card,
      );
    }
    if (sigma > 0.4) {
      card = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: card,
      );
    }

    return Positioned(
      top: top,
      left: 10,
      right: 10,
      height: _cardH,
      child: GestureDetector(
        onTap: () {
          if (dist > 0.35) {
            HapticFeedback.selectionClick();
            _springTo(index.toDouble(), 0);
            return;
          }
          HapticFeedback.lightImpact();
          widget.onOpen(cat);
        },
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: card,
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryInfo cat;
  final int count;
  final int paletteIndex;
  final double emphasis;
  final bool showFocusRing;

  const _CategoryCard({
    required this.cat,
    required this.count,
    required this.paletteIndex,
    this.emphasis = 1,
    this.showFocusRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryAccent(cat.id, paletteIndex);
    final dark = isDarkCard(color);
    final fg = dark ? Colors.white : AppTheme.navy;
    final titleSize = lerpDouble(18, 24, emphasis.clamp(0.0, 1.0))!;
    final countSize = lerpDouble(26, 34, emphasis.clamp(0.0, 1.0))!;

    return Container(
      height: _StackedCategoryCardsState._cardH,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: showFocusRing
            ? Border.all(color: AppTheme.coral, width: 2.5)
            : (color == Colors.white
                ? Border.all(color: AppTheme.navy.withValues(alpha: 0.12))
                : null),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.14 + 0.1 * emphasis),
            blurRadius: 12 + 8 * emphasis,
            offset: Offset(0, 6 + 4 * emphasis),
          ),
          if (showFocusRing)
            BoxShadow(
              color: AppTheme.coral.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: dark ? 0.18 : 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DoodleIcons.categoryIcon(cat.id, size: 40),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: titleSize,
                fontWeight:
                    emphasis > 0.7 ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: fg.withValues(alpha: 0.9),
              fontSize: countSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Exposed for tests: how many card-steps a fling coasts under friction.
@visibleForTesting
double walletCoastPages({
  required double startPage,
  required double velocityPagesPerSec,
  double drag = 0.085,
}) {
  final friction = FrictionSimulation(drag, startPage, velocityPagesPerSec);
  return friction.x(double.infinity) - startPage;
}
