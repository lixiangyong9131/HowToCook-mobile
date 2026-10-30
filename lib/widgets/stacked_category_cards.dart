import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Interaction 3 — overlapping stack that fans into a colorful list.
class StackedCategoryCards extends StatefulWidget {
  final List<CategoryInfo> categories;
  final Map<String, int> counts;
  final ValueChanged<CategoryInfo> onOpen;
  final bool initiallyExpanded;

  const StackedCategoryCards({
    super.key,
    required this.categories,
    required this.counts,
    required this.onOpen,
    this.initiallyExpanded = false,
  });

  @override
  State<StackedCategoryCards> createState() => _StackedCategoryCardsState();
}

class _StackedCategoryCardsState extends State<StackedCategoryCards>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: _expanded ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final n = cats.length;
    // Collapsed stack height vs expanded list height.
    const cardH = 76.0;
    const peek = 18.0;
    final collapsedH = cardH + peek * (n.clamp(0, 4) - 1).clamp(0, 99);
    final expandedH = n * (cardH + 10) - 10;

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
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _toggle,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.ink,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                _expanded ? '叠起' : '展开',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_ctrl.value);
            final height = collapsedH + (expandedH - collapsedH) * t;
            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < n; i++)
                    _buildCard(i, n, t, cardH, peek),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(int i, int n, double t, double cardH, double peek) {
    final cat = widget.categories[i];
    final color = categoryAccent(cat.id, i);
    final dark = isDarkCard(color);
    final fg = dark ? Colors.white : AppTheme.ink;
    final count = widget.counts[cat.id] ?? 0;

    // Collapsed: stacked with peeks from top; Expanded: vertical list.
    final stackTop = i * peek;
    final listTop = i * (cardH + 10);
    final top = stackTop + (listTop - stackTop) * t;
    // Slight horizontal offset when stacked for depth.
    final dx = (1 - t) * (i % 2 == 0 ? -2.0 : 2.0);
    final scale = 1.0 - (1 - t) * (n - 1 - i).clamp(0, 3) * 0.012;

    return AnimatedPositioned(
      duration: Duration.zero,
      top: top,
      left: 0 + dx,
      right: 0 - dx,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () {
            if (!_expanded) {
              _toggle();
              return;
            }
            widget.onOpen(cat);
          },
          child: Container(
            height: cardH,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: color == Colors.white
                  ? Border.all(color: const Color(0xFFE5E5EA))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08 + (1 - t) * 0.04),
                  blurRadius: 16,
                  offset: Offset(0, 6 + (1 - t) * 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  categoryEmojis[cat.id] ?? '📖',
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      color: fg,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 28,
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
