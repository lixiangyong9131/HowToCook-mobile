import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Zoomable full-process recipe card (9:16 AI infographic).
///
/// Restored from [eaa0006] InteractiveViewer pan/pinch (the working 上滑
/// browse-through-image behavior before tap-fullscreen was added in
/// 05242b9). Tap opens the same fullscreen maximize route as a committed
/// upward fling — not a separate inline zoom.
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

  /// Restored from eaa0006 — track scale so we only maximize at identity.
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

  /// Shared maximize path: tap and committed swipe-up fling both call this.
  void _maximize(Widget imageChild) {
    if (!_isIdentity) return;
    HapticFeedback.lightImpact();
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
              return _NetworkProcessImage(
                url: url,
                transform: _transform,
                onRetry: _retry,
                onFallbackSteps: widget.onFallbackSteps,
                onMaximize: _maximize,
              );
            }
            // Keep 「暂无图片」 placeholder from b2b6f70.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('暂无图片',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      ProcessImageService.attribution,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.onFallbackSteps != null)
                      TextButton(
                        onPressed: widget.onFallbackSteps,
                        child: const Text('返回步骤'),
                      ),
                    TextButton(
                      onPressed: _retry,
                      child: const Text('重试下载'),
                    ),
                  ],
                ),
              ),
            );
          }

          final img = Image.file(
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
        'User-Agent': 'HowToCook-mobile/0.6.6',
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
              TextButton(
                onPressed: onRetry,
                child: const Text('重试下载'),
              ),
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

/// eaa0006 InteractiveViewer core + non-interfering tap / upward-fling maximize.
///
/// Vertical *pan* stays on InteractiveViewer (restored 上滑浏览). We only
/// listen for a quick upward *fling* at identity scale via
/// [onInteractionEnd] velocity — not a competing Drag gesture that would
/// steal pans the way 05242b9+ did.
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
                behavior: HitTestBehavior.deferToChild,
                // Tap → same maximize as committed up-fling.
                onTap: () {
                  if (_isIdentity(transform.value)) onMaximize();
                },
                child: InteractiveViewer(
                  transformationController: transform,
                  minScale: 0.8,
                  maxScale: 4,
                  // eaa0006: pan + pinch fully enabled (上滑浏览).
                  onInteractionEnd: (details) {
                    if (!_isIdentity(transform.value)) return;
                    final v = details.velocity.pixelsPerSecond.dy;
                    // Strong upward fling at identity → same maximize as tap.
                    if (v < -900) onMaximize();
                  },
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
