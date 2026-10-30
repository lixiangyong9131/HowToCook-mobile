import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recipe.dart';

/// On-demand 9:16 process cards from king-jingxiang/HowToCook
/// (GitHub Pages raw JPEGs, disk-cached). Not bundled — keeps APK small.
class ProcessImageService {
  ProcessImageService._();
  static final ProcessImageService instance = ProcessImageService._();

  static const attribution =
      '整图菜谱来自 king-jingxiang/HowToCook（AI 信息图），致谢作者。';
  static const sourceUrl = 'https://github.com/king-jingxiang/HowToCook';

  String _baseUrl =
      'https://king-jingxiang.github.io/HowToCook/images/dishes/';
  final Set<String> _keys = {};
  bool _ready = false;

  Future<void> ensureLoaded() async {
    if (_ready) return;
    final raw =
        await rootBundle.loadString('assets/process_images_index.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _baseUrl = map['baseUrl'] as String? ?? _baseUrl;
    _keys
      ..clear()
      ..addAll((map['keys'] as List<dynamic>).map((e) => e as String));
    _ready = true;
  }

  /// Resolve relative key like `vegetable_dish/蚝油生菜` if present in index.
  String? keyFor(Recipe recipe) {
    final cat = recipe.categoryId;
    final title = recipe.title;
    final stem = p.basenameWithoutExtension(recipe.path);
    // Nested upstream paths: aquatic/混合烤鱼/烤鱼.md → also try parent folder.
    final parent = p.basename(p.dirname(recipe.path));
    final candidates = <String>{
      '$cat/$title',
      '$cat/$stem',
      if (parent.isNotEmpty && parent != cat) '$cat/$parent',
      if (parent.isNotEmpty && parent != cat) '$cat/$parent/$stem',
    };
    for (final c in candidates) {
      if (_keys.contains(c)) return c;
    }
    // Last resort: unique title match across keys (rare id/path drift).
    final suffix = '/$title';
    final hits = _keys.where((k) => k.endsWith(suffix)).toList();
    if (hits.length == 1) return hits.first;
    final catHits = hits.where((k) => k.startsWith('$cat/')).toList();
    if (catHits.length == 1) return catHits.first;
    return null;
  }

  bool hasImage(Recipe recipe) => keyFor(recipe) != null;

  String? remoteUrlFor(Recipe recipe) {
    final key = keyFor(recipe);
    if (key == null) return null;
    final parts = key.split('/');
    final encoded = parts.map(Uri.encodeComponent).join('/');
    return '$_baseUrl$encoded.jpeg';
  }

  Future<File?> cachedFileFor(Recipe recipe) async {
    await ensureLoaded();
    final key = keyFor(recipe);
    if (key == null) return null;
    final dir = await _cacheDir();
    final safe = key.replaceAll('/', '__');
    final file = File(p.join(dir.path, '$safe.jpeg'));
    if (await file.exists() && await file.length() > 1000) return file;

    final url = remoteUrlFor(recipe);
    if (url == null) return null;
    try {
      final res = await http
          .get(Uri.parse(url), headers: {
            'User-Agent': 'HowToCook-mobile/0.6.3',
            'Accept': 'image/jpeg,image/*;q=0.8',
          })
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200 && res.bodyBytes.length > 1000) {
        await file.writeAsBytes(res.bodyBytes, flush: true);
        return file;
      }
    } catch (_) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    return null;
  }

  Future<Directory> _cacheDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'process_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
