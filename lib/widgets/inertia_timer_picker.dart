import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Interaction 5 — inertia wheel hour:minute picker (cream/coral capsule).
Future<Duration?> showInertiaTimerPicker(
  BuildContext context, {
  Duration initial = const Duration(minutes: 5),
}) {
  return showModalBottomSheet<Duration>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => InertiaTimerSheet(initial: initial),
  );
}

class InertiaTimerSheet extends StatefulWidget {
  final Duration initial;
  const InertiaTimerSheet({super.key, required this.initial});

  @override
  State<InertiaTimerSheet> createState() => _InertiaTimerSheetState();
}

class _InertiaTimerSheetState extends State<InertiaTimerSheet> {
  late int _hour;
  late int _min;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;

  @override
  void initState() {
    super.initState();
    final totalMin = widget.initial.inMinutes.clamp(0, 12 * 60);
    _hour = totalMin ~/ 60;
    _min = totalMin % 60;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minCtrl = FixedExtentScrollController(initialItem: _min);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        '${_hour.toString().padLeft(2, '0')}:${_min.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow(opacity: 0.18),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '计时',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  'HOUR : MINUTE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
            const Text(
              '甩动滚轮选择时间（带惯性与回弹）',
              style: TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                height: 1,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft cream/coral highlight capsule (not purple)
                  Container(
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.softCoral.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.coral.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.coral.withValues(alpha: 0.18),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _InertiaWheel(
                          controller: _hourCtrl,
                          itemCount: 13, // 0..12 hours
                          labelBuilder: (i) => i.toString().padLeft(2, '0'),
                          onSelected: (i) {
                            HapticFeedback.selectionClick();
                            setState(() => _hour = i);
                          },
                        ),
                      ),
                      const Text(
                        ':',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy,
                        ),
                      ),
                      Expanded(
                        child: _InertiaWheel(
                          controller: _minCtrl,
                          itemCount: 60,
                          labelBuilder: (i) => i.toString().padLeft(2, '0'),
                          onSelected: (i) {
                            HapticFeedback.selectionClick();
                            setState(() => _min = i);
                          },
                        ),
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Column(
                      children: [
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppTheme.radius),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(AppTheme.radius),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('时',
                    style: TextStyle(
                        color: AppTheme.muted, fontWeight: FontWeight.w600)),
                SizedBox(width: 80),
                Text('分',
                    style: TextStyle(
                        color: AppTheme.muted, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: AppTheme.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  final d = Duration(hours: _hour, minutes: _min);
                  if (d.inSeconds <= 0) return;
                  Navigator.of(context).pop(d);
                },
                child: const Text(
                  '开始计时',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InertiaWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onSelected;

  const _InertiaWheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 48,
      perspective: 0.0025,
      diameterRatio: 1.4,
      // Velocity + friction snap; rubber-band via BouncingScrollPhysics
      physics: const FixedExtentScrollPhysics(
        parent: BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.normal,
        ),
      ),
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, i) {
          // Magnifier feel via ListWheel — center is naturally larger via perspective
          return Center(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                double selected = 0;
                try {
                  selected = controller.selectedItem.toDouble();
                } catch (_) {}
                final dist = (i - selected).abs();
                final t = (1 - dist * 0.35).clamp(0.35, 1.0);
                return Opacity(
                  opacity: t,
                  child: Text(
                    labelBuilder(i),
                    style: TextStyle(
                      fontSize: 22 + 12 * t,
                      fontWeight: dist < 0.5 ? FontWeight.w900 : FontWeight.w600,
                      color: AppTheme.navy.withValues(alpha: 0.45 + 0.55 * t),
                      height: 1,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Compact running timer bar.
class RunningTimerBar extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final VoidCallback onClose;

  const RunningTimerBar({
    super.key,
    required this.remaining,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds == 0
        ? 0.0
        : 1 - remaining.inMilliseconds / total.inMilliseconds;
    final mm = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = remaining.inHours;
    final label = hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppTheme.navy,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppTheme.softShadow(opacity: 0.25),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppTheme.coral,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 5,
                      color: AppTheme.coral,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

mixin CountdownTimerMixin<T extends StatefulWidget> on State<T> {
  Timer? countdownTimer;
  Duration? remaining;
  Duration? total;

  void startCountdown(Duration d) {
    countdownTimer?.cancel();
    setState(() {
      total = d;
      remaining = d;
    });
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remaining == null) return;
      if (remaining!.inSeconds <= 1) {
        t.cancel();
        setState(() => remaining = Duration.zero);
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⏰ 计时结束！')),
          );
        }
      } else {
        setState(() => remaining = remaining! - const Duration(seconds: 1));
      }
    });
  }

  void stopCountdown() {
    countdownTimer?.cancel();
    setState(() {
      remaining = null;
      total = null;
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }
}
