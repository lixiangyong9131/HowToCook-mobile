import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Interaction 2 — big progress ring + rolling n/N + card tints green (bold).
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
    HapticFeedback.mediumImpact();
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
    final tint = Color.lerp(Colors.white, AppTheme.neon, progress * 0.72)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: AppTheme.softShadow(opacity: 0.14),
            border: Border.all(
              color: Color.lerp(
                    AppTheme.purple.withValues(alpha: 0.15),
                    AppTheme.neon,
                    progress,
                  ) ??
                  AppTheme.neon,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CustomPaint(
                      painter: _RingPainter(
                        progress: value,
                        track: AppTheme.navy.withValues(alpha: 0.12),
                        fill: AppTheme.navy,
                        glow: AppTheme.neon,
                      ),
                      child: Center(
                        child: Text(
                          '${(value * 100).round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.navy.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _RollingFraction(done: done, total: total),
                    const SizedBox(height: 4),
                    Text(
                      done == total && total > 0 ? '✓ 全部备齐！' : '勾选已备原料 → 卡片变绿',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
          tween: Tween(
            begin: (done - 1).clamp(0, total).toDouble(),
            end: done.toDouble(),
          ),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            return Text(
              '${v.round()}',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1.5,
                color: AppTheme.navy,
              ),
            );
          },
        ),
        Text(
          '/$total',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy.withValues(alpha: 0.4),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: checked
            ? AppTheme.neon.withValues(alpha: 0.35)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: checked
                    ? AppTheme.neon
                    : AppTheme.purple.withValues(alpha: 0.15),
                width: checked ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: checked ? AppTheme.neon : Colors.transparent,
                    border: Border.all(
                      color: checked ? AppTheme.navy : const Color(0xFFC7C7CC),
                      width: 2,
                    ),
                  ),
                  child: checked
                      ? const Icon(Icons.check, size: 18, color: AppTheme.navy)
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
                      color: checked ? AppTheme.muted : AppTheme.navy,
                      fontWeight: FontWeight.w600,
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
  final Color glow;
  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
