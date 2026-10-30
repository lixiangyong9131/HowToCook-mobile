import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Interaction 3 — overlapping stack that FANS OUT with spring (bold, obvious).
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
  late bool _expanded;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && !widget.autoFanOnMount;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      value: _expanded ? 1 : 0,
    );
    if (widget.autoFanOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 280));
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() => _expanded = true);
        _ctrl.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
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
    const cardH = 88.0;
    const peek = 22.0;
    final collapsedH = cardH + peek * (n.clamp(0, 5) - 1).clamp(0, 99);
    final expandedH = n * (cardH + 12) - 12;

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            final t = Curves.elasticOut.transform(_ctrl.value.clamp(0.0, 1.0));
            // elasticOut can overshoot >1 — clamp height math
            final tt = t.clamp(0.0, 1.15);
            final height = collapsedH + (expandedH - collapsedH) * tt.clamp(0.0, 1.0);
            return SizedBox(
              height: height + 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < n; i++)
                    _buildCard(i, n, tt.clamp(0.0, 1.0), cardH, peek),
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
    final fg = dark ? Colors.white : AppTheme.navy;
    final count = widget.counts[cat.id] ?? 0;

    final stackTop = i * peek;
    final listTop = i * (cardH + 12);
    final top = stackTop + (listTop - stackTop) * t;
    final dx = (1 - t) * (i % 2 == 0 ? -6.0 : 6.0);
    final rot = (1 - t) * (i % 2 == 0 ? -0.03 : 0.03);
    final scale = 1.0 - (1 - t) * (n - 1 - i).clamp(0, 4) * 0.02;

    return Positioned(
      top: top,
      left: 0 + dx,
      right: 0 - dx,
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              if (!_expanded) {
                _toggle();
                return;
              }
              HapticFeedback.lightImpact();
              widget.onOpen(cat);
            },
            child: Container(
              height: cardH,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: color == Colors.white
                    ? Border.all(color: AppTheme.purple.withValues(alpha: 0.2))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: Offset(0, 8 + (1 - t) * 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    categoryEmojis[cat.id] ?? '📖',
                    style: const TextStyle(fontSize: 32),
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
      ),
    );
  }
}
