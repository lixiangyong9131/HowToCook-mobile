import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Apple Wallet–style **stacked overlapping** category pile (not a PageView).
///
/// Folded: cards stack with peek; drag/fling the front card up — velocity
/// can skip **multiple** cards then settle. Tap front to open.
/// Expanded: fan-out list with the same AnimationController as collapse.
class StackedCategoryCards extends StatefulWidget {
  final List<CategoryInfo> categories;
  final Map<String, int> counts;
  final ValueChanged<CategoryInfo> onOpen;
  final bool initiallyExpanded;
  final bool autoFanOnMount;
  /// After a swipe settles on a new front card, call [onOpen] with it.
  final bool openOnSwipeSettle;
  /// Show 展开/叠起 control (false = wallet-only folded UX).
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
  static const _peek = 28.0;
  static const _cardH = 104.0;
  static const _gap = 12.0;
  static const _visibleBehind = 3;
  static const _swipeThreshold = 72.0;

  late bool _expanded;
  late final AnimationController _fanCtrl;
  late final AnimationController _swipeCtrl;

  /// Index in [categories] that is currently the front (top) card.
  int _front = 0;
  double _dragDy = 0;
  bool _cycling = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && !widget.autoFanOnMount;
    _fanCtrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 420 + widget.categories.length * 40,
      ),
      value: _expanded ? 1 : 0,
    );
    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    if (widget.autoFanOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 240));
        if (!mounted) return;
        _expand();
      });
    }
  }

  @override
  void dispose() {
    _fanCtrl.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  void _expand() {
    if (_expanded) return;
    HapticFeedback.mediumImpact();
    setState(() => _expanded = true);
    _fanCtrl.forward(from: 0);
  }

  void _collapse() {
    if (!_expanded) return;
    HapticFeedback.selectionClick();
    setState(() => _expanded = false);
    _fanCtrl.reverse();
  }

  void _toggle() => _expanded ? _collapse() : _expand();

  int get _n => widget.categories.length;

  CategoryInfo _atStackDepth(int depth) {
    // depth 0 = front, 1 = next, …
    final i = (_front + depth) % _n;
    return widget.categories[i];
  }

  int _paletteIndex(CategoryInfo cat) {
    final i = widget.categories.indexWhere((c) => c.id == cat.id);
    return i < 0 ? 0 : i;
  }

  Future<void> _cycleFront() async {
    if (_cycling || _n < 2) return;
    _cycling = true;
    HapticFeedback.lightImpact();
    _swipeCtrl.value = 0;
    await _swipeCtrl.animateTo(
      1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInCubic,
    );
    if (!mounted) return;
    setState(() {
      _front = (_front + 1) % _n;
      _dragDy = 0;
      _cycling = false;
      _swipeCtrl.value = 0;
    });
    if (widget.openOnSwipeSettle && _n > 0) {
      final selected = widget.categories[_front];
      widget.onOpen(selected);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_expanded || _cycling) return;
    setState(() {
      // Only allow upward drag (negative dy in Flutter? actually dy positive = down)
      _dragDy = (_dragDy + d.delta.dy).clamp(-180.0, 40.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails d) async {
    if (_expanded || _cycling) return;
    final v = d.primaryVelocity ?? 0;
    // Upward fling / drag past threshold → advance. Velocity can skip many.
    if (_dragDy < -_swipeThreshold || v < -550) {
      var steps = 1;
      if (v < -550) {
        // ~900 px/s ≈ 1 extra card; cap so a huge flick still feels controlled.
        steps = ( (-v) / 900 ).ceil().clamp(1, 6);
      }
      for (var i = 0; i < steps; i++) {
        if (!mounted || _expanded) break;
        await _cycleFront();
      }
    } else if (v > 550) {
      // Downward fling → go previous (multi-card too).
      var steps = (v / 900).ceil().clamp(1, 6);
      for (var i = 0; i < steps; i++) {
        if (!mounted || _expanded) break;
        await _cycleBack();
      }
    } else {
      setState(() => _dragDy = 0);
    }
  }

  Future<void> _cycleBack() async {
    if (_cycling || _n < 2) return;
    _cycling = true;
    HapticFeedback.lightImpact();
    // Instant settle backward (mirror of cycle front exit).
    setState(() {
      _front = (_front - 1 + _n) % _n;
      _dragDy = 0;
      _cycling = false;
      _swipeCtrl.value = 0;
    });
    if (widget.openOnSwipeSettle && _n > 0) {
      widget.onOpen(widget.categories[_front]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    if (n == 0) return const SizedBox.shrink();

    final peekN = n.clamp(0, _visibleBehind + 1);
    final collapsedH = _cardH + _peek * (peekN - 1).clamp(0, 99) + 24;
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
                child: Text(
                  _expanded ? '叠起 ↑' : '展开 ↓',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (!_expanded)
          Text(
            widget.openOnSwipeSettle
                ? '甩动叠卡可跨多张 · 停稳打开 · 点按打开当前'
                : '甩动叠卡可跨多张再停 · 点按打开',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: Listenable.merge([_fanCtrl, _swipeCtrl]),
          builder: (context, _) {
            final height =
                collapsedH + (expandedH - collapsedH) * _fanCtrl.value;
            return SizedBox(
              height: height + 8,
              child: _expanded ? _buildExpanded(n) : _buildWallet(n),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExpanded(int n) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < n; i++) _buildFanCard(i, n),
      ],
    );
  }

  Widget _buildFanCard(int i, int n) {
    final cat = widget.categories[i];
    final start = (i * 40) / (_fanCtrl.duration?.inMilliseconds ?? 1);
    final end = (start + 0.55).clamp(0.0, 1.0);
    final local = Curves.easeOutCubic.transform(
      ((_fanCtrl.value - start) / (end - start).clamp(0.001, 1.0))
          .clamp(0.0, 1.0),
    );
    final t =
        Curves.easeOutBack.transform(local.clamp(0.0, 1.0)).clamp(0.0, 1.15);
    final stackTop = i * _peek;
    final listTop = i * (_cardH + _gap);
    final top = stackTop + (listTop - stackTop) * t.clamp(0.0, 1.0);
    final scale =
        1.0 - (1 - t.clamp(0.0, 1.0)) * (n - 1 - i).clamp(0, 5) * 0.015;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onOpen(cat);
          },
          child: _cardBody(cat, i),
        ),
      ),
    );
  }

  Widget _buildWallet(int n) {
    final exitT = _swipeCtrl.value;
    final drag = _dragDy + (-140.0 * exitT);
    final depths = List.generate(
      n.clamp(0, _visibleBehind + 1),
      (d) => d,
    ).reversed.toList(); // draw back first

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          for (final depth in depths) _buildWalletCard(depth, n, drag),
        ],
      ),
    );
  }

  Widget _buildWalletCard(int depth, int n, double drag) {
    final cat = _atStackDepth(depth);
    final paletteI = _paletteIndex(cat);
    final isFront = depth == 0;

    // Behind cards sit lower with scale-down (Wallet peek).
    final baseTop = depth * _peek;
    final scale = 1.0 - depth * 0.035;
    final lift = isFront ? drag : (drag < 0 ? (-drag / 180) * depth * 4 : 0.0);
    // As front leaves, next cards rise toward front position.
    final promote = isFront
        ? 0.0
        : Curves.easeOut.transform(
            ((-drag.clamp(-180.0, 0.0)) / 180.0).clamp(0.0, 1.0),
          );
    final top = baseTop * (1 - promote) + lift;
    final thisScale = scale + (1 - scale) * promote;

    return Positioned(
      top: top,
      left: 8.0 * depth * (1 - promote),
      right: 8.0 * depth * (1 - promote),
      child: Opacity(
        opacity: isFront
            ? (1.0 - (-drag.clamp(-180.0, 0.0) / 220.0).clamp(0.0, 0.35))
            : 1,
        child: Transform.scale(
          scale: thisScale,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              if (!isFront) return;
              HapticFeedback.lightImpact();
              widget.onOpen(cat);
            },
            child: _cardBody(cat, paletteI),
          ),
        ),
      ),
    );
  }

  Widget _cardBody(CategoryInfo cat, int paletteIndex) {
    final color = categoryAccent(cat.id, paletteIndex);
    final dark = isDarkCard(color);
    final fg = dark ? Colors.white : AppTheme.navy;
    final count = widget.counts[cat.id] ?? 0;

    return Container(
      height: _cardH,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: color == Colors.white
            ? Border.all(color: AppTheme.navy.withValues(alpha: 0.12))
            : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
              style: TextStyle(
                color: fg,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: fg.withValues(alpha: 0.9),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
