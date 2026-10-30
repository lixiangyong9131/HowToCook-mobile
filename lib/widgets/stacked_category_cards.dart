import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/doodle_icons.dart';

/// Interaction 3 — Stack Fan (叠卡展开).
/// Folded: cards stacked with ~48px peek; expand: staggered push-down.
class StackedCategoryCards extends StatefulWidget {
  final List<CategoryInfo> categories;
  final Map<String, int> counts;
  final ValueChanged<CategoryInfo> onOpen;
  final bool initiallyExpanded;
  final bool autoFanOnMount;

  const StackedCategoryCards({
    super.key,
    required this.categories,
    required this.counts,
    required this.onOpen,
    this.initiallyExpanded = false,
    this.autoFanOnMount = false,
  });

  @override
  State<StackedCategoryCards> createState() => _StackedCategoryCardsState();
}

class _StackedCategoryCardsState extends State<StackedCategoryCards>
    with SingleTickerProviderStateMixin {
  static const _peek = 48.0;
  static const _cardH = 96.0;
  static const _gap = 12.0;
  static const _staggerMs = 40;

  late bool _expanded;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && !widget.autoFanOnMount;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 420 + widget.categories.length * _staggerMs,
      ),
      value: _expanded ? 1 : 0,
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
    _ctrl.dispose();
    super.dispose();
  }

  void _expand() {
    if (_expanded) return;
    HapticFeedback.mediumImpact();
    setState(() => _expanded = true);
    _ctrl.forward(from: 0);
  }

  void _collapse() {
    if (!_expanded) return;
    HapticFeedback.selectionClick();
    setState(() => _expanded = false);
    _ctrl.reverse();
  }

  void _toggle() => _expanded ? _collapse() : _expand();

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    final peekN = n.clamp(0, 6);
    final collapsedH = _cardH + _peek * (peekN - 1).clamp(0, 99);
    final expandedH = n * (_cardH + _gap) - _gap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              '分类',
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
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _toggle,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: AppTheme.neon,
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
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final height =
                collapsedH + (expandedH - collapsedH) * _ctrl.value;
            return SizedBox(
              height: height + 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < n; i++) _buildCard(i, n),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(int i, int n) {
    final cat = widget.categories[i];
    final color = categoryAccent(cat.id, i);
    final dark = isDarkCard(color);
    final fg = dark ? Colors.white : AppTheme.navy;
    final count = widget.counts[cat.id] ?? 0;

    // Stagger: later cards lag by ~40ms each when expanding.
    final start = (i * _staggerMs) / (_ctrl.duration?.inMilliseconds ?? 1);
    final end = (start + 0.55).clamp(0.0, 1.0);
    final local = Curves.easeOutCubic.transform(
      ((_ctrl.value - start) / (end - start).clamp(0.001, 1.0)).clamp(0.0, 1.0),
    );
    // Spring-ish overshoot soft clamp
    final t = Curves.easeOutBack.transform(local.clamp(0.0, 1.0)).clamp(0.0, 1.15);

    final stackTop = i * _peek;
    final listTop = i * (_cardH + _gap);
    final top = stackTop + (listTop - stackTop) * t.clamp(0.0, 1.0);
    final scale = 1.0 - (1 - t.clamp(0.0, 1.0)) * (n - 1 - i).clamp(0, 5) * 0.015;
    final elev = 6.0 + (1 - t.clamp(0.0, 1.0)) * i * 1.2;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () {
            if (!_expanded) {
              _expand();
              return;
            }
            HapticFeedback.lightImpact();
            widget.onOpen(cat);
          },
          child: Container(
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
                  color: AppTheme.navy.withValues(alpha: 0.18 + i * 0.02),
                  blurRadius: 14 + elev,
                  offset: Offset(0, 6 + elev * 0.4),
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
          ),
        ),
      ),
    );
  }
}
