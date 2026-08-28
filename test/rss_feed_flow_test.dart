import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filter_flow/core/db/app_database.dart';
import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/models/field_mapping.dart';
import 'package:filter_flow/providers/core_providers.dart';
import 'package:filter_flow/providers/feed_list_provider.dart';
import 'package:filter_flow/ui/feed/feed_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端到端链路测试：内存数据库 + 假 HTTP 适配器，
/// 真跑 "数据库里的 RSS 源 → allFeedSourcesProvider 分流 → RssFeedRepository
/// 网络拉取 → XML 解析 → 屏蔽词过滤 → FeedNotifier 聚合去重 → 信息流渲染"。

const _atomXml = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>阮一峰的网络日志</title>
  <entry>
    <title>科技爱好者周刊（第 100 期）</title>
    <link rel="alternate" href="https://www.ruanyifeng.com/blog/2026/01/post-100.html" />
    <id>tag:www.ruanyifeng.com,2026:blog.post.100</id>
    <published>2026-01-02T08:30:00+08:00</published>
    <author><name>阮一峰</name></author>
    <content type="html">&lt;p&gt;本周内容&lt;/p&gt;</content>
  </entry>
  <entry>
    <title>工具性与实用性</title>
    <link rel="alternate" href="https://www.ruanyifeng.com/blog/2026/01/post-99.html" />
    <id>tag:www.ruanyifeng.com,2026:blog.post.99</id>
    <published>2026-01-01T08:30:00+08:00</published>
    <author><name>阮一峰</name></author>
    <content type="html">&lt;p&gt;旧文重读&lt;/p&gt;</content>
  </entry>
  <entry>
    <title>RSS 仍然是最好的订阅方式</title>
    <link rel="alternate" href="https://www.ruanyifeng.com/blog/2025/12/post-98.html" />
    <id>tag:www.ruanyifeng.com,2026:blog.post.98</id>
    <published>2025-12-31T08:30:00+08:00</published>
    <author><name>阮一峰</name></author>
    <content type="html">&lt;p&gt;谈谈 RSS&lt;/p&gt;</content>
  </entry>
  <entry>
    <title>每周软件更新</title>
    <link rel="alternate" href="https://www.ruanyifeng.com/blog/2025/12/post-97.html" />
    <id>tag:www.ruanyifeng.com,2026:blog.post.97</id>
    <published>2025-12-30T08:30:00+08:00</published>
    <author><name>阮一峰</name></author>
    <content type="html">&lt;p&gt;软件更新&lt;/p&gt;</content>
  </entry>
  <entry>
    <title>数字极简主义实践</title>
    <link rel="alternate" href="https://www.ruanyifeng.com/blog/2025/12/post-96.html" />
    <id>tag:www.ruanyifeng.com,2026:blog.post.96</id>
    <published>2025-12-29T08:30:00+08:00</published>
    <author><name>阮一峰</name></author>
    <content type="html">&lt;p&gt;极简生活&lt;/p&gt;</content>
  </entry>
</feed>
''';

const _hnJson = '''
{
  "hits": [
    {"title": "My AI story", "url": "https://example.com/ai",
     "author": "pg", "created_at": "2026-01-01T10:00:00Z"}
  ]
}
''';

/// 按 URL 路由的假 HTTP 适配器：atom.xml 回 Atom 报文，HN 回 JSON。
class _FakeAdapter implements HttpClientAdapter {
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    final url = options.uri.toString();
    if (url.contains('atom.xml')) {
      return ResponseBody.fromString(
        _atomXml,
        200,
        headers: {
          Headers.contentTypeHeader: ['application/xml'],
        },
      );
    }
    if (url.contains('hn.algolia')) {
      return ResponseBody.fromString(
        _hnJson,
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString('not found', 404);
  }

  @override
  void close({bool force = false}) {}
}

const _rssSource = DataSourceConfig(
  id: 'rss1',
  name: '阮一峰的网络日志',
  apiUrl: 'https://www.ruanyifeng.com/blog/atom.xml',
  sourceType: DataSourceType.rss,
);

const _hnSource = DataSourceConfig(
  id: 'hn1',
  name: 'Hacker News',
  apiUrl: 'https://hn.algolia.com/api/v1/search',
  fieldMapping: FieldMapping(
    listPath: 'hits',
    titlePath: 'title',
    thumbPath: 'thumb',
    authorPath: 'author',
    publishTimePath: 'created_at',
    detailUrlPath: 'url',
  ),
);

Future<AppDatabase> _seedDb({
  List<String> keywords = const [],
  bool withHnSource = true,
}) async {
  final db = AppDatabase(executor: NativeDatabase.memory());
  await db.upsertDataSource(_rssSource);
  if (withHnSource) {
    await db.upsertDataSource(_hnSource);
  }
  for (final w in keywords) {
    await db.addBlockedKeyword(w);
  }
  return db;
}

Widget _buildApp(AppDatabase db, Dio dio) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    dioProvider.overrideWithValue(dio),
  ],
  child: const MaterialApp(home: FeedListPage()),
);

void main() {
  testWidgets('聚合模式：RSS 源与 JSON 源混合渲染（全链路）', (tester) async {
    SharedPreferences.setMockInitialValues({'aggregate_mode': true});
    final db = await _seedDb();
    addTearDown(db.close);
    final dio = Dio()..httpClientAdapter = _FakeAdapter();

    await tester.pumpWidget(_buildApp(db, dio));
    // 不能用 pumpAndSettle：列表底部"加载更多"指示器会无限旋转永不静止，
    // 改为有限次 pump 等待异步加载完成后的重建
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 两种类型的数据源条目都渲染出来了
    expect(find.text('科技爱好者周刊（第 100 期）'), findsOneWidget);
    expect(find.text('My AI story'), findsOneWidget);
  });

  testWidgets('屏蔽词过滤作用于 RSS 条目', (tester) async {
    SharedPreferences.setMockInitialValues({'aggregate_mode': true});
    final db = await _seedDb(keywords: ['周刊']);
    final dio = Dio()..httpClientAdapter = _FakeAdapter();

    await tester.pumpWidget(_buildApp(db, dio));
    // 不能用 pumpAndSettle：列表底部"加载更多"指示器会无限旋转永不静止，
    // 改为有限次 pump 等待异步加载完成后的重建
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('科技爱好者周刊（第 100 期）'), findsNothing);
    expect(find.text('My AI story'), findsOneWidget);
  });

  testWidgets('分源 Tab 模式：RSS 源有独立 Tab', (tester) async {
    SharedPreferences.setMockInitialValues({}); // 默认 aggregateMode = false
    final db = await _seedDb();
    addTearDown(db.close);
    final dio = Dio()..httpClientAdapter = _FakeAdapter();

    await tester.pumpWidget(_buildApp(db, dio));
    // 不能用 pumpAndSettle：列表底部"加载更多"指示器会无限旋转永不静止，
    // 改为有限次 pump 等待异步加载完成后的重建
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // TabBarView 惰性构建：点击"阮一峰的网络日志"标签激活 RSS 源的 Tab
    await tester.tap(find.text('阮一峰的网络日志'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('科技爱好者周刊（第 100 期）'), findsOneWidget);
  });

  testWidgets('RSS 全量源不参与加载更多：底部直接显示"没有更多了"，不再发请求', (tester) async {
    SharedPreferences.setMockInitialValues({'aggregate_mode': true});
    final db = await _seedDb(withHnSource: false);
    addTearDown(db.close);
    final adapter = _FakeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;

    await tester.pumpWidget(_buildApp(db, dio));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 滚到底部：footer 是"没有更多了"，而不是"加载更多"转圈
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('— 没有更多了 —'), findsOneWidget);

    // 直接调 loadMore（状态机层）：RSS 无分页语义，不应发出任何网络请求
    final context = tester.element(find.byType(FeedListPage));
    final container = ProviderScope.containerOf(context);
    await container.read(feedAggregateProvider.notifier).loadMore();
    await tester.pumpAndSettle();
    expect(adapter.callCount, 1);
  });
}
