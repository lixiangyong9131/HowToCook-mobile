import 'dart:io';

import 'package:flutter/material.dart';

import '../services/process_image_service.dart';
import '../theme/app_theme.dart';

/// Zoomable full-process recipe card (9:16 AI infographic).
class ProcessImageViewer extends StatefulWidget {
  final Future<File?> Function() loader;
  final VoidCallback? onFallbackSteps;

  const ProcessImageViewer({
    super.key,
    required this.loader,
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
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.navy),
                SizedBox(height: 12),
                Text('正在加载整图做法…',
                    style: TextStyle(color: AppTheme.muted)),
              ],
            ),
          );
        }
        final file = snap.data;
        if (file == null) {
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
                  if (widget.onFallbackSteps != null)
                    TextButton(
                      onPressed: widget.onFallbackSteps,
                      child: const Text('返回步骤'),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      _future = widget.loader();
                    }),
                    child: const Text('重试下载'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
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
      },
    );
  }
}
