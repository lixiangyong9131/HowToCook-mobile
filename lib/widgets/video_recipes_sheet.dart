import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/video_search_service.dart';
import '../theme/app_theme.dart';
import 'bili_video_player_dialog.dart';

Future<void> showVideoRecipesSheet(
  BuildContext context, {
  required String dishName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VideoRecipesSheet(dishName: dishName),
  );
}

enum _VideoTab { bili, douyin }

class VideoRecipesSheet extends StatefulWidget {
  final String dishName;
  const VideoRecipesSheet({super.key, required this.dishName});

  @override
  State<VideoRecipesSheet> createState() => _VideoRecipesSheetState();
}

class _VideoRecipesSheetState extends State<VideoRecipesSheet> {
  _VideoTab _tab = _VideoTab.bili;
  bool _loading = true;
  VideoSearchResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBili();
  }

  Future<void> _loadBili() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await VideoSearchService.search(widget.dishName);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接：$url')),
      );
    }
  }

  /// Prefer Douyin App deep link; fall back to https search.
  Future<void> _openDouyinSearch() async {
    HapticFeedback.selectionClick();
    final app = Uri.parse(DouyinSearch.appSearchUrl(widget.dishName));
    final web = Uri.parse(DouyinSearch.webSearchUrl(widget.dishName));
    try {
      final launched = await launchUrl(app, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {
      // App not installed / scheme blocked.
    }
    final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开抖音，请确认已安装抖音或可用浏览器')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.78;
    final biliSearchUrl = _result?.searchUrl ??
        VideoSearchService.searchUrlFor(widget.dishName);

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
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.dishName}的视频做法',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<_VideoTab>(
              segments: const [
                ButtonSegment(
                  value: _VideoTab.bili,
                  label: Text('哔哩哔哩'),
                  icon: Icon(Icons.play_circle_outline, size: 18),
                ),
                ButtonSegment(
                  value: _VideoTab.douyin,
                  label: Text('抖音'),
                  icon: Icon(Icons.music_note_outlined, size: 18),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                setState(() => _tab = s.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.coral.withValues(alpha: 0.15);
                  }
                  return AppTheme.cream;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.coral;
                  }
                  return AppTheme.muted;
                }),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _tab == _VideoTab.bili
                ? _biliBody(biliSearchUrl)
                : _douyinBody(),
          ),
        ],
      ),
    );
  }

  Widget _biliBody(String searchUrl) {
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
    if (_error != null) {
      return _Empty(
        message: '搜索失败',
        primaryLabel: '去 B 站搜索',
        onPrimary: () => _openUrl(searchUrl),
        onRetry: _loadBili,
      );
    }
    final list = _result?.results ?? const <BiliVideo>[];
    if (list.isEmpty) {
      return _Empty(
        message: '😔 没有找到相关视频',
        primaryLabel: '去 B 站搜索',
        onPrimary: () => _openUrl(searchUrl),
        onRetry: _loadBili,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Text(
                '共 ${list.length} 条 · 点按可应用内播放',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openUrl(searchUrl),
                child: const Text('在 B 站打开'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final v = list[i];
              return Material(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => showBiliVideoPlayer(context, video: v),
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
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppTheme.lilac,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.play_circle_outline),
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
          ),
        ),
      ],
    );
  }

  Widget _douyinBody() {
    final kw = DouyinSearch.keywordFor(widget.dishName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '抖音不提供稳定的第三方公开搜索列表接口，也无法合规内嵌播放器。'
              '本页会用官方搜索页 / App 深链打开「菜名的做法」，在抖音或浏览器里观看。',
              style: TextStyle(
                color: AppTheme.ink,
                height: 1.45,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '搜索词：$kw',
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _openDouyinSearch,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text(
              '打开抖音搜索',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _openUrl(DouyinSearch.webSearchUrl(widget.dishName)),
            icon: const Icon(Icons.public_rounded),
            label: const Text(
              '用浏览器打开抖音网页搜索',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          const Text(
            '提示：若已安装抖音，优先跳转 App；否则使用网页搜索。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onRetry;
  const _Empty({
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
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
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
              ),
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
