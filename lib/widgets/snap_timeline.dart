import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Interaction 4 — Snap cards first, THEN draw timeline (never while scrolling).
///
/// No 「完成这一步」 button. Steps with a duration show a clock icon (top-right);
/// when that step's timer finishes, the card is stamped 「计时已完成」.
class SnapTimeline extends StatefulWidget {
  final List<String> steps;
  final ValueChanged<int>? onStepChanged;
  /// Start a timer for [stepIndex] with [duration].
  final void Function(int stepIndex, Duration duration)? onStartTimer;
  final Duration? Function(String step)? durationOf;
  /// Step indices whose timer has finished (stamped 「计时已完成」).
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

class _SnapTimelineState extends State<SnapTimeline>
    with TickerProviderStateMixin {
  late final ScrollController _scroll;
  int _index = 0;
  bool _scrolling = false;

  late final AnimationController _drawCtrl;
  double _cardExtent = 220;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
    _drawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drawCtrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _drawCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrolling) {
      setState(() => _scrolling = true);
      _drawCtrl.stop();
      _drawCtrl.value = 0;
    }
    final i = _nearestIndex();
    if (i != _index) {
      setState(() => _index = i);
    }
  }

  int _nearestIndex() {
    if (!_scroll.hasClients || _cardExtent <= 0) return _index;
    final offset = _scroll.offset;
    final i = (offset / _cardExtent).round().clamp(0, widget.steps.length - 1);
    return i;
  }

  Future<void> _onScrollEnd() async {
    if (!_scroll.hasClients) return;
    final i = _nearestIndex();
    final target = i * _cardExtent;
    if ((_scroll.offset - target).abs() > 0.5) {
      await _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = i;
      _scrolling = false;
    });
    widget.onStepChanged?.call(i);
    _drawCtrl.forward(from: 0);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        _cardExtent =
            math.min(196.0, math.max(148.0, constraints.maxHeight * 0.34));
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification) {
              SchedulerBinding.instance
                  .addPostFrameCallback((_) => _onScrollEnd());
            }
            return false;
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_drawCtrl, _scroll]),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _TimelinePainter(
                        count: steps.length,
                        active: _index,
                        timerDone: widget.timerCompletedSteps,
                        drawProgress: _scrolling ? 0 : _drawCtrl.value,
                        cardExtent: _cardExtent,
                        scrollOffset: _scroll.hasClients ? _scroll.offset : 0,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: (constraints.maxHeight - _cardExtent) / 2,
                  ),
                  itemCount: steps.length,
                  itemExtent: _cardExtent,
                  itemBuilder: (context, i) {
                    final active = i == _index && !_scrolling;
                    final dimmed = i != _index;
                    final timerDone = widget.timerCompletedSteps.contains(i);
                    final text = steps[i]
                        .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
                        .trim();
                    final dur = widget.durationOf?.call(steps[i]);
                    return AnimatedScale(
                      scale: active ? 1.0 : 0.94,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: dimmed ? 0.45 : 1,
                        duration: const Duration(milliseconds: 280),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : timerDone
                                    ? AppTheme.softCoral.withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.7),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius),
                            border: Border.all(
                              color: active
                                  ? AppTheme.coral
                                  : AppTheme.navy.withValues(alpha: 0.08),
                              width: active ? 2.5 : 1,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: AppTheme.coral
                                          .withValues(alpha: 0.28),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ]
                                : AppTheme.softShadow(opacity: 0.05),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          (i + 1).toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.navy.withValues(
                                              alpha: active ? 1 : 0.35,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        // Clock only when this step has a timer.
                                        if (dur != null)
                                          IconButton(
                                            tooltip: '开始计时 ${_fmt(dur)}',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            onPressed: () =>
                                                _onClockTap(i, dur),
                                            icon: Icon(
                                              timerDone
                                                  ? Icons.alarm_on_rounded
                                                  : Icons.schedule_rounded,
                                              color: timerDone
                                                  ? AppTheme.coral
                                                  : AppTheme.navy,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        physics:
                                            const BouncingScrollPhysics(),
                                        child: Text(
                                          text,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            fontWeight: active
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: dimmed
                                                ? AppTheme.muted
                                                : AppTheme.navy,
                                          ),
                                        ),
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
                              ),
                              if (timerDone)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Transform.rotate(
                                        angle: -0.28,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.92),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppTheme.coral,
                                              width: 2.5,
                                            ),
                                            boxShadow:
                                                AppTheme.softShadow(opacity: 0.12),
                                          ),
                                          child: const Text(
                                            '计时已完成',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.coral,
                                              letterSpacing: 1.2,
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
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) return '${d.inHours}小时';
    if (d.inMinutes > 0) return '${d.inMinutes}分钟';
    return '${d.inSeconds}秒';
  }
}

class _TimelinePainter extends CustomPainter {
  final int count;
  final int active;
  final Set<int> timerDone;
  final double drawProgress; // 0 while scrolling; 0→1 after settle
  final double cardExtent;
  final double scrollOffset;

  _TimelinePainter({
    required this.count,
    required this.active,
    required this.timerDone,
    required this.drawProgress,
    required this.cardExtent,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final x = size.width / 2;
    final pad = size.height / 2;
    final centers = <double>[];
    for (var i = 0; i < count; i++) {
      final y = pad + i * cardExtent + cardExtent / 2 - scrollOffset;
      centers.add(y);
    }

    final track = Paint()
      ..color = AppTheme.navy.withValues(alpha: 0.12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (centers.length >= 2) {
      canvas.drawLine(
        Offset(x, centers.first),
        Offset(x, centers.last),
        track,
      );
    }

    if (drawProgress > 0 && centers.isNotEmpty) {
      final endY = centers[active.clamp(0, centers.length - 1)];
      final startY = centers.first;
      final drawnY =
          startY + (endY - startY) * Curves.easeOutCubic.transform(drawProgress);
      final glow = Paint()
        ..color = AppTheme.coral.withValues(alpha: 0.55)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final fill = Paint()
        ..color = AppTheme.coral
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, startY), Offset(x, drawnY), glow);
      canvas.drawLine(Offset(x, startY), Offset(x, drawnY), fill);
    }

    for (var i = 0; i < centers.length; i++) {
      final y = centers[i];
      if (y < -20 || y > size.height + 20) continue;
      final isActive = i == active;
      final isDone = timerDone.contains(i);
      final lit = drawProgress > 0.15 && i <= active;
      final r = isActive ? 8.0 : 5.5;
      final fillC = isDone
          ? AppTheme.neon
          : (lit ? AppTheme.coral : Colors.white);
      final strokeC = isActive
          ? AppTheme.navy
          : AppTheme.navy.withValues(alpha: 0.25);
      canvas.drawCircle(Offset(x, y), r, Paint()..color = fillC);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = strokeC
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.active != active ||
      old.timerDone != timerDone ||
      old.drawProgress != drawProgress ||
      old.scrollOffset != scrollOffset ||
      old.cardExtent != cardExtent ||
      old.count != count;
}
