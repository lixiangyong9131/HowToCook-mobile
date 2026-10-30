import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Apple Wallet–style category stack with **one** sharp focus card.
///
/// Folded: vertical center-focus pager — off-focus cards blur/fade (title
/// still readable). Expanded: fan to a list via [AnimatedPositioned] +
/// [RepaintBoundary] (no per-frame setState rebuild storms).
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
  static const _peek = 28.0;
  static const _visibleBehind = 3;
  /// Folded viewport shows ~3 slots; focus sits in the middle.
  static const _foldSlots = 3;
  static const _foldAnim = Duration(milliseconds: 320);

  late bool _expanded;
  /// Index of the focused (sharp, center) card in [categories].
  int _focus = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && !widget.autoFanOnMount;
    if (widget.autoFanOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        _expand();
      });
    }
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
    setState(() => _expanded = false);
  }

  void _toggle() => _expanded ? _collapse() : _expand();

  void _shiftFocus(int delta) {
    if (_n < 2) return;
    HapticFeedback.lightImpact();
    setState(() {
      _focus = (_focus + delta) % _n;
      if (_focus < 0) _focus += _n;
    });
    if (widget.openOnSwipeSettle) {
      widget.onOpen(widget.categories[_focus]);
    }
  }

  int _paletteIndex(CategoryInfo cat) {
    final i = widget.categories.indexWhere((c) => c.id == cat.id);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    if (n == 0) return const SizedBox.shrink();

    final peekN = n.clamp(0, _visibleBehind + 1);
    final collapsedH = _cardH * _foldSlots + _gap * (_foldSlots - 1) + 8;
    final stackPeekH = _cardH + _peek * (peekN - 1).clamp(0, 99) + 24;
    final foldedH = collapsedH > stackPeekH ? collapsedH : stackPeekH;
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
                ? '上滑选定并打开 · 点按打开当前'
                : '上滑切换下一张 · 点按打开',
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
          child: _expanded ? _buildExpanded(n) : _buildFolded(n),
        ),
      ],
    );
  }

  /// Expanded list: each card animates with [AnimatedPositioned].
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
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Folded: center-focus stack. Only depth-0 is sharp; others blur/fade.
  Widget _buildFolded(int n) {
    final depths = List.generate(
      n.clamp(0, _visibleBehind + 1),
      (d) => d,
    );

    return GestureDetector(
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -400) {
          _shiftFocus(1); // swipe up → next
        } else if (v > 400) {
          _shiftFocus(-1); // swipe down → previous
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          // Focus card vertically centered in the folded viewport.
          final focusTop = ((h - _cardH) / 2).clamp(0.0, h);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Draw back → front so focus is on top.
              for (final depth in depths.reversed)
                _buildFocusCard(depth: depth, focusTop: focusTop),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFocusCard({required int depth, required double focusTop}) {
    final idx = (_focus + depth) % _n;
    final cat = widget.categories[idx];
    final isFocus = depth == 0;

    // Behind cards sit below focus with peek; above-focus ghost for prev.
    final top = isFocus
        ? focusTop
        : focusTop + depth * _peek;

    // Distance from focus → blur / opacity. Blurred name still readable.
    final sigma = isFocus ? 0.0 : (2.0 + depth * 2.2).clamp(2.0, 8.0);
    final opacity = isFocus ? 1.0 : (0.72 - depth * 0.12).clamp(0.38, 0.72);
    final scale = isFocus ? 1.0 : (1.0 - depth * 0.04).clamp(0.88, 1.0);
    final hPad = isFocus ? 0.0 : 10.0 * depth;

    Widget card = RepaintBoundary(
      child: _CategoryCard(
        cat: cat,
        count: widget.counts[cat.id] ?? 0,
        paletteIndex: _paletteIndex(cat),
      ),
    );

    if (!isFocus) {
      card = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Opacity(opacity: opacity, child: card),
      );
    }

    return AnimatedPositioned(
      key: ValueKey('fold-$depth-${cat.id}'),
      duration: _foldAnim,
      curve: Curves.easeOutCubic,
      top: top,
      left: hPad,
      right: hPad,
      height: _cardH,
      child: AnimatedScale(
        scale: scale,
        duration: _foldAnim,
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            if (!isFocus) {
              // Tap a peek card → bring it to focus (still blurred until settled).
              HapticFeedback.selectionClick();
              setState(() => _focus = idx);
              return;
            }
            HapticFeedback.lightImpact();
            widget.onOpen(cat);
          },
          child: card,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryInfo cat;
  final int count;
  final int paletteIndex;

  const _CategoryCard({
    required this.cat,
    required this.count,
    required this.paletteIndex,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryAccent(cat.id, paletteIndex);
    final dark = isDarkCard(color);
    final fg = dark ? Colors.white : AppTheme.navy;

    return Container(
      height: _StackedCategoryCardsState._cardH,
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
