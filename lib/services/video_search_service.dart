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

  /// Parses official search API result items (`pic` / `play` / `bvid` / …).
  factory BiliVideo.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String? ?? '')
        .replaceAll(RegExp(r'</?em[^>]*>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return BiliVideo(
      bvid: json['bvid'] as String? ?? '',
      title: title,
      author: json['author'] as String? ?? '',
      duration: '${json['duration'] ?? ''}',
      cover: json['pic'] as String? ?? json['cover'] as String? ?? '',
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

/// Outcome of one search, after in-service retries.
///
/// [ok] has videos. [empty] means Bilibili answered `code == 0` with no hits.
/// [failed] means every attempt timed out, returned a non-200 (often HTTP 412
/// risk-control HTML), or returned `code != 0`.
enum VideoSearchStatus { ok, empty, failed }

class VideoSearchResult {
  final List<BiliVideo> results;
  final String keyword;

  /// bilibili | fallback
  ///
  /// `bilibili` when the API returned `code == 0` (videos or a real empty).
  /// `fallback` when the search never got that far; [searchUrl] is still set.
  final String source;
  final String searchUrl;
  final VideoSearchStatus status;

  const VideoSearchResult({
    required this.results,
    required this.keyword,
    required this.source,
    required this.searchUrl,
    required this.status,
  });
}

/// Searches Bilibili via the official web search API
/// (`/x/web-interface/search/type`).
///
/// The endpoint often answers the first call with HTTP 412 and an HTML
/// risk-control page, then succeeds on the next call. A single failure used
/// to be reported as "no videos". This client retries transient failures and
/// empty payloads with a short backoff, and only then distinguishes a real
/// empty (`code == 0`, no hits) from a failed search.
class VideoSearchService {
  static const _bili = 'https://api.bilibili.com/x/web-interface/search/type';

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36',
    'Referer': 'https://search.bilibili.com',
  };

  /// Pause before the 2nd and 3rd attempts. Kept short: an HTTP 412 usually
  /// comes back in well under a second, and the next call often succeeds.
  static const defaultRetryDelays = <Duration>[
    Duration(milliseconds: 250),
    Duration(milliseconds: 600),
  ];

  static String searchUrlFor(String dishName) =>
      'https://search.bilibili.com/all?keyword=${Uri.encodeComponent('$dishName的做法')}';

  static Future<VideoSearchResult> search(
    String dishName, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
    int maxAttempts = 3,
    List<Duration> retryDelays = defaultRetryDelays,
    Future<void> Function(Duration delay)? backoff,
  }) async {
    final keyword = dishName.trim();
    final searchUrl = searchUrlFor(keyword);
    if (keyword.isEmpty) {
      return VideoSearchResult(
        results: const [],
        keyword: keyword,
        source: 'fallback',
        searchUrl: searchUrl,
        status: VideoSearchStatus.empty,
      );
    }

    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final uri = Uri.parse(_bili).replace(
      queryParameters: {
        'search_type': 'video',
        'keyword': '$keyword的做法',
        'page': '1',
      },
    );
    final wait = backoff ?? Future<void>.delayed;

    try {
      var sawEmpty = false;
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (attempt > 0) {
          await wait(_delayBefore(attempt, retryDelays));
        }
        final parsed = await _fetchOnce(httpClient, uri, timeout);
        if (parsed.status == VideoSearchStatus.ok) {
          return VideoSearchResult(
            results: parsed.videos,
            keyword: keyword,
            source: 'bilibili',
            searchUrl: searchUrl,
            status: VideoSearchStatus.ok,
          );
        }
        if (parsed.status == VideoSearchStatus.empty) sawEmpty = true;
      }

      // A code-0 empty is a real answer. Failures mixed in (412, timeout)
      // still lose to that, because the API did confirm there were no hits.
      // Status is `failed` only when no attempt produced code 0.
      if (sawEmpty) {
        return VideoSearchResult(
          results: const [],
          keyword: keyword,
          source: 'bilibili',
          searchUrl: searchUrl,
          status: VideoSearchStatus.empty,
        );
      }
      return VideoSearchResult(
        results: const [],
        keyword: keyword,
        source: 'fallback',
        searchUrl: searchUrl,
        status: VideoSearchStatus.failed,
      );
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  static Duration _delayBefore(int attempt, List<Duration> retryDelays) {
    if (retryDelays.isEmpty) return const Duration(milliseconds: 300);
    final index = attempt - 1;
    if (index < retryDelays.length) return retryDelays[index];
    return retryDelays.last;
  }

  static Future<_Attempt> _fetchOnce(
    http.Client client,
    Uri uri,
    Duration timeout,
  ) async {
    try {
      final res = await client.get(uri, headers: _headers).timeout(timeout);
      if (res.statusCode != 200) return const _Attempt.failed();
      return _parseBody(res.body);
    } catch (_) {
      return const _Attempt.failed();
    }
  }

  static _Attempt _parseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return const _Attempt.failed();
      final code = decoded['code'];
      final data = decoded['data'];
      final dataMap = data is Map<String, dynamic> ? data : null;
      final list = (dataMap?['result'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BiliVideo.fromJson)
          .where((v) => v.bvid.isNotEmpty)
          .take(12)
          .toList();
      final successCode = code == null || code == 0 || code == '0';
      if (list.isNotEmpty && successCode) {
        return _Attempt(VideoSearchStatus.ok, list);
      }
      // Only an explicit code 0 counts as "this dish has no videos".
      // Missing code, -412, -509, and HTML bodies are transient failures.
      if (code == 0 || code == '0') {
        return const _Attempt(VideoSearchStatus.empty, []);
      }
      return const _Attempt.failed();
    } catch (_) {
      return const _Attempt.failed();
    }
  }
}

class _Attempt {
  final VideoSearchStatus status;
  final List<BiliVideo> videos;

  const _Attempt(this.status, this.videos);

  const _Attempt.failed() : this(VideoSearchStatus.failed, const []);
}
