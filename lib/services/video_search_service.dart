import 'dart:convert';

import 'package:http/http.dart' as http;

/// One Bilibili search hit (covers thumbnails + meta for the video sheet).
class BiliVideo {
  final String bvid;
  final String title;
  final String author;
  final String duration;
  final String cover;
  final int play;

  const BiliVideo({
    required this.bvid,
    required this.title,
    required this.author,
    required this.duration,
    required this.cover,
    required this.play,
  });

  String get watchUrl => 'https://www.bilibili.com/video/$bvid';

  String get coverHttps {
    if (cover.startsWith('//')) return 'https:$cover';
    if (cover.startsWith('http')) return cover;
    return 'https://$cover';
  }

  String get playLabel {
    if (play >= 10000) {
      final v = play / 10000;
      final s = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      return '$s 万';
    }
    return '$play';
  }

  factory BiliVideo.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String? ?? '')
        .replaceAll(RegExp(r'</?em[^>]*>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return BiliVideo(
      bvid: json['bvid'] as String? ?? '',
      title: title,
      author: json['author'] as String? ?? '',
      duration: '${json['duration'] ?? ''}',
      cover: json['cover'] as String? ??
          json['pic'] as String? ??
          '',
      play: _asInt(json['play'] ?? json['play_count'] ?? json['video_review']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }
}

class VideoSearchResult {
  final List<BiliVideo> results;
  final String keyword;
  final String source; // ryanuo | bilibili | fallback
  final String searchUrl;

  const VideoSearchResult({
    required this.results,
    required this.keyword,
    required this.source,
    required this.searchUrl,
  });
}

/// Prefer eat.ryanuo.cc backend (same as https://eat.ryanuo.cc/),
/// then official Bilibili search API; last resort is search URL intent only.
class VideoSearchService {
  static const _ryanuo =
      'https://eat.ryanuo.cc/api/video-search';
  static const _bili =
      'https://api.bilibili.com/x/web-interface/search/type';

  static String searchUrlFor(String dishName) =>
      'https://search.bilibili.com/all?keyword=${Uri.encodeComponent('$dishName的做法')}';

  static Future<VideoSearchResult> search(String dishName) async {
    final keyword = dishName.trim();
    final searchUrl = searchUrlFor(keyword);
    if (keyword.isEmpty) {
      return VideoSearchResult(
        results: const [],
        keyword: keyword,
        source: 'fallback',
        searchUrl: searchUrl,
      );
    }

    try {
      final uri = Uri.parse(_ryanuo).replace(queryParameters: {'name': keyword});
      final res = await http
          .get(uri, headers: {'User-Agent': 'HowToCook-mobile/0.5'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (map['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BiliVideo.fromJson)
            .where((v) => v.bvid.isNotEmpty)
            .toList();
        if (list.isNotEmpty) {
          return VideoSearchResult(
            results: list,
            keyword: keyword,
            source: 'ryanuo',
            searchUrl: searchUrl,
          );
        }
      }
    } catch (_) {
      // fall through
    }

    try {
      final uri = Uri.parse(_bili).replace(queryParameters: {
        'search_type': 'video',
        'keyword': '$keyword的做法',
        'page': '1',
      });
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36',
        'Referer': 'https://search.bilibili.com',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final data = map['data'] as Map<String, dynamic>? ?? {};
        final list = (data['result'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BiliVideo.fromJson)
            .where((v) => v.bvid.isNotEmpty)
            .take(12)
            .toList();
        if (list.isNotEmpty) {
          return VideoSearchResult(
            results: list,
            keyword: keyword,
            source: 'bilibili',
            searchUrl: searchUrl,
          );
        }
      }
    } catch (_) {
      // fall through
    }

    return VideoSearchResult(
      results: const [],
      keyword: keyword,
      source: 'fallback',
      searchUrl: searchUrl,
    );
  }
}
