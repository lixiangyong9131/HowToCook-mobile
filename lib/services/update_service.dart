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

class UpdateService {
  static const repoApi =
      'https://api.github.com/repos/lixiangyong9131/HowToCook-mobile/releases/latest';

  static const _installerChannel =
      MethodChannel('com.howtocook.how_to_cook/installer');

  static Future<PackageInfo> currentInfo() => PackageInfo.fromPlatform();

  /// Normalize tags like `v0.5.0`, `V0.5.0+6`, `release-0.5.0` → `0.5.0`.
  static String normalizeVersion(String raw) {
    var v = raw.trim();
    if (v.toLowerCase().startsWith('v')) v = v.substring(1);
    v = v.split('+').first; // drop build
    // Keep pre-release core before first hyphen if it looks like semver.
    final m = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(v);
    return m?.group(1) ?? v.trim();
  }

  /// Returns newer release if available, else null.
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

  /// Semver-ish compare: true if remote > local.
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

  /// Prefer temp/cache (FileProvider cache-path), then external-files.
  static Future<Directory> _apkDir() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(p.join(tmp.path, 'updates'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {}
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.path, 'updates'));
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'updates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<bool> _looksLikeApk(File file) async {
    final raf = await file.open();
    try {
      final magic = await raf.read(4);
      // ZIP / APK local file header: PK\x03\x04
      return magic.length >= 4 &&
          magic[0] == 0x50 &&
          magic[1] == 0x4b &&
          magic[2] == 0x03 &&
          magic[3] == 0x04;
    } finally {
      await raf.close();
    }
  }

  /// Launch system installer via FileProvider MethodChannel; fall back to OpenFilex.
  static Future<String> _launchInstaller(File file) async {
    try {
      final status = await _installerChannel.invokeMethod<String>(
        'installApk',
        {'path': file.path},
      );
      switch (status) {
        case 'launched':
        case 'session_committed':
          return '已调起安装程序，请按系统提示完成安装';
        case 'need_permission':
          return '请先允许「安装未知应用」，返回 App 后再次点「下载并安装」';
        default:
          if (status != null && status.isNotEmpty) {
            return '安装状态：$status';
          }
      }
    } on PlatformException catch (e) {
      // Fall through to OpenFilex.
      debugPrint('installApk channel failed: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('installApk channel error: $e');
    }

    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    switch (result.type) {
      case ResultType.done:
        return '已调起安装程序，请按系统提示完成安装';
      case ResultType.noAppToOpen:
        return '无法打开安装程序。请在系统设置中允许「安装未知应用」，或手动安装：${file.path}';
      case ResultType.permissionDenied:
        try {
          await _installerChannel.invokeMethod('openInstallPermissionSettings');
        } catch (_) {}
        return '没有安装权限。请到系统设置 → 应用 → 允许安装未知应用后重试';
      case ResultType.fileNotFound:
        return '安装包丢失，请重新下载';
      case ResultType.error:
        return '打开安装包失败：${result.message}';
    }
  }

  /// Download APK and open installer (Android). Returns user-facing message.
  static Future<String> downloadAndInstall(
    String apkUrl, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return '请到 GitHub Release 下载安装包';
    }

    final dir = await _apkDir();
    final file = File(p.join(dir.path, 'how_to_cook_update.apk'));
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(apkUrl));
      req.headers['User-Agent'] = 'HowToCook-mobile';
      req.headers['Accept'] = '*/*';
      // ~85MB APK: allow long transfer; incomplete files still start with PK..
      final streamed =
          await client.send(req).timeout(const Duration(minutes: 10));
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw Exception('下载失败（HTTP ${streamed.statusCode}）');
      }
      final total = streamed.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      // Incomplete download is a known install-failure root cause: magic still PK.
      if (total > 0 && received < total) {
        try { await file.delete(); } catch (_) {}
        throw Exception('下载不完整（$received / $total 字节），请重试');
      }
      if (received < 5 * 1024 * 1024) {
        try { await file.delete(); } catch (_) {}
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
      throw Exception('下载内容不是有效 APK（文件头校验失败），请稍后重试或到 GitHub 手动下载');
    }

    return _launchInstaller(file);
  }
}
