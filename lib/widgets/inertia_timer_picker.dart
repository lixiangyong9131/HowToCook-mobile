import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Interaction 5 — inertia wheel duration picker (min + sec).
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
  late int _min;
  late int _sec;
  late FixedExtentScrollController _minCtrl;
  late FixedExtentScrollController _secCtrl;

  @override
  void initState() {
    super.initState();
    _min = widget.initial.inMinutes.clamp(0, 180);
    _sec = widget.initial.inSeconds.remainder(60);
    // snap sec to 5s steps for nicer feel
    _sec = (_sec ~/ 5) * 5;
    _minCtrl = FixedExtentScrollController(initialItem: _min);
    _secCtrl = FixedExtentScrollController(initialItem: _sec ~/ 5);
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        '${_min.toString().padLeft(2, '0')}:${_sec.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.bg,
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
                  'SET A TIME',
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
              '上下甩动滚轮选择时间',
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
                  // Lavender selection capsule
                  Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.lavender,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.purple, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.purple.withValues(alpha: 0.25),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _Wheel(
                          controller: _minCtrl,
                          itemCount: 181,
                          labelBuilder: (i) => i.toString().padLeft(2, '0'),
                          onSelected: (i) {
                            HapticFeedback.selectionClick();
                            setState(() => _min = i);
                          },
                        ),
                      ),
                      const Text(
                        ':',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Expanded(
                        child: _Wheel(
                          controller: _secCtrl,
                          itemCount: 12, // 0,5,...,55
                          labelBuilder: (i) =>
                              (i * 5).toString().padLeft(2, '0'),
                          onSelected: (i) {
                            HapticFeedback.selectionClick();
                            setState(() => _sec = i * 5);
                          },
                        ),
                      ),
                    ],
                  ),
                  // top/bottom fade
                  IgnorePointer(
                    child: Column(
                      children: [
                        Container(
                          height: 40,
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
                          height: 40,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('分', style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
                const SizedBox(width: 80),
                Text('秒', style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: AppTheme.neon,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  final d = Duration(minutes: _min, seconds: _sec);
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

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onSelected;

  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 52,
      perspective: 0.003,
      diameterRatio: 1.35,
      physics: const FixedExtentScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, i) {
          return Center(
            child: Text(
              labelBuilder(i),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact running timer bar (shown while countdown active).
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
          color: AppTheme.blackCard,
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
                color: AppTheme.lime,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer, color: AppTheme.ink, size: 20),
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
                      color: AppTheme.lime,
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

/// Helper to drive a countdown from a State that owns a Timer.
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
