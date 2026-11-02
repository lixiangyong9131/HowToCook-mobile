import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/video_search_service.dart';
import '../theme/app_theme.dart';
import 'bili_tv_icon.dart';
import 'bili_video_player_dialog.dart';

Future<void> showVideoRecipesSheet(
  BuildContext context, {
  required String dishName,
}) async {
  final name = dishName.trim();
  if (name.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('暂无菜名，无法搜索视频')),
    );
    return;
  }
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VideoRecipesSheet(dishName: name),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('暂时无法打开视频列表，请稍后重试')),
    );
  }
}

class VideoRecipesSheet extends StatefulWidget {
  final String dishName;

  /// Override for tests. Production uses [VideoSearchService.search].
  final Future<VideoSearchResult> Function(String dishName)? search;

  const VideoRecipesSheet({super.key, required this.dishName, this.search});

  @override
  State<VideoRecipesSheet> createState() => _VideoRecipesSheetState();
}

class _VideoRecipesSheetState extends State<VideoRecipesSheet> {
  bool _loading = true;
  VideoSearchResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final search = widget.search ?? VideoSearchService.search;
      final r = await search(widget.dishName);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
        // Never surface raw exceptions — failed status uses soft copy.
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      // Soft failure flag only; UI shows [_failMessage], not the exception.
      setState(() {
        _error = 'failed';
        _result = VideoSearchResult(
          results: const [],
          keyword: widget.dishName,
          source: 'fallback',
          searchUrl: VideoSearchService.searchUrlFor(widget.dishName),
          status: VideoSearchStatus.failed,
        );
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    HapticFeedback.selectionClick();
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开 B 站链接，请稍后重试')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开 B 站链接，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.78;
    final searchUrl =
        _result?.searchUrl ?? VideoSearchService.searchUrlFor(widget.dishName);

    return Container(
      height: h,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow(opacity: 0.22),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                const BiliTvIcon(size: 26, color: AppTheme.coral),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.dishName} · B 站做法',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Material(
                  color: AppTheme.coral,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openUrl(searchUrl),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        '在 B 站打开',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(searchUrl)),
        ],
      ),
    );
  }

  Widget _body(String searchUrl) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.navy),
            SizedBox(height: 12),
            Text('正在搜索 B 站视频…', style: TextStyle(color: AppTheme.muted)),
          ],
        ),
      );
    }
    if (_error != null || _result?.status == VideoSearchStatus.failed) {
      return _Empty(
        message: _failMessage,
        detail: _failDetail,
        onOpen: () => _openUrl(searchUrl),
        onRetry: _load,
      );
    }
    final list = _result?.results ?? const <BiliVideo>[];
    if (list.isEmpty) {
      return _Empty(
        message: _emptyMessage,
        onOpen: () => _openUrl(searchUrl),
        onRetry: _load,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final v = list[i];
        return Material(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              try {
                await showBiliVideoPlayer(context, video: v);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('暂时无法播放，请稍后重试')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 120,
                      height: 76,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            v.coverHttps,
                            fit: BoxFit.cover,
                            headers: const {
                              'User-Agent':
                                  'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36',
                              'Referer': 'https://www.bilibili.com/',
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.lilac,
                              alignment: Alignment.center,
                              child: const BiliTvIcon(
                                size: 28,
                                color: AppTheme.navy,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v.duration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.3,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${v.author} · ${v.duration} · ${v.playLabel} 播放',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

const _failMessage = '搜索暂时失败';
const _failDetail = '网络不稳定或被 B 站拦截，并不是这道菜没有视频';
const _emptyMessage = '😔 没有找到相关视频';

class _Empty extends StatelessWidget {
  final String message;
  final String? detail;
  final VoidCallback onOpen;
  final VoidCallback onRetry;
  const _Empty({
    required this.message,
    this.detail,
    required this.onOpen,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.muted,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
              ),
              onPressed: onOpen,
              child: const Text('去 B 站搜索'),
            ),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
