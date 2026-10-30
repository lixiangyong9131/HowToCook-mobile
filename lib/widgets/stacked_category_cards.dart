import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Apple Wallet–style **stacked overlapping** category pile (not a PageView).
///
/// Folded: continuous free-scroll through the pile. Finger drag tracks 1:1;
/// release coasts with friction (延迟滑动), then springs/folds to nearest
/// card. Cards scrolled past rise into an **upper** peek pile; remaining
/// cards stay in the lower peek stack. Tap front to open.
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
  static const _upperPeek = 22.0;
  static const _cardH = 104.0;
  static const _gap = 12.0;
  static const _visibleBehind = 3;
  static const _visibleAbove = 3;
  /// Finger pixels per one card of [offset].
  static const _pxPerCard = 78.0;

  late bool _expanded;
  late final AnimationController _fanCtrl;
  late final AnimationController _coastCtrl;

  /// Continuous deck position in `[0, n-1]`. Integer = folded on that card.
  double _offset = 0;
  int _lastSettled = 0;
  bool _dragging = false;

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
    _coastCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onCoastTick)
      ..addStatusListener(_onCoastStatus);
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
    _coastCtrl.removeListener(_onCoastTick);
    _coastCtrl.removeStatusListener(_onCoastStatus);
    _fanCtrl.dispose();
    _coastCtrl.dispose();
    super.dispose();
  }

  void _onCoastTick() {
    if (!mounted || _dragging) return;
    setState(() => _offset = _coastCtrl.value.clamp(0.0, _maxOffset));
  }

  void _onCoastStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final settled = _offset.round().clamp(0, (_n - 1).clamp(0, 9999));
    setState(() {
      _offset = settled.toDouble();
      _coastCtrl.value = _offset;
    });
    if (settled != _lastSettled) {
      _lastSettled = settled;
      HapticFeedback.selectionClick();
      if (widget.openOnSwipeSettle && _n > 0) {
        widget.onOpen(widget.categories[settled]);
      }
    }
  }

  void _expand() {
    if (_expanded) return;
    _coastCtrl.stop();
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
  double get _maxOffset => (_n - 1).clamp(0, 9999).toDouble();

  int _paletteIndex(CategoryInfo cat) {
    final i = widget.categories.indexWhere((c) => c.id == cat.id);
    return i < 0 ? 0 : i;
  }

  void _onVerticalDragStart(DragStartDetails _) {
    if (_expanded) return;
    _dragging = true;
    _coastCtrl.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_expanded || !_dragging) return;
    // Finger up (negative dy) → advance through deck (offset ↑).
    setState(() {
      _offset = (_offset - d.delta.dy / _pxPerCard).clamp(0.0, _maxOffset);
    });
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_expanded) return;
    _dragging = false;
    // primaryVelocity: positive = finger down. Advance = finger up = negative.
    final pxVel = -(d.primaryVelocity ?? 0);
    final offsetVel = pxVel / _pxPerCard;
    _startCoast(offsetVel);
  }

  void _onVerticalDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _startCoast(0);
  }

  /// Friction coast toward a predicted stop, then soft spring-fold to nearest.
  void _startCoast(double velocity) {
    if (_n < 2) {
      setState(() => _offset = 0);
      return;
    }
    // Ballistic end under light friction → "延迟滑动".
    final friction = FrictionSimulation(0.085, _offset, velocity);
    var predicted = friction.x(double.infinity);
    if (predicted.isNaN || predicted.isInfinite) {
      predicted = _offset + velocity * 0.35;
    }
    predicted = predicted.clamp(0.0, _maxOffset);
    // Free-scroll feel: snap to nearest integer after coast prediction.
    final target = predicted.round().toDouble().clamp(0.0, _maxOffset);

    // Soft spring = lingering coast then fold. Stiffness low → 延迟.
    final spring = SpringDescription(
      mass: 1,
      stiffness: 95,
      damping: 16,
    );
    final sim = SpringSimulation(spring, _offset, target, velocity);
    _coastCtrl.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    if (n == 0) return const SizedBox.shrink();

    final peekN = n.clamp(0, _visibleBehind + 1);
    final upperN = n.clamp(0, _visibleAbove);
    final collapsedH =
        _cardH + _peek * (peekN - 1).clamp(0, 99) + _upperPeek * upperN + 24;
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
                ? '自由甩动可跨多张 · 惯性停稳打开 · 点按打开当前'
                : '自由甩动可跨多张再停 · 划过的叠在上部 · 点按打开',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: Listenable.merge([_fanCtrl, _coastCtrl]),
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
    // Origin Y of the focus slot — leave room for the upper (passed) pile.
    final focusOrigin = _upperPeek * _visibleAbove.toDouble();

    // Draw far cards first so nearer ones paint on top.
    final indices = List<int>.generate(n, (i) => i);
    indices.sort((a, b) {
      final da = (a - _offset).abs();
      final db = (b - _offset).abs();
      // Farther first; among equals prefer higher index under.
      final c = db.compareTo(da);
      return c != 0 ? c : a.compareTo(b);
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onVerticalDragCancel: _onVerticalDragCancel,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          for (final i in indices) _buildWalletCard(i, n, focusOrigin),
        ],
      ),
    );
  }

  Widget _buildWalletCard(int index, int n, double focusOrigin) {
    final cat = widget.categories[index];
    final paletteI = _paletteIndex(cat);
    final rel = index - _offset; // <0 passed/upper, 0 focus, >0 lower

    // Cull cards too far from focus to keep the pile readable.
    if (rel < -(_visibleAbove + 0.6) || rel > (_visibleBehind + 0.6)) {
      return const SizedBox.shrink();
    }

    double top;
    double scale;
    double opacity;
    double sideInset;

    if (rel <= 0) {
      // Passed cards rise into the upper peek pile; focus sits at origin.
      final depthUp = (-rel).clamp(0.0, _visibleAbove + 0.5);
      top = focusOrigin - depthUp * _upperPeek;
      scale = 1.0 - depthUp * 0.03;
      opacity = (1.0 - depthUp * 0.12).clamp(0.35, 1.0);
      sideInset = 6.0 * depthUp;
    } else {
      // Remaining deck peeks below the focus (classic Wallet stack).
      final depthDown = rel.clamp(0.0, _visibleBehind + 0.5);
      top = focusOrigin + depthDown * _peek;
      scale = 1.0 - depthDown * 0.035;
      opacity = (1.0 - depthDown * 0.08).clamp(0.4, 1.0);
      sideInset = 8.0 * depthDown;
    }

    final isFront = rel.abs() < 0.45;

    return Positioned(
      top: top,
      left: sideInset,
      right: sideInset,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
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
