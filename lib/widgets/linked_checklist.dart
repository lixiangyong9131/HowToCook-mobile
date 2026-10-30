import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Interaction 2 — one checkbox tap drives progress ring + rolling fraction + tint.
class LinkedChecklist extends StatefulWidget {
  final List<String> items;
  final String title;
  final ValueChanged<Set<int>>? onChanged;
  final ValueChanged<bool>? onAllDone;

  const LinkedChecklist({
    super.key,
    required this.items,
    this.title = '原料清单',
    this.onChanged,
    this.onAllDone,
  });

  @override
  State<LinkedChecklist> createState() => _LinkedChecklistState();
}

class _LinkedChecklistState extends State<LinkedChecklist>
    with SingleTickerProviderStateMixin {
  final Set<int> _checked = {};
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toggle(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_checked.contains(i)) {
        _checked.remove(i);
      } else {
        _checked.add(i);
      }
    });
    _pulse.forward(from: 0);
    widget.onChanged?.call(Set.unmodifiable(_checked));
    if (_checked.length == widget.items.length && widget.items.isNotEmpty) {
      widget.onAllDone?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final done = _checked.length;
    final progress = total == 0 ? 0.0 : done / total;
    final tint = Color.lerp(Colors.white, AppTheme.lime, progress * 0.85)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: AppTheme.softShadow(opacity: 0.06),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CustomPaint(
                      painter: _RingPainter(
                        progress: value,
                        track: AppTheme.ink.withValues(alpha: 0.12),
                        fill: AppTheme.ink,
                      ),
                      child: Center(
                        child: Text(
                          '${(value * 100).round()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppTheme.ink.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _RollingFraction(done: done, total: total),
                    const SizedBox(height: 2),
                    Text(
                      done == total && total > 0 ? '全部备齐' : '勾选已备原料',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.ink.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(widget.items.length, (i) {
          final checked = _checked.contains(i);
          return _CheckRow(
            text: widget.items[i],
            checked: checked,
            onTap: () => _toggle(i),
          );
        }),
      ],
    );
  }
}

class _RollingFraction extends StatelessWidget {
  final int done;
  final int total;
  const _RollingFraction({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(done),
          tween: Tween(begin: (done - 1).clamp(0, total).toDouble(), end: done.toDouble()),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            return Text(
              '${v.round()}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1,
              ),
            );
          },
        ),
        Text(
          '/$total',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String text;
  final bool checked;
  final VoidCallback onTap;
  const _CheckRow({
    required this.text,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: checked ? AppTheme.lime : Colors.transparent,
                    border: Border.all(
                      color: checked ? AppTheme.ink : const Color(0xFFC7C7CC),
                      width: 1.6,
                    ),
                  ),
                  child: checked
                      ? const Icon(Icons.check, size: 16, color: AppTheme.ink)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text.replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '').trim(),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                      color: checked
                          ? AppTheme.muted
                          : AppTheme.ink,
                      fontWeight: FontWeight.w500,
                    ),
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color fill;
  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 4;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
