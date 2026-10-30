import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Zoomable full-process recipe card (9:16 AI infographic).
///
/// When not zoomed, **tap** or **swipe up** opens the same InteractiveViewer
/// in a fullscreen maximize route (pinch/drag there; close to return).
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

class _ProcessImageViewerState extends State<ProcessImageViewer> {
  late Future<File?> _future;
  final _transform = TransformationController();

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

  bool get _isIdentityZoom {
    final m = _transform.value;
    final scale = m.getMaxScaleOnAxis();
    return (scale - 1.0).abs() < 0.08;
  }

  void _openFullscreen(Widget imageChild) {
    if (!_isIdentityZoom) return;
    HapticFeedback.lightImpact();
    // Reset any tiny pan before leaving.
    _transform.value = Matrix4.identity();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, anim, _) {
          return FadeTransition(
            opacity: anim,
            child: _FullscreenProcessImage(image: imageChild),
          );
        },
      ),
    );
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
                  'User-Agent': 'HowToCook-mobile/0.6.3',
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
              return _ZoomableImage(
                transform: _transform,
                onMaximize: () => _openFullscreen(net),
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
          return _ZoomableImage(
            transform: _transform,
            onMaximize: () => _openFullscreen(fileImg),
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
            const Text('整图暂不可用', style: TextStyle(fontSize: 16)),
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

class _ZoomableImage extends StatelessWidget {
  final TransformationController transform;
  final Widget child;
  final VoidCallback onMaximize;

  const _ZoomableImage({
    required this.transform,
    required this.child,
    required this.onMaximize,
  });

  bool _isIdentity(Matrix4 m) {
    final scale = m.getMaxScaleOnAxis();
    return (scale - 1.0).abs() < 0.08;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_isIdentity(transform.value)) onMaximize();
                },
                onVerticalDragEnd: (d) {
                  if (!_isIdentity(transform.value)) return;
                  final v = d.primaryVelocity ?? 0;
                  // Swipe up → maximize (same as tap).
                  if (v < -420) onMaximize();
                },
                child: InteractiveViewer(
                  transformationController: transform,
                  minScale: 0.8,
                  maxScale: 4,
                  // Double-tap style expand handled via tap when identity.
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Center(child: child),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '${ProcessImageService.attribution}\n点按或上滑放大 · 双指缩放 · 拖动查看',
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

/// Fullscreen InteractiveViewer for 做法大图 (tap / swipe-up from inline).
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
          GestureDetector(
            onVerticalDragEnd: (d) {
              final scale = _transform.value.getMaxScaleOnAxis();
              if ((scale - 1.0).abs() > 0.08) return;
              final v = d.primaryVelocity ?? 0;
              // Swipe down to dismiss when not zoomed.
              if (v > 500) _close();
            },
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.5,
              maxScale: 5,
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
