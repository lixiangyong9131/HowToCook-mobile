import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Tight vertical stack of category cards (not a PageView).
///
/// Folded: cards share one column on a navy stage. Cards behind the front
/// one only show a short title lip (tighter than a loose “access card”
/// stack). The front card is tall — cover mark plus the category name.
/// Finger up/down still free-scrolls the pile (**infinite loop**). Release
/// coasts with friction, then springs to the nearest card. Tap the front
/// card to open.
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
  /// Title lip of each card behind the front one.
  /// A loose reference stack shows ~64–72px of the card behind; this is
  /// about 60% of that, so the pile reads tighter.
  static const _peek = 40.0;

  /// Expanded-list row height (folded front card is taller — see [_frontH]).
  static const _cardH = 108.0;
  static const _gap = 12.0;
  static const _visibleBehind = 3;
  static const _stackRadius = 28.0;

  /// Finger pixels per one card of [offset].
  static const _pxPerCard = 64.0;

  /// Front card fills most of the lower half of a phone screen.
  static double _frontH(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.48).clamp(300.0, 460.0);
  }

  late bool _expanded;
  late final AnimationController _fanCtrl;
  late final AnimationController _coastCtrl;

  /// Continuous deck position (unbounded; wraps mod n). Integer = front card.
  double _offset = 0;
  int _lastSettled = 0;
  bool _dragging = false;

  /// 0 idle, 1 friction coast, 2 spring snap.
  int _coastPhase = 0;

  /// Last integer slot that fired a scroll tick haptic (Clock-wheel style).
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && !widget.autoFanOnMount;
    _fanCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 680 + widget.categories.length * 32),
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
    _fireTickHaptic();
  }

  /// Apple Clock–style click each time the focus crosses a card slot.
  void _fireTickHaptic() {
    final tick = _offset.round();
    if (tick == _lastTick) return;
    _lastTick = tick;
    HapticFeedback.selectionClick();
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
      // Cupertino-ish snap: stiff spring, quick settle onto a slot.
      final spring = SpringDescription(mass: 1.0, stiffness: 110, damping: 18);
      _coastCtrl.animateWith(SpringSimulation(spring, _offset, target, 0));
      return;
    }

    // Phase 2 (or direct) done → normalize + haptics.
    _coastPhase = 0;
    final settled = _modIndex(_offset.round());
    setState(() {
      _offset = settled.toDouble();
      _coastCtrl.value = _offset;
    });
    _lastTick = settled;
    if (settled != _lastSettled) {
      _lastSettled = settled;
      // Soft settle pulse after the last tick (Clock stops on a digit).
      HapticFeedback.lightImpact();
      if (widget.openOnSwipeSettle) {
        widget.onOpen(widget.categories[settled]);
      }
    }
  }

  Duration get _expandDur =>
      Duration(milliseconds: 680 + widget.categories.length * 32);

  Duration get _collapseDur =>
      Duration(milliseconds: 780 + widget.categories.length * 36);

  void _expand() {
    if (_expanded || _fanCtrl.isAnimating) return;
    _coastCtrl.stop();
    HapticFeedback.mediumImpact();
    setState(() => _expanded = true);
    // Linear controller; curve applied once in the builder (no double-ease).
    _fanCtrl.animateTo(1, duration: _expandDur, curve: Curves.linear);
  }

  void _collapse() {
    if (!_expanded || _fanCtrl.isAnimating) return;
    HapticFeedback.selectionClick();
    // Keep fan layout until reverse finishes — avoids hard cut to wallet.
    // Longer reverse + easeOutCubic visual (applied in builder) softens the end.
    _fanCtrl
        .animateBack(0, duration: _collapseDur, curve: Curves.linear)
        .whenComplete(() {
          if (!mounted) return;
          if (_fanCtrl.value <= 0.001) {
            setState(() => _expanded = false);
          }
        });
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

  void _onVerticalDragStart(DragStartDetails _) {
    if (_expanded) return;
    _dragging = true;
    _coastPhase = 0;
    _coastCtrl.stop();
    _lastTick = _offset.round();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_expanded || !_dragging) return;
    // Finger up (negative dy) → advance through deck (offset ↑). No clamp —
    // infinite loop lets offset run past ends and wrap visually.
    setState(() {
      _offset = _offset - d.delta.dy / _pxPerCard;
    });
    _fireTickHaptic();
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
    // Clock wheel: short coast then hard snap (not a long free glide).
    final coastVel = velocity * 1.35;
    var kick = coastVel;
    if (kick.abs() < 0.55 && kick.abs() > 0.08) {
      kick = kick.sign * 0.95;
    } else if (kick.abs() >= 0.55 && kick.abs() < 1.8) {
      kick = kick.sign * (kick.abs() + 0.55);
    }
    _coastPhase = 1;
    _coastCtrl.animateWith(FrictionSimulation(0.085, _offset, kick));
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    if (n == 0) return const SizedBox.shrink();

    final frontH = _frontH(context);
    final collapsedH = frontH + _peek * _visibleBehind;
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
              Material(
                color: Colors.white,
                elevation: 0,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: AppTheme.coral.withValues(alpha: 0.45),
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          size: 18,
                          color: AppTheme.coral,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _expanded ? '叠起' : '展开',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: Listenable.merge([_fanCtrl, _coastCtrl]),
          builder: (context, _) {
            final raw = _fanCtrl.value.clamp(0.0, 1.0);
            final tFan =
                (_fanCtrl.status == AnimationStatus.reverse ||
                    (_fanCtrl.status == AnimationStatus.dismissed &&
                        !_expanded))
                ? Curves.easeOutCubic.transform(raw)
                : Curves.easeInOutCubic.transform(raw);
            final height = collapsedH + (expandedH - collapsedH) * tFan;
            final showFan = _expanded || _fanCtrl.value > 0.001;
            final pile = SizedBox(
              height: showFan ? height : collapsedH,
              child: showFan
                  ? _buildExpanded(n, frontH)
                  : _buildWallet(n, frontH),
            );
            if (showFan) return pile;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navy.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                child: pile,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExpanded(int n, double frontH) {
    return Stack(
      clipBehavior: Clip.none,
      children: [for (var i = 0; i < n; i++) _buildFanCard(i, n, frontH)],
    );
  }

  Widget _buildFanCard(int i, int n, double frontH) {
    final cat = widget.categories[i];
    final stagger = (i / n.clamp(1, 99)) * 0.22;
    final raw = _fanCtrl.value.clamp(0.0, 1.0);
    final localRaw = ((raw - stagger) / (1.0 - stagger).clamp(0.001, 1.0))
        .clamp(0.0, 1.0);
    final collapsing = _fanCtrl.status == AnimationStatus.reverse;
    final t =
        (collapsing
                ? Curves.easeOutCubic.transform(localRaw)
                : Curves.easeInOutCubic.transform(localRaw))
            .clamp(0.0, 1.0);

    final slot = _stackSlot(_circularRel(i));
    final listTop = i * (_cardH + _gap);
    final top = slot.top + (listTop - slot.top) * t;
    final height = frontH + (_cardH - frontH) * t;
    final opacity = slot.opacity + (1.0 - slot.opacity) * t;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onOpen(cat);
          },
          child: _cardBody(cat, i, height: height, elevation: slot.elev),
        ),
      ),
    );
  }

  /// Folded stack slot. rel 0 is the tall front card; rel > 0 sits above it
  /// by [_peek] per step so only the title lip shows.
  ({double top, double opacity, double elev}) _stackSlot(double rel) {
    final vb = _visibleBehind.toDouble();
    if (rel <= -1.0 || rel > vb + 0.45) {
      return (top: rel < 0 ? -120.0 : vb * _peek, opacity: 0.0, elev: 0);
    }
    if (rel >= 0) {
      final depth = rel.clamp(0.0, vb);
      return (
        top: (vb - depth) * _peek,
        opacity: 1.0,
        elev: rel < 0.45 ? 16.0 : 7.0,
      );
    }
    final leave = (-rel).clamp(0.0, 1.0);
    return (
      top: vb * _peek + rel * (_peek + 28),
      opacity: (1.0 - leave * 1.25).clamp(0.0, 1.0),
      elev: 18.0,
    );
  }

  Widget _buildWallet(int n, double frontH) {
    final indices = List<int>.generate(n, (i) => i);
    indices.sort((a, b) {
      final ra = _circularRel(a);
      final rb = _circularRel(b);
      final aExit = ra < 0;
      final bExit = rb < 0;
      if (aExit != bExit) return aExit ? 1 : -1;
      return rb.compareTo(ra);
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
        children: [for (final i in indices) _buildWalletCard(i, frontH)],
      ),
    );
  }

  Widget _buildWalletCard(int index, double frontH) {
    final rel = _circularRel(index);
    final slot = _stackSlot(rel);
    if (slot.opacity <= 0.001) return const SizedBox.shrink();

    final cat = widget.categories[index];
    final isFront = rel.abs() < 0.5;

    return Positioned(
      top: slot.top,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: slot.opacity,
        child: GestureDetector(
          onTap: () {
            if (!isFront) return;
            HapticFeedback.lightImpact();
            widget.onOpen(cat);
          },
          child: _cardBody(
            cat,
            index,
            height: frontH,
            elevation: slot.elev,
            emphasize: isFront,
          ),
        ),
      ),
    );
  }

  Widget _cardBody(
    CategoryInfo cat,
    int paletteIndex, {
    required double height,
    double elevation = 10,
    bool emphasize = false,
  }) {
    final color = _stackColors[paletteIndex % _stackColors.length];
    final lightFg = color.computeLuminance() < 0.62;
    final fg = lightFg ? Colors.white : AppTheme.navy;
    final count = widget.counts[cat.id] ?? 0;
    final iconSize = ((height - _peek) * 0.58).clamp(72.0, 168.0);

    return Container(
      key: ValueKey('stack-card-${cat.id}'),
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_stackRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: emphasize ? 0.55 : 0.28),
          width: emphasize ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18 + elevation * 0.006),
            blurRadius: 12,
            spreadRadius: -3,
            offset: Offset(0, 5 + elevation * 0.15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _peek,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count 道',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -28,
                  bottom: -36,
                  child: Container(
                    width: iconSize * 1.7,
                    height: iconSize * 1.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (lightFg ? Colors.white : AppTheme.navy)
                          .withValues(alpha: lightFg ? 0.10 : 0.06),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  top: 8,
                  child: Container(
                    width: iconSize * 0.72,
                    height: iconSize * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.coral.withValues(
                        alpha: lightFg ? 0.22 : 0.35,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: DoodleIcons.categoryIcon(
                      cat.id,
                      size: iconSize * 0.72,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Saturated stack faces that stay inside navy / cream / coral.
const _stackColors = <Color>[
  Color(0xFFFF8A65),
  Color(0xFFFFF6EB),
  Color(0xFF4A7C9B),
  Color(0xFFFFD6C4),
  Color(0xFF243056),
  Color(0xFFFFE8DC),
  Color(0xFFFFB59A),
  Color(0xFFE7F6EE),
  Color(0xFFFFE0B2),
  Color(0xFFD6E4EE),
];
