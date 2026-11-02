import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show Factory, kIsWeb;
import 'package:flutter/gestures.dart';
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
}) async {
  if (video.bvid.trim().isEmpty && video.watchUrl.trim().isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('这个视频链接不可用'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => BiliVideoPlayerDialog(video: video),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('网络不稳定，暂时无法播放'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
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
  /// Soft in-dialog tip only — never a flashing red framework toast.
  String? _softTip;
  /// 0 = official embed, 1 = m.bilibili
  int _mode = 0;
  bool _alive = true;
  Timer? _errorDebounce;
  bool _triedMobileFallback = false;

  /// WebView owns all gestures — avoids nested-gesture deadlock with dialog
  /// when tapping danmaku / fullscreen controls inside the player.
  static final Set<Factory<OneSequenceGestureRecognizer>> _webGestures =
      <Factory<OneSequenceGestureRecognizer>>{};

  String get _bvid => widget.video.bvid.trim();

  String get _embedUrl {
    final bvid = _bvid;
    if (bvid.isEmpty) return widget.video.watchUrl;
    return 'https://player.bilibili.com/player.html'
        '?bvid=$bvid&high_quality=1&danmaku=0&autoplay=0&muted=0&as_wide=1';
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
    // iOS: inline OK; require tap before media (no autoplay).
    if (!kIsWeb && Platform.isIOS) {
      final params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {
          PlaybackMediaTypes.audio,
          PlaybackMediaTypes.video,
        },
      );
      return WebViewController.fromPlatformCreationParams(params);
    }
    return WebViewController();
  }

  Future<void> _configureAndLoad() async {
    if (!_alive) return;
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setUserAgent(_kMobileUa);

      if (!kIsWeb && Platform.isAndroid) {
        final platform = _controller.platform;
        if (platform is AndroidWebViewController) {
          await platform.setMediaPlaybackRequiresUserGesture(true);
          await platform.setMixedContentMode(MixedContentMode.alwaysAllow);
          AndroidWebViewController.enableDebugging(false);
        }
      }

      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!_alive || !mounted) return;
            _cancelErrorDebounce();
            setState(() {
              _loading = true;
              _error = null;
              _softTip = null;
            });
          },
          onPageFinished: (_) async {
            if (!_alive || !mounted) return;
            _cancelErrorDebounce();
            setState(() {
              _loading = false;
              _error = null;
            });
            // No autoplay — pause if the page tries to start; user taps to play.
            if (_mode == 1) {
              await _runJsSafe(r'''(function(){
  try {
    var s=document.createElement('style');
    s.innerHTML='.m-navbar,.nav-bar,.international-header,.v-navbar,.open-app-btn,.openapp,.app-guide,.bili-header{display:none!important;} body{padding-top:0!important;}';
    document.documentElement.appendChild(s);
    var v=document.querySelector('video');
    if(v){ try{ v.pause(); }catch(e){} }
  } catch(e) {}
})();''');
            } else {
              await _runJsSafe(r'''(function(){
  try {
    var v=document.querySelector('video');
    if(v){ try{ v.pause(); v.autoplay=false; }catch(e){} }
  } catch(e) {}
})();''');
            }
          },
          onWebResourceError: (err) {
            // Subframe noise and cancelled redirects must never flash UI.
            if (err.isForMainFrame != true) return;
            if (!_alive || !mounted) return;
            final desc = err.description.toLowerCase();
            final code = err.errorCode;
            // Aborts/cancels during embed redirects are normal — ignore hard.
            if (code == -3 /* ERR_ABORTED */ ||
                code == -999 /* NSURLErrorCancelled */ ||
                desc.contains('abort') ||
                desc.contains('cancel') ||
                desc.contains('interrupt') ||
                desc.contains('replaced')) {
              return;
            }
            // Real network failures: debounce, then silent mobile fallback.
            _scheduleSoftFailure(networkish: true);
          },
          onHttpError: (err) {
            final code = err.response?.statusCode;
            if (code == null || code < 400) return;
            final uri = err.response?.uri;
            if (uri != null &&
                !uri.host.contains('bilibili.com') &&
                !uri.host.contains('bilivideo')) {
              return;
            }
            if (!_alive || !mounted) return;
            // Risk-control / redirects: ignore completely (no flash).
            if (code == 412 || code == 403 || code == 429 || code == 302) {
              return;
            }
            if (code >= 500 || code == 404) {
              _scheduleSoftFailure(networkish: true);
            }
          },
          onNavigationRequest: (req) {
            final url = req.url;
            if (url.startsWith('http://') || url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }
            // Block bilibili:// and intent:// deep links out of the WebView.
            return NavigationDecision.prevent;
          },
        ),
      );

      await _loadCurrent();
    } catch (_) {
      if (!_alive || !mounted) return;
      _showSoftFailure(message: '播放器暂时不可用，请重试或到 B 站打开');
    }
  }

  void _cancelErrorDebounce() {
    _errorDebounce?.cancel();
    _errorDebounce = null;
  }

  /// Debounced soft failure: prefer silent embed→mobile fallback; never flash
  /// raw WebView descriptions or framework red errors.
  void _scheduleSoftFailure({required bool networkish}) {
    _cancelErrorDebounce();
    _errorDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!_alive || !mounted) return;
      // Still loading a subsequent navigation — keep waiting quietly.
      if (_loading && _error == null) {
        // Give the page one more beat; if still stuck, soft-fail below.
      }
      if (_mode == 0 && !_triedMobileFallback) {
        _triedMobileFallback = true;
        setState(() {
          _mode = 1;
          _error = null;
          _softTip = null;
          _loading = true;
        });
        unawaited(_loadCurrent());
        return;
      }
      _showSoftFailure(
        message: networkish
            ? '网络不稳定，暂时无法播放'
            : '暂时无法播放，请稍后重试',
      );
    });
  }

  void _showSoftFailure({required String message}) {
    if (!_alive || !mounted) return;
    setState(() {
      _loading = false;
      _error = message;
      _softTip = message;
    });
  }

  Future<void> _runJsSafe(String js) async {
    if (!_alive) return;
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _loadCurrent() async {
    if (!_alive || !mounted) return;
    _cancelErrorDebounce();
    setState(() {
      _loading = true;
      _error = null;
      _softTip = null;
    });
    try {
      await _controller.loadRequest(_headersUri, headers: _headers);
    } catch (_) {
      if (!_alive || !mounted) return;
      _scheduleSoftFailure(networkish: true);
    }
  }

  Future<void> _retry() async {
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
    _alive = false;
    _cancelErrorDebounce();
    // Tear down safely: stop media via JS, clear delegate, blank page.
    // Do not await — dispose must be sync; fire-and-forget with guards.
    unawaited(() async {
      try {
        await _controller.runJavaScript(
          "try{var v=document.querySelector('video');if(v){v.pause();v.src='';v.load();}}catch(e){}",
        );
      } catch (_) {}
      try {
        await _controller.setNavigationDelegate(NavigationDelegate());
      } catch (_) {}
      try {
        await _controller.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
    }());
    super.dispose();
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.video.watchUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时打不开 B 站链接'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
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
                  // Keep WebView mounted to avoid recreate jank; overlay errors.
                  Offstage(
                    offstage: _error != null,
                    child: RepaintBoundary(
                      child: WebViewWidget(
                        controller: _controller,
                        gestureRecognizers: _webGestures,
                      ),
                    ),
                  ),
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_outlined,
                                size: 40, color: AppTheme.muted),
                            const SizedBox(height: 12),
                            Text(
                              _softTip ?? '暂时无法播放',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '可以重试，或到 B 站打开',
                              textAlign: TextAlign.center,
                              style: TextStyle(
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
