import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/video_search_service.dart';
import '../theme/app_theme.dart';

/// In-app Bilibili player dialog (mobile page in WebView).
Future<void> showBiliVideoPlayer(
  BuildContext context, {
  required BiliVideo video,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => BiliVideoPlayerDialog(video: video),
  );
}

class BiliVideoPlayerDialog extends StatefulWidget {
  final BiliVideo video;
  const BiliVideoPlayerDialog({super.key, required this.video});

  @override
  State<BiliVideoPlayerDialog> createState() => _BiliVideoPlayerDialogState();
}

class _BiliVideoPlayerDialogState extends State<BiliVideoPlayerDialog> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  String get _mobileUrl {
    final bvid = widget.video.bvid.trim();
    if (bvid.isNotEmpty) {
      return 'https://m.bilibili.com/video/$bvid';
    }
    return widget.video.watchUrl;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = err.description.isNotEmpty
                    ? err.description
                    : '页面加载失败';
              });
            }
          },
          onNavigationRequest: (req) {
            final url = req.url;
            // Keep playback in-app; allow bilibili / bilivideo CDNs.
            if (url.startsWith('http://') || url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }
            // Block bilibili:// deep links that jump to the app.
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(_mobileUrl),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      );
  }

  @override
  void dispose() {
    // Stop media when dialog closes.
    try {
      _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    super.dispose();
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.video.watchUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接：${widget.video.watchUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: size.width,
        height: size.height * 0.78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppTheme.softShadow(opacity: 0.25),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.video.title.isEmpty ? '视频播放' : widget.video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  Material(
                    color: const Color(0xFFFF5A8A),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _openExternal,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          '在 B 站打开',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
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
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_error == null)
                    WebViewWidget(controller: _controller)
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('😔 播放页加载失败',
                                style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A8A),
                              ),
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                  _loading = true;
                                });
                                _controller.loadRequest(Uri.parse(_mobileUrl));
                              },
                              child: const Text('重试'),
                            ),
                            TextButton(
                              onPressed: _openExternal,
                              child: const Text('在 B 站打开'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_loading && _error == null)
                    const ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              '正在加载视频…',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
