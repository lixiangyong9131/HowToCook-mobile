import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Zoomable full-process recipe card (9:16 AI infographic).
///
/// Tap immediately maximizes; committed 上滑 shares the same route.
/// Fullscreen: tap anywhere (near identity) dismisses / restores.
class ProcessImageViewer extends StatefulWidget {
  final Future<ProcessImageBytes?> Function() loader;
  final String? remoteUrl;
  final VoidCallback? onFallbackSteps;
  /// Full-bleed detail mode: black canvas, no footer chrome.
  final bool immersive;

  const ProcessImageViewer({
    super.key,
    required this.loader,
    this.remoteUrl,
    this.onFallbackSteps,
    this.immersive = false,
  });

  @override
  State<ProcessImageViewer> createState() => _ProcessImageViewerState();
}

class _ProcessImageViewerState extends State<ProcessImageViewer> {
  late Future<ProcessImageBytes?> _future;
  final _transform = TransformationController();
  bool _routeOpen = false;
  DateTime? _ignoreUntil;

  bool get _isNearIdentity {
    final scale = _transform.value.getMaxScaleOnAxis();
    return scale < 1.25;
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
    setState(() => _future = widget.loader());
  }

  /// Single maximize path for tap and swipe-up fling.
  Future<void> _maximize(Widget imageChild) async {
    if (!mounted) return;
    if (_routeOpen) return;
    final until = _ignoreUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    if (!_isNearIdentity) return;

    _routeOpen = true;
    HapticFeedback.lightImpact();
    _transform.value = Matrix4.identity();
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          barrierDismissible: true,
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (ctx, anim, sec) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
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
    } finally {
      _routeOpen = false;
      // Absorb the closing tap / residual fling so we don't immediately reopen.
      _ignoreUntil = DateTime.now().add(const Duration(milliseconds: 320));
      if (mounted) {
        _transform.value = Matrix4.identity();
      }
    }
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
                immersive: widget.immersive,
              );
            }
            return _placeholder();
          }

          // Immersive: fitWidth keeps full horizontal content (less side crop);
          // vertical letterbox OK. Non-immersive stays contain.
          final fit =
              widget.immersive ? BoxFit.fitWidth : BoxFit.contain;
          final Widget img;
          if (data.assetBytes != null) {
            img = Image.memory(
              Uint8List.fromList(data.assetBytes!),
              fit: fit,
              width: double.infinity,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('图片损坏')),
            );
          } else {
            img = Image.file(
              data.file!,
              fit: fit,
              width: double.infinity,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('图片损坏，请重试')),
            );
          }
          return _ZoomableImage(
            transform: _transform,
            onMaximize: () => _maximize(img),
            immersive: widget.immersive,
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
  final Future<void> Function(Widget imageChild) onMaximize;
  final bool immersive;

  const _NetworkProcessImage({
    required this.url,
    required this.transform,
    required this.onRetry,
    required this.onMaximize,
    this.onFallbackSteps,
    this.immersive = false,
  });

  @override
  Widget build(BuildContext context) {
    final net = Image.network(
      url,
      fit: immersive ? BoxFit.fitWidth : BoxFit.contain,
      width: double.infinity,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      headers: const {
        'User-Agent': 'HowToCook-mobile/0.6.17',
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
      immersive: immersive,
      child: net,
    );
  }
}

/// InteractiveViewer browse; tap / upward fling → same [onMaximize].
class _ZoomableImage extends StatefulWidget {
  final TransformationController transform;
  final Widget child;
  final VoidCallback onMaximize;
  final bool immersive;

  const _ZoomableImage({
    required this.transform,
    required this.child,
    required this.onMaximize,
    this.immersive = false,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  Offset? _downPos;
  int? _downPointer;
  DateTime? _downAt;
  double _maxMove = 0;
  int _activePointers = 0;

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
              // Listener always observes pointers (arena-independent) so tap
              // hits the same _fireMaximize as upward fling.
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (e.kind != ui.PointerDeviceKind.touch &&
                      e.kind != ui.PointerDeviceKind.mouse) {
                    return;
                  }
                  _activePointers++;
                  if (_activePointers > 1) {
                    _downPos = null;
                    _maxMove = 999;
                    return;
                  }
                  _downPointer = e.pointer;
                  _downPos = e.position;
                  _downAt = DateTime.now();
                  _maxMove = 0;
                },
                onPointerMove: (e) {
                  if (e.pointer != _downPointer || _downPos == null) return;
                  final d = (e.position - _downPos!).distance;
                  if (d > _maxMove) _maxMove = d;
                },
                onPointerUp: (e) {
                  if (e.pointer == _downPointer) {
                    final start = _downPos;
                    final t0 = _downAt;
                    final move = _maxMove;
                    final wasTap = start != null &&
                        t0 != null &&
                        _activePointers <= 1 &&
                        move <= 36 &&
                        DateTime.now().difference(t0) <
                            const Duration(milliseconds: 500);
                    _downPointer = null;
                    _downPos = null;
                    _downAt = null;
                    if (wasTap) {
                      // Immediate maximize — no post-frame delay.
                      _fireMaximize();
                    }
                  }
                  _activePointers = (_activePointers - 1).clamp(0, 10);
                },
                onPointerCancel: (e) {
                  if (e.pointer == _downPointer) {
                    _downPointer = null;
                    _downPos = null;
                    _downAt = null;
                    _maxMove = 999;
                  }
                  _activePointers = (_activePointers - 1).clamp(0, 10);
                },
                child: widget.immersive
                    // Fixed frame: no pan / scale — swipe must not move the image.
                    ? SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(child: widget.child),
                      )
                    : InteractiveViewer(
                        transformationController: widget.transform,
                        minScale: 0.8,
                        maxScale: 4,
                        panEnabled: true,
                        scaleEnabled: true,
                        boundaryMargin:
                            const EdgeInsets.fromLTRB(0, 24, 0, 48),
                        onInteractionEnd: (details) {
                          if (!_isNearIdentity(widget.transform.value)) {
                            return;
                          }
                          final v = details.velocity.pixelsPerSecond;
                          if (v.dy < -650) {
                            _fireMaximize();
                          }
                        },
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                            child: Center(child: widget.child),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
        if (!widget.immersive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              '${ProcessImageService.attribution}\n点按立即全屏 · 上滑同效 · 双指缩放',
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
  bool _closing = false;
  Offset? _downPos;
  int? _downPointer;
  DateTime? _downAt;
  double _maxMove = 0;
  int _activePointers = 0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  bool get _isNearIdentity =>
      _transform.value.getMaxScaleOnAxis() < 1.25;

  void _close() {
    if (_closing) return;
    _closing = true;
    HapticFeedback.selectionClick();
    Navigator.of(context).maybePop();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.kind != ui.PointerDeviceKind.touch &&
        e.kind != ui.PointerDeviceKind.mouse) {
      return;
    }
    _activePointers++;
    if (_activePointers > 1) {
      _downPos = null;
      _maxMove = 999;
      return;
    }
    _downPointer = e.pointer;
    _downPos = e.position;
    _downAt = DateTime.now();
    _maxMove = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _downPointer || _downPos == null) return;
    final d = (e.position - _downPos!).distance;
    if (d > _maxMove) _maxMove = d;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer == _downPointer) {
      final start = _downPos;
      final t0 = _downAt;
      final move = _maxMove;
      final wasTap = start != null &&
          t0 != null &&
          _activePointers <= 1 &&
          move <= 36 &&
          DateTime.now().difference(t0) < const Duration(milliseconds: 500);
      _downPointer = null;
      _downPos = null;
      _downAt = null;
      // Tap anywhere (when not zoomed) restores / dismisses fullscreen.
      if (wasTap && _isNearIdentity) {
        _close();
      }
    }
    _activePointers = (_activePointers - 1).clamp(0, 10);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer == _downPointer) {
      _downPointer = null;
      _downPos = null;
      _downAt = null;
      _maxMove = 999;
    }
    _activePointers = (_activePointers - 1).clamp(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: true,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 0.5,
                maxScale: 5,
                onInteractionEnd: (details) {
                  if (!_isNearIdentity) return;
                  if (details.velocity.pixelsPerSecond.dy > 900) {
                    _close();
                  }
                },
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
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: math.max(pad.bottom, 12) + 8,
              child: IgnorePointer(
                child: Text(
                  '点按任意处关闭 · 双指缩放 · 下滑关闭',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
