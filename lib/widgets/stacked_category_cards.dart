import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Apple Wallet–style category stack with inertia-wheel swipe physics.
///
/// Folded: vertical pager — velocity + friction, snap to nearest card,
/// rubber-band ends (spring stiffness 300 / damping 20). Only the center
/// card is sharp & larger; neighbors blur/fade (name still readable).
/// Expanded: [AnimatedPositioned] + [RepaintBoundary] fan-out list.
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

class _StackedCategoryCardsState extends State<StackedCategoryCards> {
  static const _cardH = 104.0;
  static const _gap = 12.0;
  static const _foldAnim = Duration(milliseconds: 320);
  /// Viewport shows ~2.4 cards so neighbors peek above/below focus.
  static const _viewportFraction = 0.42;

  late bool _expanded;
  PageController? _pageCtrl;
  int _focus = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && !widget.autoFanOnMount;
    _initPageCtrl();
    if (widget.autoFanOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        _expand();
      });
    }
  }

  void _initPageCtrl() {
    _pageCtrl?.dispose();
    _pageCtrl = PageController(
      initialPage: _focus,
      viewportFraction: _viewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant StackedCategoryCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories.length != widget.categories.length) {
      _focus = _focus.clamp(0, (widget.categories.length - 1).clamp(0, 9999));
      _initPageCtrl();
    }
  }

  @override
  void dispose() {
    _pageCtrl?.dispose();
    super.dispose();
  }

  int get _n => widget.categories.length;

  void _expand() {
    if (_expanded) return;
    HapticFeedback.mediumImpact();
    setState(() => _expanded = true);
  }

  void _collapse() {
    if (!_expanded) return;
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = false;
      // Re-sync pager to current focus after collapse.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl != null && _pageCtrl!.hasClients) {
          _pageCtrl!.jumpToPage(_focus);
        }
      });
    });
  }

  void _toggle() => _expanded ? _collapse() : _expand();

  int _paletteIndex(CategoryInfo cat) {
    final i = widget.categories.indexWhere((c) => c.id == cat.id);
    return i < 0 ? 0 : i;
  }

  void _onPageSettled(int i) {
    if (i == _focus) return;
    HapticFeedback.selectionClick();
    setState(() => _focus = i);
    if (widget.openOnSwipeSettle && _n > 0) {
      widget.onOpen(widget.categories[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    if (n == 0) return const SizedBox.shrink();

    // Folded height: enough for center + peeks (~1/viewportFraction cards).
    final foldedH = _cardH / _viewportFraction + 12;
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
                ? '惯性上滑选定并打开 · 点按打开当前'
                : '惯性上滑切换 · 点按打开',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: _foldAnim,
          curve: Curves.easeOutCubic,
          height: (_expanded ? expandedH : foldedH) + 8,
          child: _expanded ? _buildExpanded(n) : _buildInertiaWheel(n),
        ),
      ],
    );
  }

  Widget _buildExpanded(int n) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < n; i++)
          AnimatedPositioned(
            key: ValueKey('fan-${widget.categories[i].id}'),
            duration: Duration(milliseconds: 280 + (i * 28).clamp(0, 220)),
            curve: Curves.easeOutCubic,
            top: i * (_cardH + _gap),
            left: 0,
            right: 0,
            height: _cardH,
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
      ],
    );
  }

  /// Inertia wheel: PageView + spring snap + blur by distance from center.
  Widget _buildInertiaWheel(int n) {
    final ctrl = _pageCtrl;
    if (ctrl == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        // Soft cream stage — not purple.
        color: AppTheme.cream.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: AppTheme.coral.withValues(alpha: 0.22),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: ctrl,
        itemCount: n,
        physics: const _WalletInertiaPhysics(
          parent: BouncingScrollPhysics(
            decelerationRate: ScrollDecelerationRate.normal,
          ),
        ),
        onPageChanged: _onPageSettled,
        itemBuilder: (context, i) {
          final cat = widget.categories[i];
          // Card chrome cached in RepaintBoundary; only transform/blur ticks.
          final cached = RepaintBoundary(
            child: _CategoryCard(
              cat: cat,
              count: widget.counts[cat.id] ?? 0,
              paletteIndex: _paletteIndex(cat),
              emphasis: 1,
              showFocusRing: false,
            ),
          );
          return AnimatedBuilder(
            animation: ctrl,
            child: cached,
            builder: (context, child) {
              final page = ctrl.hasClients
                  ? (ctrl.page ?? _focus.toDouble())
                  : _focus.toDouble();
              final dist = (page - i).abs();
              final focusT = (1.0 - dist).clamp(0.0, 1.0);
              final sigma =
                  lerpDouble(0, 6.5, (dist).clamp(0.0, 1.4) / 1.4)!;
              final opacity = lerpDouble(0.42, 1.0, focusT)!;
              final scale = lerpDouble(0.88, 1.06, focusT)!;

              Widget card = child!;
              // Coral focus ring overlay when centered (theme, not purple).
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
                  imageFilter: ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                  ),
                  child: card,
                );
              }
              return Center(
                child: GestureDetector(
                  onTap: () {
                    if (dist > 0.35) {
                      HapticFeedback.selectionClick();
                      ctrl.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                      return;
                    }
                    HapticFeedback.lightImpact();
                    widget.onOpen(cat);
                  },
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: card,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Page-snapping scroll physics with spring rubber-band
/// (stiffness ≈ 300, damping ≈ 20) — mirrors inertia timer wheel feel.
class _WalletInertiaPhysics extends PageScrollPhysics {
  const _WalletInertiaPhysics({super.parent});

  @override
  _WalletInertiaPhysics applyTo(ScrollPhysics? ancestor) {
    return _WalletInertiaPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 1,
        stiffness: 300,
        damping: 20,
      );
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
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
