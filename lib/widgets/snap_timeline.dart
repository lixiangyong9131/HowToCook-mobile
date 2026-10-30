import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Text steps list: top-pinned timeline + content-hugging cards.
///
/// Cards size to their text (no fixed itemExtent / min-height blank).
/// Left rail aligns to each card via IntrinsicHeight — starts at the top.
class SnapTimeline extends StatefulWidget {
  final List<String> steps;
  final ValueChanged<int>? onStepChanged;
  final void Function(int stepIndex, Duration duration)? onStartTimer;
  final Duration? Function(String step)? durationOf;
  final Set<int> timerCompletedSteps;

  const SnapTimeline({
    super.key,
    required this.steps,
    this.onStepChanged,
    this.onStartTimer,
    this.durationOf,
    this.timerCompletedSteps = const {},
  });

  @override
  State<SnapTimeline> createState() => _SnapTimelineState();
}

class _SnapTimelineState extends State<SnapTimeline> {
  final _scroll = ScrollController();
  int _index = 0;
  final Map<int, GlobalKey> _keys = {};

  GlobalKey _keyFor(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateActiveFromScroll();
  }

  void _updateActiveFromScroll() {
    if (!mounted || !_scroll.hasClients) return;
    // Prefer the topmost card whose top is at/above a small inset.
    const probe = 48.0;
    var best = _index;
    var bestDist = double.infinity;
    for (var i = 0; i < widget.steps.length; i++) {
      final ctx = _keyFor(i).currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final listBox = context.findRenderObject() as RenderBox?;
      if (listBox == null) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      final dist = (top - probe).abs();
      if (top <= probe + box.size.height && dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    if (best != _index) {
      setState(() => _index = best);
      widget.onStepChanged?.call(best);
    }
  }

  void _onClockTap(int i, Duration dur) {
    HapticFeedback.selectionClick();
    widget.onStartTimer?.call(i, dur);
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) {
      return const Center(child: Text('暂无步骤'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification || n is ScrollUpdateNotification) {
          _updateActiveFromScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        // Pin to top — no vertical centering padding.
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 100),
        itemCount: steps.length,
        itemBuilder: (context, i) {
          final active = i == _index;
          final dimmed = i != _index;
          final timerDone = widget.timerCompletedSteps.contains(i);
          final text = steps[i]
              .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
              .trim();
          final dur = widget.durationOf?.call(steps[i]);

          return KeyedSubtree(
            key: _keyFor(i),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 28,
                    child: CustomPaint(
                      painter: _StepRailPainter(
                        isFirst: i == 0,
                        isLast: i == steps.length - 1,
                        active: active,
                        lit: i <= _index,
                        done: timerDone,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: active
                            ? Colors.white
                            : timerDone
                                ? AppTheme.softCoral.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.85),
                        elevation: active ? 2 : 0,
                        shadowColor: AppTheme.coral.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _index = i);
                            widget.onStepChanged?.call(i);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? AppTheme.coral
                                    : AppTheme.navy.withValues(alpha: 0.08),
                                width: active ? 2 : 1,
                              ),
                            ),
                            // Tight padding — height hugs content.
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          (i + 1).toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            height: 1.1,
                                            color: AppTheme.navy.withValues(
                                              alpha: active ? 1 : 0.4,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (dur != null)
                                          IconButton(
                                            tooltip: '开始计时 ${_fmt(dur)}',
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            onPressed: () =>
                                                _onClockTap(i, dur),
                                            icon: Icon(
                                              timerDone
                                                  ? Icons.alarm_on_rounded
                                                  : Icons.schedule_rounded,
                                              size: 20,
                                              color: timerDone
                                                  ? AppTheme.coral
                                                  : AppTheme.navy,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: dimmed
                                            ? AppTheme.muted
                                            : AppTheme.navy,
                                      ),
                                    ),
                                    if (active && dur != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '建议 ${_fmt(dur)} · 点右上角时钟开始',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.muted
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (timerDone)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Center(
                                        child: Transform.rotate(
                                          angle: -0.28,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.92),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.coral,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Text(
                                              '计时已完成',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: AppTheme.coral,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) return '${d.inHours}小时';
    if (d.inMinutes > 0) return '${d.inMinutes}分钟';
    return '${d.inSeconds}秒';
  }
}

/// Vertical rail segment for one step row (line + node at mid-height).
class _StepRailPainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final bool active;
  final bool lit;
  final bool done;

  _StepRailPainter({
    required this.isFirst,
    required this.isLast,
    required this.active,
    required this.lit,
    required this.done,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final midY = size.height / 2;
    final track = Paint()
      ..color = AppTheme.navy.withValues(alpha: 0.14)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = lit ? AppTheme.coral : AppTheme.navy.withValues(alpha: 0.14)
      ..strokeWidth = lit ? 2.5 : 2
      ..strokeCap = StrokeCap.round;

    if (!isFirst) {
      canvas.drawLine(Offset(x, 0), Offset(x, midY), lit ? fill : track);
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(x, midY),
        Offset(x, size.height),
        // Segment below stays muted until later steps activate.
        track,
      );
    }

    final r = active ? 7.0 : 5.0;
    final fillC = done
        ? AppTheme.neon
        : (lit || active ? AppTheme.coral : Colors.white);
    final strokeC =
        active ? AppTheme.navy : AppTheme.navy.withValues(alpha: 0.28);
    canvas.drawCircle(Offset(x, midY), r, Paint()..color = fillC);
    canvas.drawCircle(
      Offset(x, midY),
      r,
      Paint()
        ..color = strokeC
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _StepRailPainter old) =>
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.active != active ||
      old.lit != lit ||
      old.done != done;
}
