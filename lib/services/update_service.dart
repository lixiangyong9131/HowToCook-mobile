import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String tag; // e.g. v0.4.0
  final String version; // e.g. 0.4.0
  final String body;
  final String? apkUrl;
  final String htmlUrl;

  const UpdateInfo({
    required this.tag,
    required this.version,
    required this.body,
    required this.apkUrl,
    required this.htmlUrl,
  });
}

/// Persisted download metadata so install can retry without re-downloading.
class CachedApk {
  final String path;
  final String tag;
  final String url;
  final int bytes;

  const CachedApk({
    required this.path,
    required this.tag,
    required this.url,
    required this.bytes,
  });

  File get file => File(path);
}

class UpdateService {
  static const repoApi =
      'https://api.github.com/repos/lixiangyong9131/HowToCook-mobile/releases/latest';

  static const _installerChannel =
      MethodChannel('com.howtocook.how_to_cook/installer');

  static const _prefPath = 'update_apk_path';
  static const _prefTag = 'update_apk_tag';
  static const _prefUrl = 'update_apk_url';
  static const _prefBytes = 'update_apk_bytes';

  static Future<PackageInfo> currentInfo() => PackageInfo.fromPlatform();

  /// Normalize tags like `v0.5.0`, `V0.5.0+6`, `release-0.5.0` → `0.5.0`.
  static String normalizeVersion(String raw) {
    var v = raw.trim();
    if (v.toLowerCase().startsWith('v')) v = v.substring(1);
    v = v.split('+').first;
    final m = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(v);
    return m?.group(1) ?? v.trim();
  }

  static Future<UpdateInfo?> checkLatest() async {
    final info = await PackageInfo.fromPlatform();
    late http.Response res;
    try {
      res = await http.get(
        Uri.parse(repoApi),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'HowToCook-mobile',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ).timeout(const Duration(seconds: 20));
    } on SocketException catch (e) {
      throw Exception('网络不可用，请检查网络后重试（$e）');
    } on HttpException catch (e) {
      throw Exception('网络请求失败：$e');
    } on HandshakeException catch (e) {
      throw Exception('HTTPS 证书校验失败：$e');
    } on TimeoutException {
      throw Exception('检查更新超时，请稍后重试');
    }

    if (res.statusCode == 404) {
      throw Exception('尚未发布任何版本（GitHub Releases 为空）');
    }
    if (res.statusCode != 200) {
      throw Exception('检查更新失败（HTTP ${res.statusCode}）');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').trim();
    final version = normalizeVersion(tag);
    final body = (json['body'] as String?) ?? '';
    final htmlUrl = (json['html_url'] as String?) ?? '';
    String? apkUrl;
    final assets = json['assets'] as List<dynamic>? ?? const [];
    for (final a in assets) {
      final m = a as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = m['browser_download_url'] as String?;
        break;
      }
    }
    final local = normalizeVersion(info.version);
    if (version.isEmpty) {
      throw Exception('无法解析远端版本号：$tag');
    }
    if (!_isNewer(version, local)) return null;
    return UpdateInfo(
      tag: tag.isEmpty ? 'v$version' : tag,
      version: version,
      body: body,
      apkUrl: apkUrl,
      htmlUrl: htmlUrl,
    );
  }

  static bool _isNewer(String remote, String local) {
    List<int> parse(String v) {
      final core = normalizeVersion(v);
      return core
          .split('.')
          .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final a = parse(remote);
    final b = parse(local);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x > y) return true;
      if (x < y) return false;
    }
    return false;
  }

  /// Stable dir (support/files), FileProvider-friendly; not wiped like temp.
  static Future<Directory> _apkDir() async {
    // Prefer app support (files) — survives longer than cache/temp.
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'updates'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {}
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'updates'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {}
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'updates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _persistCache({
    required String path,
    required String tag,
    required String url,
    required int bytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPath, path);
    await prefs.setString(_prefTag, tag);
    await prefs.setString(_prefUrl, url);
    await prefs.setInt(_prefBytes, bytes);
  }

  static Future<void> clearCachedApk({bool deleteFile = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefPath);
    await prefs.remove(_prefPath);
    await prefs.remove(_prefTag);
    await prefs.remove(_prefUrl);
    await prefs.remove(_prefBytes);
    if (deleteFile && path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Valid on-disk APK for [tag] / [url] if still present.
  static Future<CachedApk?> cachedApk({String? tag, String? url}) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefPath);
    final savedTag = prefs.getString(_prefTag) ?? '';
    final savedUrl = prefs.getString(_prefUrl) ?? '';
    final bytes = prefs.getInt(_prefBytes) ?? 0;
    if (path == null || path.isEmpty || bytes < 5 * 1024 * 1024) return null;
    if (tag != null && tag.isNotEmpty && savedTag.isNotEmpty && tag != savedTag) {
      return null;
    }
    if (url != null && url.isNotEmpty && savedUrl.isNotEmpty && url != savedUrl) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) return null;
    final len = await file.length();
    // Allow small FS rounding; reject truncated files.
    if (len < bytes * 0.98 || len < 5 * 1024 * 1024) return null;
    if (!await _looksLikeApk(file)) return null;
    return CachedApk(path: path, tag: savedTag, url: savedUrl, bytes: bytes);
  }

  static Future<bool> _looksLikeApk(File file) async {
    final raf = await file.open();
    try {
      final magic = await raf.read(4);
      return magic.length >= 4 &&
          magic[0] == 0x50 &&
          magic[1] == 0x4b &&
          magic[2] == 0x03 &&
          magic[3] == 0x04;
    } finally {
      await raf.close();
    }
  }

  /// Install a local APK (no download). Keeps file on failure for retry.
  static Future<String> installCachedApk(File file) async {
    if (!await file.exists()) {
      await clearCachedApk(deleteFile: false);
      return '本地安装包不存在，请重新下载';
    }
    if (!await _looksLikeApk(file)) {
      return '本地文件不是有效 APK，请清除后重新下载';
    }
    return _launchInstaller(file);
  }

  /// Launch system installer via FileProvider MethodChannel; fall back carefully.
  static Future<String> _launchInstaller(File file) async {
    if (!await file.exists()) {
      // Root cause of the old 「安装包丢失」 toast: OpenFilex fileNotFound after
      // channel failure, often because temp/cache path was wiped or wrong.
      return '安装包路径无效（文件不存在）。已保留下载记录，请点「继续安装」或重新下载';
    }

    try {
      final status = await _installerChannel.invokeMethod<String>(
        'installApk',
        {'path': file.absolute.path},
      );
      switch (status) {
        case 'launched':
        case 'session_committed':
          return '已调起安装程序，请按系统提示完成安装（包仍保留，失败可继续安装）';
        case 'need_permission':
          return '请先允许「安装未知应用」，返回后点「继续安装」（无需重新下载）';
        default:
          if (status != null && status.isNotEmpty) {
            return '安装状态：$status';
          }
      }
    } on PlatformException catch (e) {
      debugPrint('installApk channel failed: ${e.code} ${e.message}');
      // Prefer surfacing native error over OpenFilex false "file missing".
      if (e.code == 'install_failed' &&
          (e.message?.contains('file_not_found') ?? false)) {
        return '原生安装找不到文件：${file.path}。请重新下载';
      }
      // Fall through to OpenFilex only if file still on disk.
    } catch (e) {
      debugPrint('installApk channel error: $e');
    }

    if (!await file.exists()) {
      return '安装包在调起过程中丢失，请重新下载';
    }

    final result = await OpenFilex.open(
      file.absolute.path,
      type: 'application/vnd.android.package-archive',
    );
    switch (result.type) {
      case ResultType.done:
        return '已调起安装程序，请按系统提示完成安装';
      case ResultType.noAppToOpen:
        return '无法打开安装程序。请允许「安装未知应用」，或手动安装：${file.path}';
      case ResultType.permissionDenied:
        try {
          await _installerChannel.invokeMethod('openInstallPermissionSettings');
        } catch (_) {}
        return '没有安装权限。请到设置允许安装未知应用后点「继续安装」';
      case ResultType.fileNotFound:
        // OpenFilex often reports this even when File.exists — path/provider issue.
        final stillThere = await file.exists();
        if (stillThere) {
          return '系统安装器无法读取安装包（文件仍在）。请到「我的」再点继续安装，或允许安装未知应用';
        }
        await clearCachedApk(deleteFile: false);
        return '安装包丢失，请重新下载';
      case ResultType.error:
        return '打开安装包失败：${result.message}（可点继续安装重试，无需重下）';
    }
  }

  /// Download APK if needed, then install. Reuses cache for same [tag]/[url].
  static Future<String> downloadAndInstall(
    String apkUrl, {
    String? tag,
    void Function(double progress)? onProgress,
    bool forceRedownload = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return '请到 GitHub Release 下载安装包';
    }

    final label = tag ?? 'update';

    if (!forceRedownload) {
      final cached = await cachedApk(tag: tag, url: apkUrl);
      if (cached != null) {
        onProgress?.call(1);
        return installCachedApk(cached.file);
      }
    }

    final dir = await _apkDir();
    final file = File(p.join(dir.path, 'how_to_cook_update.apk'));
    // Only delete when we are about to replace with a fresh download.
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    final client = http.Client();
    var received = 0;
    var total = 0;
    try {
      final req = http.Request('GET', Uri.parse(apkUrl));
      req.headers['User-Agent'] = 'HowToCook-mobile';
      req.headers['Accept'] = '*/*';
      final streamed =
          await client.send(req).timeout(const Duration(minutes: 10));
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw Exception('下载失败（HTTP ${streamed.statusCode}）');
      }
      total = streamed.contentLength ?? 0;
      final sink = file.openWrite();
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      if (total > 0 && received < total) {
        try {
          await file.delete();
        } catch (_) {}
        throw Exception('下载不完整（$received / $total 字节），请重试');
      }
      if (received < 5 * 1024 * 1024) {
        try {
          await file.delete();
        } catch (_) {}
        throw Exception('下载的文件过小（$received 字节），可能不是完整 APK');
      }
    } on SocketException catch (e) {
      throw Exception('下载失败：网络不可用（$e）');
    } on TimeoutException {
      throw Exception('下载超时（大包约 80MB），请检查网络后重试');
    } finally {
      client.close();
    }

    if (!await _looksLikeApk(file)) {
      try {
        await file.delete();
      } catch (_) {}
      throw Exception('下载内容不是有效 APK（文件头校验失败），请稍后重试或到 GitHub 手动下载');
    }

    // Persist until install succeeds or user clears — never delete on install fail.
    await _persistCache(
      path: file.absolute.path,
      tag: label,
      url: apkUrl,
      bytes: received,
    );

    return _launchInstaller(file);
  }
}
