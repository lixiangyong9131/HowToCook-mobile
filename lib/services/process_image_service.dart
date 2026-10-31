import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recipe.dart';

/// 9:16 process cards from king-jingxiang/HowToCook.
///
/// Resolution order: **bundled asset** → disk cache → network download.
/// Bundled under `assets/process_images/<cat>__<title>.jpeg`.
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

  /// Asset path for an index key (`aquatic/白灼虾` → `…/aquatic__白灼虾.jpeg`).
  static String assetPathForKey(String key) =>
      'assets/process_images/${key.replaceAll('/', '__')}.jpeg';

  /// Resolve relative key like `vegetable_dish/蚝油生菜` if present in index.
  String? keyFor(Recipe recipe) {
    final cat = recipe.categoryId;
    final title = recipe.title;
    final stem = p.basenameWithoutExtension(recipe.path);
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
    final suffix = '/$title';
    final hits = _keys.where((k) => k.endsWith(suffix)).toList();
    if (hits.length == 1) return hits.first;
    final catHits = hits.where((k) => k.startsWith('$cat/')).toList();
    if (catHits.length == 1) return catHits.first;
    return null;
  }

  bool hasImage(Recipe recipe) => keyFor(recipe) != null;

  /// Canonical bundled asset path when the recipe has an index key.
  String? assetPathFor(Recipe recipe) {
    final key = keyFor(recipe);
    if (key == null) return null;
    return assetPathForKey(key);
  }

  String? remoteUrlFor(Recipe recipe) {
    final key = keyFor(recipe);
    if (key == null) return null;
    final parts = key.split('/');
    final encoded = parts.map(Uri.encodeComponent).join('/');
    return '$_baseUrl$encoded.jpeg';
  }

  /// Prefer bundled asset (instant), else disk cache / network file.
  Future<ProcessImageBytes?> loadFor(Recipe recipe) async {
    await ensureLoaded();
    final key = keyFor(recipe);
    if (key == null) return null;

    final asset = assetPathForKey(key);
    try {
      final data = await rootBundle.load(asset);
      return ProcessImageBytes.asset(
        asset,
        data.buffer.asUint8List(),
      );
    } catch (_) {}

    final file = await _fileForKey(key, download: true);
    if (file != null) return ProcessImageBytes.file(file);
    return null;
  }

  /// Disk cache / download only (legacy File path for callers that need it).
  Future<File?> cachedFileFor(Recipe recipe) async {
    await ensureLoaded();
    final key = keyFor(recipe);
    if (key == null) return null;
    return _fileForKey(key, download: true);
  }

  Future<File?> _fileForKey(String key, {required bool download}) async {
    final dir = await _cacheDir();
    final safe = key.replaceAll('/', '__');
    final file = File(p.join(dir.path, '$safe.jpeg'));
    if (await file.exists() && await file.length() > 1000) return file;
    if (!download) return null;

    final parts = key.split('/');
    final encoded = parts.map(Uri.encodeComponent).join('/');
    final url = '$_baseUrl$encoded.jpeg';
    try {
      final res = await http
          .get(Uri.parse(url), headers: {
            'User-Agent': 'HowToCook-mobile/0.6.8',
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

  /// Tip process-card key: `tips/learn/学习焯水.md` → `tips/学习焯水`.
  /// Keys whose bundled/remote card is known wrong for the tip prose.
  static const _tipImageBlocklist = <String>{
    'tips/厨房准备', // was 葱油拌面 card upstream
  };

  String? tipKeyForPath(String tipPath) {
    final stem = p.basenameWithoutExtension(tipPath);
    if (stem.isEmpty) return null;
    final key = 'tips/$stem';
    if (_tipImageBlocklist.contains(key)) return null;
    return _keys.contains(key) ? key : null;
  }

  bool hasTipImage(String tipPath) => tipKeyForPath(tipPath) != null;

  String? tipAssetPath(String tipPath) {
    final key = tipKeyForPath(tipPath);
    if (key == null) return null;
    return assetPathForKey(key);
  }

  /// Doodle / icon placeholder when a tip has prose but no bundled jpeg.
  static String tipPlaceholderAsset(String tipPath) {
    final stem = p.basenameWithoutExtension(tipPath);
    if (stem.contains('用刀') || stem.contains('刀')) {
      return 'assets/icons/doodle/cutlery.png';
    }
    // Upstream tips/厨房准备.jpeg was mislabeled 葱油拌面 — never bind that file.
    if (stem.contains('洗碗') || stem.contains('厨房准备') || stem.contains('厨房')) {
      return 'assets/icons/doodle/kitchen.png';
    }
    if (stem.contains('压力') || stem.contains('高压')) {
      return 'assets/icons/doodle/cooking-pot.png';
    }
    return 'assets/icons/doodle/chef-hat.png';
  }

    Future<Directory> _cacheDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'process_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

/// Resolved process image payload (asset bytes or on-disk file).
class ProcessImageBytes {
  final String? assetPath;
  final List<int>? assetBytes;
  final File? file;

  const ProcessImageBytes._({this.assetPath, this.assetBytes, this.file});

  factory ProcessImageBytes.asset(String path, List<int> bytes) =>
      ProcessImageBytes._(assetPath: path, assetBytes: bytes);

  factory ProcessImageBytes.file(File file) => ProcessImageBytes._(file: file);

  bool get isAsset => assetPath != null;
}
