import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

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

  static Future<PackageInfo> currentInfo() => PackageInfo.fromPlatform();

  /// Returns newer release if available, else null.
  static Future<UpdateInfo?> checkLatest() async {
    final info = await PackageInfo.fromPlatform();
    final res = await http.get(
      Uri.parse(repoApi),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'HowToCook-mobile',
      },
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('检查更新失败 (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').trim();
    final version = tag.startsWith('v') || tag.startsWith('V')
        ? tag.substring(1)
        : tag;
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
    if (!_isNewer(version, info.version)) return null;
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
      final core = v.split('+').first.split('-').first;
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

  /// Download APK and open installer (Android). Returns OpenResult message.
  static Future<String> downloadAndInstall(
    String apkUrl, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return '请到 GitHub Release 下载安装包';
    }
    final dir = await getTemporaryDirectory();
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
      final streamed = await client.send(req).timeout(const Duration(seconds: 30));
      if (streamed.statusCode != 200) {
        throw Exception('下载失败 (${streamed.statusCode})');
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
    } finally {
      client.close();
    }

    final result = await OpenFilex.open(file.path);
    return result.message;
  }
}
