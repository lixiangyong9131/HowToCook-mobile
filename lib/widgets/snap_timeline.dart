import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'squeeze_done_button.dart';

/// Interaction 4 — magnetic snap cards + dashed timeline.
class SnapTimeline extends StatefulWidget {
  final List<String> steps;
  final ValueChanged<int>? onStepChanged;
  final ValueChanged<Duration>? onPickTimer;
  final Duration? Function(String step)? durationOf;

  const SnapTimeline({
    super.key,
    required this.steps,
    this.onStepChanged,
    this.onPickTimer,
    this.durationOf,
  });

  @override
  State<SnapTimeline> createState() => _SnapTimelineState();
}

class _SnapTimelineState extends State<SnapTimeline> {
  late final PageController _page;
  int _index = 0;
  final Set<int> _done = {};
  final _doneKey = GlobalKey<SqueezeDoneButtonState>();

  @override
  void initState() {
    super.initState();
    _page = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _completeCurrent() {
    setState(() {
      _done.add(_index);
      if (_index < widget.steps.length - 1) {
        _index++;
        _page.animateToPage(
          _index,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
    widget.onStepChanged?.call(_index);
    _doneKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) {
      return const Center(child: Text('暂无步骤'));
    }

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: steps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final active = i == _index;
              final done = _done.contains(i);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: active ? 22 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: done
                      ? AppTheme.lime
                      : active
                          ? AppTheme.ink
                          : const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dashed timeline rail
              SizedBox(
                width: 36,
                child: CustomPaint(
                  painter: _DashLinePainter(
                    count: steps.length,
                    active: _index,
                    done: _done,
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  scrollDirection: Axis.vertical,
                  physics: const _SnapPagePhysics(),
                  itemCount: steps.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _index = i);
                    widget.onStepChanged?.call(i);
                  },
                  itemBuilder: (context, i) {
                    final active = i == _index;
                    final done = _done.contains(i);
                    final text = steps[i]
                        .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
                        .trim();
                    final dur = widget.durationOf?.call(steps[i]);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      margin: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.lime
                            : done
                                ? AppTheme.lavender.withValues(alpha: 0.55)
                                : Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radius),
                        border: active
                            ? null
                            : Border.all(color: const Color(0xFFE5E5EA)),
                        boxShadow: active
                            ? AppTheme.softShadow(opacity: 0.12)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (i + 1).toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.ink.withValues(
                                    alpha: active ? 1 : 0.35,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (done)
                                const Icon(Icons.check_circle,
                                    color: AppTheme.ink),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          if (active) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (dur != null)
                                  TextButton.icon(
                                    onPressed: () =>
                                        widget.onPickTimer?.call(dur),
                                    icon: const Icon(Icons.timer_outlined,
                                        size: 18),
                                    label: Text(_fmt(dur)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.ink,
                                    ),
                                  ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () =>
                                      widget.onPickTimer?.call(
                                    dur ?? const Duration(minutes: 5),
                                  ),
                                  child: const Text('计时'),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 200,
                                child: SqueezeDoneButton(
                                  key: _doneKey,
                                  label: i == steps.length - 1
                                      ? '全部完成'
                                      : '完成这一步',
                                  onCompleted: _completeCurrent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) return '${d.inHours}小时';
    if (d.inMinutes > 0) return '${d.inMinutes}分钟';
    return '${d.inSeconds}秒';
  }
}

class _DashLinePainter extends CustomPainter {
  final int count;
  final int active;
  final Set<int> done;
  _DashLinePainter({
    required this.count,
    required this.active,
    required this.done,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final x = size.width / 2;
    final paint = Paint()
      ..color = const Color(0xFFC7C7CC)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // dashed line
    const dash = 5.0;
    const gap = 4.0;
    var y = 24.0;
    final end = size.height - 24;
    while (y < end) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + dash).clamp(0, end)), paint);
      y += dash + gap;
    }

    for (var i = 0; i < count; i++) {
      final yy = 40.0 + i * ((size.height - 80) / (count.clamp(1, 999)));
      final isActive = i == active;
      final isDone = done.contains(i);
      final fill = isDone
          ? AppTheme.lime
          : isActive
              ? AppTheme.blue
              : Colors.white;
      final stroke = isActive ? AppTheme.blue : const Color(0xFFC7C7CC);
      canvas.drawCircle(
        Offset(x, yy.clamp(24, size.height - 24)),
        isActive ? 7 : 5,
        Paint()..color = fill,
      );
      canvas.drawCircle(
        Offset(x, yy.clamp(24, size.height - 24)),
        isActive ? 7 : 5,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashLinePainter old) =>
      old.active != active || old.done != done || old.count != count;
}

/// Vertical PageView that snaps firmly to pages.
class _SnapPagePhysics extends PageScrollPhysics {
  const _SnapPagePhysics({super.parent});

  @override
  _SnapPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.9,
        stiffness: 140,
        damping: 18,
      );
}
