import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Zoomable full-process recipe card (9:16 AI infographic).
///
/// Keeps the v0.6.6/0.6.7 InteractiveViewer 上滑 browse. Tap and a committed
/// upward fling share one maximize path (slide-up + fade) — not a separate
/// inline zoom.
class ProcessImageViewer extends StatefulWidget {
  final Future<ProcessImageBytes?> Function() loader;
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

class _ProcessImageViewerState extends State<ProcessImageViewer> {
  late Future<ProcessImageBytes?> _future;
  final _transform = TransformationController();

  bool get _isIdentity {
    final scale = _transform.value.getMaxScaleOnAxis();
    return (scale - 1.0).abs() < 0.08;
  }

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
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
    _transform.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _future = widget.loader();
    });
  }

  /// Shared maximize path for tap and committed swipe-up fling.
  void _maximize(Widget imageChild) {
    if (!_isIdentity) return;
    HapticFeedback.lightImpact();
    _transform.value = Matrix4.identity();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (ctx, anim, sec) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          // Same “finish the up-swipe” feel: slide up + slight scale + fade.
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: _FullscreenProcessImage(image: imageChild),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() {
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
            if (widget.onFallbackSteps != null)
              TextButton(
                onPressed: widget.onFallbackSteps,
                child: const Text('返回步骤'),
              ),
            TextButton(onPressed: _retry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bg,
      child: FutureBuilder<ProcessImageBytes?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            // Assets resolve in a flash; keep spinner minimal.
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navy),
            );
          }
          final data = snap.data;
          if (data == null) {
            final url = widget.remoteUrl;
            if (url != null && url.isNotEmpty) {
              return _NetworkProcessImage(
                url: url,
                transform: _transform,
                onRetry: _retry,
                onFallbackSteps: widget.onFallbackSteps,
                onMaximize: _maximize,
              );
            }
            return _placeholder();
          }

          final Widget img;
          if (data.assetBytes != null) {
            img = Image.memory(
              Uint8List.fromList(data.assetBytes!),
              fit: BoxFit.contain,
              width: double.infinity,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('图片损坏'),
              ),
            );
          } else {
            img = Image.file(
              data.file!,
              fit: BoxFit.contain,
              width: double.infinity,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('图片损坏，请重试'),
              ),
            );
          }
          return _ZoomableImage(
            transform: _transform,
            onMaximize: () => _maximize(img),
            child: img,
          );
        },
      ),
    );
  }
}

class _NetworkProcessImage extends StatelessWidget {
  final String url;
  final TransformationController transform;
  final VoidCallback onRetry;
  final VoidCallback? onFallbackSteps;
  final void Function(Widget imageChild) onMaximize;

  const _NetworkProcessImage({
    required this.url,
    required this.transform,
    required this.onRetry,
    required this.onMaximize,
    this.onFallbackSteps,
  });

  @override
  Widget build(BuildContext context) {
    final net = Image.network(
      url,
      fit: BoxFit.contain,
      width: double.infinity,
      filterQuality: FilterQuality.high,
      headers: const {
        'User-Agent': 'HowToCook-mobile/0.6.8',
        'Accept': 'image/jpeg,image/*;q=0.8',
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navy),
        );
      },
      errorBuilder: (_, __, ___) => Center(
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
              TextButton(onPressed: onRetry, child: const Text('重试下载')),
            ],
          ),
        ),
      ),
    );
    return _ZoomableImage(
      transform: transform,
      onMaximize: () => onMaximize(net),
      child: net,
    );
  }
}

/// InteractiveViewer 上滑 browse + tap/fling → same maximize.
class _ZoomableImage extends StatefulWidget {
  final TransformationController transform;
  final Widget child;
  final VoidCallback onMaximize;

  const _ZoomableImage({
    required this.transform,
    required this.child,
    required this.onMaximize,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  Offset? _focalStart;
  DateTime? _downAt;

  bool _isIdentity(Matrix4 m) {
    final scale = m.getMaxScaleOnAxis();
    return (scale - 1.0).abs() < 0.08;
  }

  void _maybeMaximizeFromEnd(ScaleEndDetails details) {
    if (!_isIdentity(widget.transform.value)) return;
    final v = details.velocity.pixelsPerSecond;
    // Committed upward fling → maximize (same path as tap).
    if (v.dy < -900) {
      widget.onMaximize();
      return;
    }
    // Tap: short press, tiny travel, near-zero velocity.
    final start = _focalStart;
    final t0 = _downAt;
    if (start == null || t0 == null) return;
    final dt = DateTime.now().difference(t0);
    if (dt > const Duration(milliseconds: 450)) return;
    if (v.distance > 220) return;
    widget.onMaximize();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: widget.transform,
                minScale: 0.8,
                maxScale: 4,
                onInteractionStart: (details) {
                  if (details.pointerCount == 1) {
                    _focalStart = details.focalPoint;
                    _downAt = DateTime.now();
                  } else {
                    _focalStart = null;
                    _downAt = null;
                  }
                },
                onInteractionUpdate: (details) {
                  final start = _focalStart;
                  if (start == null) return;
                  // If finger moved like a pan, cancel tap.
                  if ((details.focalPoint - start).distance > 18) {
                    _focalStart = null;
                  }
                },
                onInteractionEnd: (details) {
                  _maybeMaximizeFromEnd(details);
                  _focalStart = null;
                  _downAt = null;
                },
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Center(child: widget.child),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '${ProcessImageService.attribution}\n上滑浏览 · 点按最大化 · 双指缩放',
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

class _FullscreenProcessImage extends StatefulWidget {
  final Widget image;
  const _FullscreenProcessImage({required this.image});

  @override
  State<_FullscreenProcessImage> createState() =>
      _FullscreenProcessImageState();
}

class _FullscreenProcessImageState extends State<_FullscreenProcessImage> {
  final _transform = TransformationController();

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
          InteractiveViewer(
            transformationController: _transform,
            minScale: 0.5,
            maxScale: 5,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              child: Center(child: widget.image),
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
              '双指缩放 · 点关闭',
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
