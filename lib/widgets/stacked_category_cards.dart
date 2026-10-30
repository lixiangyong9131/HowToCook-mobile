import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Apple Wallet–style **stacked overlapping** category pile (not a PageView).
///
/// Folded: continuous free-scroll through the pile (**infinite loop** —
/// past the last card wraps to the first). Finger drag tracks 1:1; release
/// coasts with soft friction then springs to nearest card. Passed cards
/// rise into an upper peek pile. Tap front to open.
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
  /// Finger pixels per one card of [offset] (higher = silkier / less twitchy).
  static const _pxPerCard = 78.0;

  late bool _expanded;
  late final AnimationController _fanCtrl;
  late final AnimationController _coastCtrl;

  /// Continuous deck position (unbounded; wraps mod n). Integer = front card.
  double _offset = 0;
  int _lastSettled = 0;
  bool _dragging = false;
  /// 0 idle, 1 friction coast, 2 spring snap.
  int _coastPhase = 0;

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
    setState(() => _offset = _coastCtrl.value);
  }

  void _onCoastStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_n < 1) return;

    // Phase 1 (friction) finished → soft spring to nearest card.
    if (_coastPhase == 1) {
      var target = _offset.round().toDouble();
      // After a real fling, prefer landing at least one card away when
      // friction barely moved us (keeps “多滑 1～2 张” obvious).
      if ((target - _lastSettled).abs() < 0.5 &&
          (_offset - _lastSettled).abs() > 0.35) {
        target = _offset > _lastSettled
            ? _lastSettled + 1.0
            : _lastSettled - 1.0;
      }
      _coastPhase = 2;
      final spring = SpringDescription(
        mass: 1.2,
        stiffness: 22,
        damping: 14,
      );
      _coastCtrl.animateWith(
        SpringSimulation(spring, _offset, target, 0),
      );
      return;
    }

    // Phase 2 (or direct) done → normalize + haptics.
    _coastPhase = 0;
    final settled = _modIndex(_offset.round());
    setState(() {
      _offset = settled.toDouble();
      _coastCtrl.value = _offset;
    });
    if (settled != _lastSettled) {
      _lastSettled = settled;
      HapticFeedback.selectionClick();
      if (widget.openOnSwipeSettle) {
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

  int _modIndex(int i) {
    final n = _n;
    if (n <= 0) return 0;
    return (i % n + n) % n;
  }

  /// Shortest signed distance from focus [_offset] to card [index] on a ring.
  double _circularRel(int index) {
    final n = _n;
    if (n <= 0) return 0;
    var rel = index - _offset;
    rel -= n * (rel / n).round();
    return rel;
  }

  int _paletteIndex(CategoryInfo cat) {
    final i = widget.categories.indexWhere((c) => c.id == cat.id);
    return i < 0 ? 0 : i;
  }

  void _onVerticalDragStart(DragStartDetails _) {
    if (_expanded) return;
    _dragging = true;
    _coastPhase = 0;
    _coastCtrl.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_expanded || !_dragging) return;
    // Finger up (negative dy) → advance through deck (offset ↑). No clamp —
    // infinite loop lets offset run past ends and wrap visually.
    setState(() {
      _offset = _offset - d.delta.dy / _pxPerCard;
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
  /// Target may lie outside `[0, n)` — visuals wrap; we normalize on settle.
  void _startCoast(double velocity) {
    if (_n < 2) {
      setState(() => _offset = 0);
      return;
    }
    // Two-phase: friction coast (delayed / silky) → soft spring snap.
    // Previously we only *predicted* with friction then sprang immediately,
    // so the delayed coast was never visible.
    final coastVel = velocity * 1.85;
    // Mild fling still advances ~1 card; strong fling coasts 1–2 extra.
    var kick = coastVel;
    if (kick.abs() < 0.8 && kick.abs() > 0.12) {
      kick = kick.sign * 1.15;
    } else if (kick.abs() >= 0.8 && kick.abs() < 2.2) {
      kick = kick.sign * (kick.abs() + 1.0);
    }
    _coastPhase = 1;
    _coastCtrl.animateWith(FrictionSimulation(0.035, _offset, kick));
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
    final focusOrigin = _upperPeek * _visibleAbove.toDouble() + 6;

    // Draw far cards first so nearer ones paint on top.
    final indices = List<int>.generate(n, (i) => i);
    indices.sort((a, b) {
      final da = _circularRel(a).abs();
      final db = _circularRel(b).abs();
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
    final rel = _circularRel(index); // <0 passed/upper, 0 focus, >0 lower

    // Soft edge fade — mid-scroll frames stay smooth (ring-aware).
    if (rel < -(_visibleAbove + 1.15) || rel > (_visibleBehind + 1.15)) {
      return const SizedBox.shrink();
    }

    final depthUp = (-rel).clamp(0.0, _visibleAbove + 0.8);
    final depthDown = rel.clamp(0.0, _visibleBehind + 0.8);
    // Smoother easing for silkier morph between stacked slots.
    final upT = Curves.easeInOutCubic.transform(
      (depthUp / (_visibleAbove + 0.8)).clamp(0.0, 1.0),
    );
    final downT = Curves.easeInOutCubic.transform(
      (depthDown / (_visibleBehind + 0.8)).clamp(0.0, 1.0),
    );

    late double top;
    late double scale;
    late double opacity;
    late double sideInset;
    late double elev;

    if (rel <= 0) {
      top = focusOrigin - depthUp * _upperPeek;
      scale = 1.0 - upT * 0.06;
      opacity = (1.0 - upT * 0.45).clamp(0.25, 1.0);
      sideInset = 10.0 * upT;
      elev = 10.0 * (1.0 - upT);
    } else {
      top = focusOrigin + depthDown * _peek;
      scale = 1.0 - downT * 0.07;
      opacity = (1.0 - downT * 0.35).clamp(0.3, 1.0);
      sideInset = 12.0 * downT;
      elev = 10.0 * (1.0 - downT);
    }

    // Front card eases between slots (visible card morph, less twitchy).
    final frac = (rel.abs() < 1) ? (1.0 - rel.abs()) : 0.0;
    final lift = Curves.easeInOutCubic.transform(frac.clamp(0.0, 1.0));
    final dragLift = _dragging ? 1.0 : 0.7;
    scale += 0.03 * lift * dragLift;
    top -= 8.0 * lift * dragLift;
    elev += 12.0 * lift;

    final isFront = rel.abs() < 0.5;
    final tilt = (rel <= 0 ? -upT : downT) * 0.035;

    return Positioned(
      top: top,
      left: sideInset,
      right: sideInset,
      child: Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.00115)
            ..rotateX(tilt),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {
                if (!isFront) return;
                HapticFeedback.lightImpact();
                widget.onOpen(cat);
              },
              child: _cardBody(
                cat,
                paletteI,
                elevation: elev,
                emphasize: isFront,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardBody(
    CategoryInfo cat,
    int paletteIndex, {
    double elevation = 10,
    bool emphasize = false,
  }) {
    final color = categoryAccent(cat.id, paletteIndex);
    final dark = isDarkCard(color);
    final fg = dark ? Colors.white : AppTheme.navy;
    final count = widget.counts[cat.id] ?? 0;
    final blur = 10.0 + elevation * 0.5;
    final yOff = 4.0 + elevation * 0.35;

    return Container(
      height: _cardH,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: color == Colors.white
            ? Border.all(color: AppTheme.navy.withValues(alpha: 0.12))
            : (emphasize
                ? Border.all(
                    color: Colors.white.withValues(alpha: dark ? 0.22 : 0.35),
                    width: 1.2,
                  )
                : null),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.14 + elevation * 0.008),
            blurRadius: blur,
            offset: Offset(0, yOff),
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
