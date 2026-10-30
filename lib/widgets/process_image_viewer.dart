import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Zoomable full-process recipe card (9:16 AI infographic).
///
/// Top dish-photo band → sticky 「菜品 logo」 strip (cover + top align).
/// Tap and committed 上滑 share one maximize route (slide-up morph).
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

  /// Measured top-band fraction of source (hero photo). Fallback 0.18.
  double _logoFrac = 0.18;
  bool _probedLogo = false;

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
      _logoFrac = 0.18;
      _probedLogo = false;
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
      _logoFrac = 0.18;
      _probedLogo = false;
    });
  }

  /// Probe image bytes for a reasonable hero/logo band height.
  /// Across the bundled set, top regions are *similar but not identical*
  /// (~14–24%); clamp to that range and prefer a soft edge into the beige canvas.
  Future<void> _probeLogoFrac(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 180);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final w = img.width;
      final h = img.height;
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (bd == null || h < 20) return;
      final pixels = bd.buffer.asUint8List();
      // Row std-dev of luminance; canvas rows are bright + flat.
      final rowStd = List<double>.filled(h, 0);
      final rowMean = List<double>.filled(h, 0);
      for (var y = 0; y < h; y++) {
        var sum = 0.0;
        var sum2 = 0.0;
        final stride = w * 4;
        final base = y * stride;
        for (var x = 0; x < w; x++) {
          final i = base + x * 4;
          final lum = 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
          sum += lum;
          sum2 += lum * lum;
        }
        final m = sum / w;
        rowMean[y] = m;
        rowStd[y] = math.sqrt(math.max(0, sum2 / w - m * m));
      }
      // Find first sustained flat bright run after some photo content.
      var run = 0;
      var found = (h * 0.18).round();
      final start = (h * 0.08).round();
      final end = (h * 0.40).round();
      for (var y = start; y < end; y++) {
        final canvasLike = rowStd[y] < 22 && rowMean[y] > 195;
        if (canvasLike) {
          run++;
          if (run >= 6) {
            found = y - 5;
            break;
          }
        } else {
          run = 0;
        }
      }
      final frac = (found / h).clamp(0.14, 0.24);
      if (mounted) setState(() => _logoFrac = frac);
    } catch (_) {
      // Keep default.
    }
  }

  /// Shared maximize path for tap and committed swipe-up fling.
  void _maximize(Widget imageChild) {
    if (!_isIdentity) {
      // Still allow maximize if barely off identity (tap jitter).
      final scale = _transform.value.getMaxScaleOnAxis();
      if (scale > 1.25) return;
    }
    HapticFeedback.lightImpact();
    _transform.value = Matrix4.identity();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (ctx, anim, sec) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          // Same “finish the up-swipe” morph for tap and fling.
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.22),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
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

  Widget _buildWithImage(Widget img, {Uint8List? probeBytes}) {
    if (probeBytes != null && !_probedLogo) {
      _probedLogo = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _probeLogoFrac(probeBytes);
      });
    }
    return Column(
      children: [
        _DishLogoHeader(image: img, fraction: _logoFrac),
        Expanded(
          child: _ZoomableImage(
            transform: _transform,
            onMaximize: () => _maximize(img),
            child: img,
          ),
        ),
      ],
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
                logoFrac: _logoFrac,
                onLogoFrac: (f) {
                  if (mounted) setState(() => _logoFrac = f);
                },
              );
            }
            return _placeholder();
          }

          final Uint8List? bytes = data.assetBytes != null
              ? Uint8List.fromList(data.assetBytes!)
              : null;
          final Widget img;
          if (bytes != null) {
            img = Image.memory(
              bytes,
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
          return _buildWithImage(img, probeBytes: bytes);
        },
      ),
    );
  }
}

/// Top dish-photo strip used as a 「菜品 logo」.
///
/// Source top bands are similar (~14–24%) but not identical — we cover-fit a
/// fixed logical height from [fraction] of the source, top-aligned.
class _DishLogoHeader extends StatelessWidget {
  final Widget image;
  final double fraction;

  const _DishLogoHeader({required this.image, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final frac = fraction.clamp(0.14, 0.24);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 104,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppTheme.navy.withValues(alpha: 0.06)),
                  FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      // Virtual canvas: width 1000, height = full card so
                      // heightFactor clips to the logo band.
                      width: 1000,
                      height: 1000 / 0.56, // ~9:16-ish
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: frac,
                          child: image,
                        ),
                      ),
                    ),
                  ),
                  // Soft bottom fade so it reads as a logo plate.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '菜品封面',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
        ],
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
  final double logoFrac;
  final ValueChanged<double>? onLogoFrac;

  const _NetworkProcessImage({
    required this.url,
    required this.transform,
    required this.onRetry,
    required this.onMaximize,
    required this.logoFrac,
    this.onFallbackSteps,
    this.onLogoFrac,
  });

  @override
  Widget build(BuildContext context) {
    final net = Image.network(
      url,
      fit: BoxFit.contain,
      width: double.infinity,
      filterQuality: FilterQuality.high,
      headers: const {
        'User-Agent': 'HowToCook-mobile/0.6.11',
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
    return Column(
      children: [
        _DishLogoHeader(image: net, fraction: logoFrac),
        Expanded(
          child: _ZoomableImage(
            transform: transform,
            onMaximize: () => onMaximize(net),
            child: net,
          ),
        ),
      ],
    );
  }
}

/// InteractiveViewer 上滑 browse; tap / upward fling → same maximize.
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
  Offset? _pointerDown;
  int? _pointerId;
  DateTime? _downAt;
  bool _moved = false;

  bool _isNearIdentity(Matrix4 m) {
    final scale = m.getMaxScaleOnAxis();
    return scale < 1.25;
  }

  void _fireMaximize() {
    if (!_isNearIdentity(widget.transform.value)) return;
    widget.onMaximize();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Listener sits above InteractiveViewer in hit-test order? No —
              // Listener as parent still receives pointers. Use it for tap
              // detection without winning the gesture arena (unlike GestureDetector).
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (e.kind != ui.PointerDeviceKind.touch &&
                      e.kind != ui.PointerDeviceKind.mouse) {
                    return;
                  }
                  if (_pointerId != null) {
                    // Multi-touch → not a tap.
                    _pointerDown = null;
                    _moved = true;
                    return;
                  }
                  _pointerId = e.pointer;
                  _pointerDown = e.position;
                  _downAt = DateTime.now();
                  _moved = false;
                },
                onPointerMove: (e) {
                  if (e.pointer != _pointerId) return;
                  final start = _pointerDown;
                  if (start == null) return;
                  if ((e.position - start).distance > 14) {
                    _moved = true;
                  }
                },
                onPointerUp: (e) {
                  if (e.pointer != _pointerId) return;
                  final start = _pointerDown;
                  final t0 = _downAt;
                  final wasTap = !_moved &&
                      start != null &&
                      t0 != null &&
                      DateTime.now().difference(t0) <
                          const Duration(milliseconds: 400) &&
                      (e.position - start).distance <= 14;
                  _pointerId = null;
                  _pointerDown = null;
                  _downAt = null;
                  if (wasTap) {
                    // Defer so InteractiveViewer settles first.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _fireMaximize();
                    });
                  }
                },
                onPointerCancel: (e) {
                  if (e.pointer == _pointerId) {
                    _pointerId = null;
                    _pointerDown = null;
                    _downAt = null;
                    _moved = true;
                  }
                },
                child: InteractiveViewer(
                  transformationController: widget.transform,
                  minScale: 0.8,
                  maxScale: 4,
                  onInteractionEnd: (details) {
                    if (!_isNearIdentity(widget.transform.value)) return;
                    final v = details.velocity.pixelsPerSecond;
                    // Committed upward fling → same maximize as tap.
                    if (v.dy < -700) {
                      _fireMaximize();
                    }
                  },
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Center(child: widget.child),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '${ProcessImageService.attribution}\n上滑浏览 · 点按与上滑同效最大化 · 双指缩放',
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
