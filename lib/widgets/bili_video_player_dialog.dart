import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../services/video_search_service.dart';
import '../theme/app_theme.dart';

const _kMobileUa =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

/// In-app Bilibili player (official embed → m.bilibili fallback).
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
  /// 0 = official embed, 1 = m.bilibili
  int _mode = 0;

  String get _bvid => widget.video.bvid.trim();

  String get _embedUrl {
    final bvid = _bvid;
    if (bvid.isEmpty) return widget.video.watchUrl;
    return 'https://player.bilibili.com/player.html'
        '?bvid=$bvid&high_quality=1&danmaku=0&autoplay=1&muted=0&as_wide=1';
  }

  String get _mobileUrl {
    final bvid = _bvid;
    if (bvid.isNotEmpty) return 'https://m.bilibili.com/video/$bvid';
    return widget.video.watchUrl;
  }

  String get _playUrl => _mode == 0 ? _embedUrl : _mobileUrl;

  Uri get _headersUri => Uri.parse(_playUrl);

  Map<String, String> get _headers => {
        'User-Agent': _kMobileUa,
        'Referer': 'https://www.bilibili.com/',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      };

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
    _configureAndLoad();
  }

  WebViewController _buildController() {
    // iOS: empty mediaTypesRequiringUserAction + inline playback so autoplay works.
    if (!kIsWeb && Platform.isIOS) {
      final params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
      return WebViewController.fromPlatformCreationParams(params);
    }
    return WebViewController();
  }

  Future<void> _configureAndLoad() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(Colors.black);
    await _controller.setUserAgent(_kMobileUa);

    if (!kIsWeb && Platform.isAndroid) {
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setMediaPlaybackRequiresUserGesture(false);
        await platform.setMixedContentMode(MixedContentMode.alwaysAllow);
        AndroidWebViewController.enableDebugging(false);
      }
    }

    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _error = null;
            });
          }
        },
        onPageFinished: (_) async {
          if (!mounted) return;
          setState(() => _loading = false);
          // Autoplay nudge: muted play → click → delayed retries.
          await _nudgeAutoplay();
          Future<void>.delayed(const Duration(milliseconds: 450), _nudgeAutoplay);
          Future<void>.delayed(const Duration(milliseconds: 1200), _nudgeAutoplay);
          Future<void>.delayed(const Duration(milliseconds: 2200), _nudgeAutoplay);
          // Soften mobile chrome for m.bilibili mode.
          if (_mode == 1) {
            try {
              await _controller.runJavaScript('''
(function(){
  try {
    var s=document.createElement('style');
    s.innerHTML='.m-navbar,.nav-bar,.international-header,.v-navbar,.open-app-btn,.openapp,.app-guide,.bili-header{display:none!important;} body{padding-top:0!important;}';
    document.documentElement.appendChild(s);
  } catch(e) {}
})();
''');
            } catch (_) {}
          }
        },
        onWebResourceError: (err) {
          // Ignore subframe / CDN noise — only fail on main frame.
          if (err.isForMainFrame != true) return;
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = err.description.isNotEmpty
                ? err.description
                : '播放页加载失败';
          });
        },
        onHttpError: (err) {
          final code = err.response?.statusCode;
          if (code == null || code < 400) return;
          // Only treat document-level failures as fatal.
          final uri = err.response?.uri;
          if (uri != null &&
              !uri.host.contains('bilibili.com') &&
              !uri.host.contains('bilivideo')) {
            return;
          }
          if (!mounted) return;
          // Soft: keep webview; show banner only for heavy failures.
          if (code >= 500 || code == 404) {
            setState(() {
              _loading = false;
              _error = 'HTTP $code';
            });
          }
        },
        onNavigationRequest: (req) {
          final url = req.url;
          if (url.startsWith('http://') || url.startsWith('https://')) {
            // Block junk app-download interstitial hosts lightly by allowing navigate.
            return NavigationDecision.navigate;
          }
          // Block bilibili:// and intent:// deep links out of the WebView.
          return NavigationDecision.prevent;
        },
      ),
    );

    await _loadCurrent();
  }


  Future<void> _nudgeAutoplay() async {
    if (!mounted) return;
    try {
      await _controller.runJavaScript("""
(function(){
  try {
    var v=document.querySelector('video');
    if(v){
      v.muted=true;
      v.playsInline=true;
      v.setAttribute('playsinline','');
      v.setAttribute('webkit-playsinline','');
      var p=v.play();
      if(p&&p.catch) p.catch(function(){});
      setTimeout(function(){ try{ v.muted=false; }catch(e){} }, 800);
    }
    var sels=['.bpx-player-ctrl-play','.player-mobile-btn-start',
      '.bilibili-player-video-btn-start','.play-btn',
      'button[aria-label*="播放"]','.bmpui-btn-play'];
    for (var j=0;j<sels.length;j++){
      var b=document.querySelector(sels[j]);
      if(b){ b.click(); break; }
    }
  } catch(e) {}
})();
""");
    } catch (_) {}
  }

  Future<void> _loadCurrent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _controller.loadRequest(_headersUri, headers: _headers);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _retry() async {
    // Prefer embed first; if already embed and failed, flip to mobile.
    if (_mode == 0 && _error != null) {
      setState(() => _mode = 1);
    }
    await _loadCurrent();
  }

  Future<void> _tryEmbedThenMobile() async {
    setState(() => _mode = 0);
    await _loadCurrent();
  }

  @override
  void dispose() {
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
                            const Icon(Icons.videocam_off_outlined,
                                size: 40, color: AppTheme.muted),
                            const SizedBox(height: 12),
                            const Text(
                              '播放页加载失败',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.navy,
                                foregroundColor: AppTheme.neon,
                              ),
                              onPressed: _retry,
                              child: Text(
                                _mode == 0 ? '重试 / 切换移动页' : '重试',
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_mode == 1)
                              TextButton(
                                onPressed: _tryEmbedThenMobile,
                                child: const Text('改用官方嵌入播放器'),
                              ),
                            TextButton(
                              onPressed: _openExternal,
                              child: const Text('在 B 站打开（备用）'),
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
