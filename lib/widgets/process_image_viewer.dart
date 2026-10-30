import 'dart:io';

import 'package:flutter/material.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Zoomable full-process recipe card (9:16 AI infographic).
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
    // If parent swaps recipe/loader, reload.
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
            // Network fallback when disk cache miss / download failed.
            final url = widget.remoteUrl;
            if (url != null && url.isNotEmpty) {
              return _NetworkProcessImage(
                url: url,
                transform: _transform,
                onRetry: _retry,
                onFallbackSteps: widget.onFallbackSteps,
              );
            }
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

          return _ZoomableImage(
            transform: _transform,
            child: Image.file(
              file,
              fit: BoxFit.contain,
              width: double.infinity,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('图片损坏，请重试下载'),
              ),
            ),
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

  const _NetworkProcessImage({
    required this.url,
    required this.transform,
    required this.onRetry,
    this.onFallbackSteps,
  });

  @override
  Widget build(BuildContext context) {
    return _ZoomableImage(
      transform: transform,
      child: Image.network(
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
        errorBuilder: (_, __, ___) => Center(
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
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  final TransformationController transform;
  final Widget child;

  const _ZoomableImage({required this.transform, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: transform,
                minScale: 0.8,
                maxScale: 4,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Center(child: child),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '${ProcessImageService.attribution}\n双指缩放 · 拖动查看',
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
