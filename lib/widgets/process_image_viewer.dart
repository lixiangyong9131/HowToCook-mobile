import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// 做法大图 viewer.
///
/// **Pull-up enlarge (restored):** dragging upward continuously scales the
/// image (progressive). Releasing past a threshold / with upward fling
/// completes the same **maximize** as tap — a fullscreen viewer. This is
/// NOT InteractiveViewer pinch-zoom on tap.
class ProcessImageViewer extends StatefulWidget {
  final Future<File?> Function() loader;
  final String? remoteUrl;
  final VoidCallback? onFallbackSteps;

  const ProcessImageViewer({
    super.key,
    required this.loader,
    this.remoteUrl,
    this.onFallbackSteps,
  });

  @override
  State<ProcessImageViewer> createState() => _ProcessImageViewerState();
}

class _ProcessImageViewerState extends State<ProcessImageViewer>
    with SingleTickerProviderStateMixin {
  late Future<File?> _future;

  /// Accumulated upward drag in logical pixels (0 = rest).
  double _pullPx = 0;
  late final AnimationController _pullBackCtrl;
  double _pullBackFrom = 0;

  static const _pullPerScale = 240.0; // px → +1.0 scale
  static const _maxPullScale = 1.55;
  static const _commitScale = 1.18; // release above this → maximize
  static const _commitVelocity = -420.0; // px/s upward

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
    _pullBackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _pullPx = _pullBackFrom * (1.0 - _pullBackCtrl.value);
        });
      });
  }

  @override
  void didUpdateWidget(covariant ProcessImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      _future = widget.loader();
    }
  }

  @override
  void dispose() {
    _pullBackCtrl.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _future = widget.loader());
  }

  double get _pullScale =>
      (1.0 + _pullPx / _pullPerScale).clamp(1.0, _maxPullScale);

  void _onPullUpdate(DragUpdateDetails d) {
    // Only upward drag enlarges (negative dy in Flutter).
    final dy = d.delta.dy;
    if (dy < 0) {
      setState(() => _pullPx = (_pullPx - dy).clamp(0.0, _pullPerScale * 1.2));
    } else if (_pullPx > 0) {
      setState(() => _pullPx = (_pullPx - dy).clamp(0.0, _pullPerScale * 1.2));
    }
  }

  void _onPullEnd(DragEndDetails d, Widget imageChild) {
    final v = d.primaryVelocity ?? 0;
    if (_pullScale >= _commitScale || v < _commitVelocity) {
      _maximize(imageChild);
    } else {
      _pullBackFrom = _pullPx;
      _pullBackCtrl.forward(from: 0);
    }
  }

  /// Same maximize end-state for completed pull-up and tap.
  void _maximize(Widget imageChild) {
    HapticFeedback.lightImpact();
    _pullPx = 0;
    _pullBackCtrl.stop();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, anim, _) {
          return FadeTransition(
            opacity: anim,
            child: _FullscreenProcessImage(image: imageChild),
          );
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _pullPx = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bg,
      child: FutureBuilder<File?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.navy),
                  SizedBox(height: 12),
                  Text(
                    '正在加载整图做法…',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ],
              ),
            );
          }
          final file = snap.data;
          if (file == null) {
            final url = widget.remoteUrl;
            if (url != null && url.isNotEmpty) {
              final net = Image.network(
                url,
                fit: BoxFit.contain,
                width: double.infinity,
                filterQuality: FilterQuality.high,
                headers: const {
                  'User-Agent': 'HowToCook-mobile/0.6.5',
                  'Accept': 'image/jpeg,image/*;q=0.8',
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.navy),
                  );
                },
                errorBuilder: (_, __, ___) => _Unavailable(
                  onRetry: _retry,
                  onFallbackSteps: widget.onFallbackSteps,
                ),
              );
              return _PullEnlargeImage(
                scale: _pullScale,
                pullProgress: ((_pullScale - 1) / (_maxPullScale - 1))
                    .clamp(0.0, 1.0),
                onTap: () => _maximize(net),
                onVerticalDragUpdate: _onPullUpdate,
                onVerticalDragEnd: (d) => _onPullEnd(d, net),
                child: net,
              );
            }
            return _Unavailable(
              onRetry: _retry,
              onFallbackSteps: widget.onFallbackSteps,
            );
          }

          final fileImg = Image.file(
            file,
            fit: BoxFit.contain,
            width: double.infinity,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('图片损坏，请重试下载'),
            ),
          );
          return _PullEnlargeImage(
            scale: _pullScale,
            pullProgress:
                ((_pullScale - 1) / (_maxPullScale - 1)).clamp(0.0, 1.0),
            onTap: () => _maximize(fileImg),
            onVerticalDragUpdate: _onPullUpdate,
            onVerticalDragEnd: (d) => _onPullEnd(d, fileImg),
            child: fileImg,
          );
        },
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback? onFallbackSteps;

  const _Unavailable({required this.onRetry, this.onFallbackSteps});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暂无图片',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              ProcessImageService.attribution,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (onFallbackSteps != null)
              TextButton(
                onPressed: onFallbackSteps,
                child: const Text('返回步骤'),
              ),
            TextButton(
              onPressed: onRetry,
              child: const Text('重试下载'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline image with progressive pull-up scale + tap maximize.
/// No InteractiveViewer here — pinch/zoom only after maximize.
class _PullEnlargeImage extends StatelessWidget {
  final Widget child;
  final double scale;
  final double pullProgress;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  const _PullEnlargeImage({
    required this.child,
    required this.scale,
    required this.pullProgress,
    required this.onTap,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onVerticalDragUpdate: onVerticalDragUpdate,
                onVerticalDragEnd: onVerticalDragEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Dim scrim grows as user pulls up (pre-maximize cue).
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55 * pullProgress),
                    ),
                    Center(
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Center(child: child),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '${ProcessImageService.attribution}\n上滑持续放大 · 松手最大化 · 点按同样最大化',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fullscreen maximize end-state (pinch/drag here; swipe down to close).
class _FullscreenProcessImage extends StatefulWidget {
  final Widget image;
  const _FullscreenProcessImage({required this.image});

  @override
  State<_FullscreenProcessImage> createState() =>
      _FullscreenProcessImageState();
}

class _FullscreenProcessImageState extends State<_FullscreenProcessImage> {
  final _transform = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      final scale = _transform.value.getMaxScaleOnAxis();
      final z = (scale - 1.0).abs() >= 0.08;
      if (z != _zoomed && mounted) setState(() => _zoomed = z);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _close() {
    HapticFeedback.selectionClick();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onVerticalDragEnd: _zoomed
                ? null
                : (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v > 500) _close();
                  },
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.5,
              maxScale: 5,
              panEnabled: _zoomed,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                child: Center(child: widget.image),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 8,
            right: 12,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              tooltip: '关闭',
              onPressed: _close,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: math.max(pad.bottom, 12) + 8,
            child: Text(
              '双指缩放 · 下滑关闭',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
