import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/services/video_search_service.dart';
import 'package:how_to_cook/widgets/video_recipes_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const cake = '戚风蛋糕';

  String okBody() => jsonEncode({
    'code': 0,
    'message': 'OK',
    'data': {
      'result': [
        {
          'bvid': 'BV1bY4y1B7Tm',
          'title': '<em class="keyword">戚风蛋糕</em>的做法',
          'author': '唐七七',
          'duration': '12:03',
          'pic': '//i0.hdslb.com/bfs/archive/x.jpg',
          'play': 15000,
        },
        {'bvid': '', 'title': 'no id'},
      ],
    },
  });

  String emptyBody() => jsonEncode({
        'code': 0,
        'message': 'OK',
        'data': {'result': <Object>[]},
      });

  /// http.Response encodes a string body as latin1 unless the content-type
  /// says JSON. Chinese titles need UTF-8 or the mock throws before the
  /// service can parse.
  http.Response jsonResponse(String body, int statusCode) {
    return http.Response(
      body,
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<VideoSearchResult> searchWith(
    http.Client client, {
    void Function(Duration delay)? onDelay,
    int maxAttempts = 3,
  }) {
    return VideoSearchService.search(
      cake,
      client: client,
      maxAttempts: maxAttempts,
      retryDelays: VideoSearchService.defaultRetryDelays,
      backoff: (delay) async {
        onDelay?.call(delay);
      },
    );
  }

  test('HTTP 412 then 200 returns videos without a manual retry', () async {
    var calls = 0;
    final delays = <Duration>[];
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, '/x/web-interface/search/type');
      expect(request.url.queryParameters['search_type'], 'video');
      expect(request.url.queryParameters['page'], '1');
      expect(request.url.queryParameters['keyword'], '戚风蛋糕的做法');
      expect(request.headers['referer'], 'https://search.bilibili.com');
      if (calls == 1) {
        return http.Response('<!DOCTYPE html><html>412</html>', 412);
      }
      return jsonResponse(okBody(), 200);
    });

    final result = await searchWith(client, onDelay: delays.add);

    expect(calls, 2);
    expect(delays, [const Duration(milliseconds: 250)]);
    expect(result.status, VideoSearchStatus.ok);
    expect(result.source, 'bilibili');
    expect(result.searchUrl, VideoSearchService.searchUrlFor(cake));
    expect(result.results, hasLength(1));
    final video = result.results.single;
    expect(video.bvid, 'BV1bY4y1B7Tm');
    expect(video.title, '戚风蛋糕的做法');
    expect(video.author, '唐七七');
    expect(video.coverHttps, 'https://i0.hdslb.com/bfs/archive/x.jpg');
    expect(video.playLabel, '1.5 万');
    expect(video.watchUrl, 'https://www.bilibili.com/video/BV1bY4y1B7Tm');
  });

  test('repeated HTTP 412 is a failure, not an empty result', () async {
    var calls = 0;
    final delays = <Duration>[];
    final client = MockClient((request) async {
      calls++;
      return http.Response('<html>banned</html>', 412);
    });

    final result = await searchWith(client, onDelay: delays.add);

    expect(calls, 3);
    expect(delays, VideoSearchService.defaultRetryDelays);
    expect(result.status, VideoSearchStatus.failed);
    expect(result.source, 'fallback');
    expect(result.results, isEmpty);
    expect(result.searchUrl, VideoSearchService.searchUrlFor(cake));
  });

  test('JSON code -412 is retried like a risk-control response', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls < 3) {
        return jsonResponse(
          jsonEncode({
            'code': -412,
            'message': 'request was banned',
            'data': null,
          }),
          200,
        );
      }
      return jsonResponse(okBody(), 200);
    });

    final result = await searchWith(client);

    expect(calls, 3);
    expect(result.status, VideoSearchStatus.ok);
    expect(result.results.single.bvid, 'BV1bY4y1B7Tm');
  });

  test('timeout then success does not surface as no videos', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw TimeoutException('timed out');
      return jsonResponse(okBody(), 200);
    });

    final result = await searchWith(client);

    expect(calls, 2);
    expect(result.status, VideoSearchStatus.ok);
  });

  test('empty code-0 payload is retried, then kept as a real empty', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return jsonResponse(emptyBody(), 200);
    });

    final result = await searchWith(client);

    expect(calls, 3);
    expect(result.status, VideoSearchStatus.empty);
    expect(result.source, 'bilibili');
    expect(result.results, isEmpty);
  });

  test('a later hit replaces an earlier empty payload', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) return jsonResponse(emptyBody(), 200);
      return jsonResponse(okBody(), 200);
    });

    final result = await searchWith(client);

    expect(calls, 2);
    expect(result.status, VideoSearchStatus.ok);
    expect(result.results, isNotEmpty);
  });

  test(
    'code-0 empty wins over a mixed 412 once retries are exhausted',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
      if (calls == 1) return http.Response('nope', 412);
      return jsonResponse(emptyBody(), 200);
      });

      final result = await searchWith(client);

      expect(calls, 3);
      expect(result.status, VideoSearchStatus.empty);
      expect(result.source, 'bilibili');
    },
  );

  test('invalid JSON is a failure and still retries', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('<html>not json</html>', 200);
    });

    final result = await searchWith(client);

    expect(calls, 3);
    expect(result.status, VideoSearchStatus.failed);
  });

  test('blank dish name does not call Bilibili', () async {
    final client = MockClient((request) async {
      fail('should not request');
    });

    final result = await VideoSearchService.search(
      '   ',
      client: client,
      backoff: (_) async => fail('should not retry'),
    );

    expect(result.status, VideoSearchStatus.empty);
    expect(result.results, isEmpty);
    expect(result.source, 'fallback');
    expect(result.searchUrl, VideoSearchService.searchUrlFor(''));
  });

  testWidgets('failed search is not copy for no videos, links stay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoRecipesSheet(
          dishName: cake,
          search: (_) async => VideoSearchResult(
            results: const [],
            keyword: cake,
            source: 'fallback',
            searchUrl: VideoSearchService.searchUrlFor(cake),
            status: VideoSearchStatus.failed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索暂时失败'), findsOneWidget);
    expect(find.text('网络不稳定或被 B 站拦截，并不是这道菜没有视频'), findsOneWidget);
    expect(find.text('😔 没有找到相关视频'), findsNothing);
    expect(find.text('在 B 站打开'), findsOneWidget);
    expect(find.text('去 B 站搜索'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('confirmed empty still says there are no videos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoRecipesSheet(
          dishName: cake,
          search: (_) async => VideoSearchResult(
            results: const [],
            keyword: cake,
            source: 'bilibili',
            searchUrl: VideoSearchService.searchUrlFor(cake),
            status: VideoSearchStatus.empty,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('😔 没有找到相关视频'), findsOneWidget);
    expect(find.text('搜索暂时失败'), findsNothing);
    expect(find.text('在 B 站打开'), findsOneWidget);
    expect(find.text('去 B 站搜索'), findsOneWidget);
  });

  testWidgets('重试 calls search again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VideoRecipesSheet(
          dishName: cake,
          search: (_) async {
            calls++;
            return VideoSearchResult(
              results: const [],
              keyword: cake,
              source: 'fallback',
              searchUrl: VideoSearchService.searchUrlFor(cake),
              status: VideoSearchStatus.failed,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.text('搜索暂时失败'), findsOneWidget);
  });
}
