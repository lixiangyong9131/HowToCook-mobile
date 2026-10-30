import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'squeeze_done_button.dart';

/// Interaction 4 — Snap cards first, THEN draw timeline (never while scrolling).
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

class _SnapTimelineState extends State<SnapTimeline>
    with TickerProviderStateMixin {
  late final ScrollController _scroll;
  int _index = 0;
  bool _scrolling = false;
  final Set<int> _done = {};
  final _doneKey = GlobalKey<SqueezeDoneButtonState>();

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
    if (( _scroll.offset - target).abs() > 0.5) {
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
    // Draw timeline ONLY after fully settled.
    _drawCtrl.forward(from: 0);
  }

  void _completeCurrent() {
    setState(() {
      _done.add(_index);
      if (_index < widget.steps.length - 1) {
        _index++;
      }
    });
    widget.onStepChanged?.call(_index);
    _doneKey.currentState?.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _index * _cardExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      ).then((_) {
        if (!mounted) return;
        setState(() => _scrolling = false);
        _drawCtrl.forward(from: 0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) {
      return const Center(child: Text('暂无步骤'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _cardExtent = math.min(240.0, math.max(180.0, constraints.maxHeight * 0.42));
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification) {
              SchedulerBinding.instance.addPostFrameCallback((_) => _onScrollEnd());
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
                        done: _done,
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
                    final done = _done.contains(i);
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
                            vertical: 8,
                            horizontal: 6,
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : done
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    (i + 1).toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.navy.withValues(
                                        alpha: active ? 1 : 0.35,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (done)
                                    const Icon(Icons.check_circle,
                                        color: AppTheme.coral),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
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
                              if (active) ...[
                                const SizedBox(height: 4),
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
                                          foregroundColor: AppTheme.navy,
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
  final Set<int> done;
  final double drawProgress; // 0 while scrolling; 0→1 after settle
  final double cardExtent;
  final double scrollOffset;

  _TimelinePainter({
    required this.count,
    required this.active,
    required this.done,
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

    // Track (faint) full line
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

    // Animated drawn segment top → active (only when settled)
    if (drawProgress > 0 && centers.isNotEmpty) {
      final endY = centers[active.clamp(0, centers.length - 1)];
      final startY = centers.first;
      final drawnY = startY + (endY - startY) * Curves.easeOutCubic.transform(drawProgress);
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
      final isDone = done.contains(i);
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
      old.done != done ||
      old.drawProgress != drawProgress ||
      old.scrollOffset != scrollOffset ||
      old.cardExtent != cardExtent ||
      old.count != count;
}
