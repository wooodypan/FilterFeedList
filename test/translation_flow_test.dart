import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filter_flow/core/db/app_database.dart';
import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/models/field_mapping.dart';
import 'package:filter_flow/models/translation_mode.dart';
import 'package:filter_flow/services/feed_repository.dart';
import 'package:filter_flow/services/translator_service.dart';
import 'package:filter_flow/ui/settings/data_source_edit_page.dart';

/// 翻译链路的端到端测试（内存数据库 + 假 HTTP 适配器，不联网）。
///
/// 覆盖三件事：
/// 1. 数据源配置里的两个"是否翻译"开关能不能正确存取、老标记能不能自动迁移；
/// 2. 翻译模式（原文替换 / 双语共存）拼出来的文字对不对；
/// 3. 仓库层是不是"一页只发一次翻译请求"、失败时会不会退化成原文。

/// 假的数据源接口：固定返回两条英文文章。
class _FakeFeedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'list': [
            {
              'title': 'Hello World',
              'thumb': 'http://img/1.jpg',
              'summary': 'First post',
              'url': 'http://site/a',
            },
            {
              'title': 'Second Post',
              'thumb': 'http://img/2.jpg',
              'summary': 'Another one',
              'url': 'http://site/b',
            },
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 假的翻译接口：把每条待翻译文本变成 "译_<原文>"，并记录请求体方便断言。
class _FakeTranslateAdapter implements HttpClientAdapter {
  /// 一共发了几次翻译请求（用来断言"标题+摘要只发一次"）
  int requestCount = 0;

  /// 最后一次请求里带的文本数组
  List<dynamic> lastPayload = const [];

  /// 置为 true 时模拟接口挂掉（返回 500），用于验证"翻译失败回退原文"
  bool fail = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestCount++;
    if (fail) return ResponseBody.fromString('boom', 500);
    // 请求体结构：[[文本数组, 源语言, 目标语言], "te_lib"]
    final decoded = jsonDecode(options.data as String) as List<dynamic>;
    lastPayload = (decoded[0] as List)[0] as List<dynamic>;
    return ResponseBody.fromString(
      jsonEncode([lastPayload.map((t) => '译_$t').toList()]),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 组装一份"标题 + 摘要都要翻译"的数据源配置。
DataSourceConfig _config({
  required String titlePath,
  required String summaryPath,
  bool translateTitle = false,
  bool translateSummary = false,
}) {
  return DataSourceConfig(
    id: 's1',
    name: '测试源',
    apiUrl: 'http://api/list',
    fieldMapping: FieldMapping(
      listPath: 'data.list',
      titlePath: titlePath,
      thumbPath: 'thumb',
      summaryPath: summaryPath,
      translateTitle: translateTitle,
      translateSummary: translateSummary,
    ),
  );
}

void main() {
  group('TranslationMode.combine', () {
    test('原文替换：字段里只剩译文', () {
      expect(TranslationMode.replace.combine('Hello', '你好'), '你好');
    });

    test('双语共存：原文在上、译文在下，中间一个换行符', () {
      expect(TranslationMode.bilingual.combine('Hello', '你好'), 'Hello\n你好');
    });

    test('译文为空（翻译失败）→ 保持原文', () {
      expect(TranslationMode.replace.combine('Hello', ''), 'Hello');
      expect(TranslationMode.bilingual.combine('Hello', ''), 'Hello');
    });

    test('译文和原文一样（本来就是中文）→ 不重复显示', () {
      expect(TranslationMode.bilingual.combine('你好', '你好'), '你好');
      expect(TranslationMode.replace.combine('你好', ' 你好 '), '你好');
    });
  });

  group('FieldMapping 翻译开关默认值', () {
    test('老配置里没有开关字段 → 两个开关都默认关闭', () {
      final m = FieldMapping.fromJson({
        'listPath': 'data.list',
        'titlePath': 'title',
        'thumbPath': 'thumb',
        'summaryPath': 'summary',
      });

      expect(m.summaryPath, 'summary');
      expect(m.translateTitle, isFalse);
      expect(m.translateSummary, isFalse);
    });
  });

  group('FeedRepository 翻译', () {
    late AppDatabase db;
    late _FakeTranslateAdapter translateAdapter;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      translateAdapter = _FakeTranslateAdapter();
    });

    tearDown(() async {
      await db.close();
    });

    /// 造一个仓库：数据源请求和翻译请求各走一个假适配器。
    FeedRepository repoWith(TranslationMode mode) {
      final feedDio = Dio()..httpClientAdapter = _FakeFeedAdapter();
      final translateDio = Dio()..httpClientAdapter = translateAdapter;
      return FeedRepository(
        feedDio,
        db,
        TranslatorService(translateDio),
        translationMode: () => mode,
      );
    }

    test('双语共存：标题和摘要各自"原文在上、译文在下"', () async {
      final articles = await repoWith(TranslationMode.bilingual).fetchFeed(
        _config(
          titlePath: 'title',
          summaryPath: 'summary',
          translateTitle: true,
          translateSummary: true,
        ),
      );

      expect(articles, hasLength(2));
      expect(articles[0].title, 'Hello World\n译_Hello World');
      expect(articles[0].summary, 'First post\n译_First post');
      expect(articles[1].title, 'Second Post\n译_Second Post');
      expect(articles[1].summary, 'Another one\n译_Another one');
    });

    test('原文替换：标题和摘要都直接变成译文', () async {
      final articles = await repoWith(TranslationMode.replace).fetchFeed(
        _config(
          titlePath: 'title',
          summaryPath: 'summary',
          translateTitle: true,
          translateSummary: true,
        ),
      );

      expect(articles[0].title, '译_Hello World');
      expect(articles[0].summary, '译_First post');
    });

    test('标题和摘要只发一次翻译请求（拼成一个批量）', () async {
      await repoWith(TranslationMode.bilingual).fetchFeed(
        _config(
          titlePath: 'title',
          summaryPath: 'summary',
          translateTitle: true,
          translateSummary: true,
        ),
      );

      expect(translateAdapter.requestCount, 1);
      // 2 条标题 + 2 条摘要 = 4 段文本
      expect(translateAdapter.lastPayload, hasLength(4));
    });

    test('summaryPath=title + 摘要翻译开关：把标题译文放进摘要，标题本身不动', () async {
      final articles = await repoWith(TranslationMode.bilingual).fetchFeed(
        _config(
          titlePath: 'title',
          summaryPath: 'title',
          translateSummary: true,
        ),
      );

      // 标题原样保留（因为它的开关是关的）
      expect(articles[0].title, 'Hello World');
      // 摘要里是"标题原文 + 标题译文"
      expect(articles[0].summary, 'Hello World\n译_Hello World');
    });

    test('summaryPath=title + 原文替换：摘要里只剩标题的译文', () async {
      final articles = await repoWith(TranslationMode.replace).fetchFeed(
        _config(
          titlePath: 'title',
          summaryPath: 'title',
          translateSummary: true,
        ),
      );

      expect(articles[0].title, 'Hello World');
      expect(articles[0].summary, '译_Hello World');
    });

    test('两个开关都关着时，完全不碰翻译接口', () async {
      final articles = await repoWith(
        TranslationMode.bilingual,
      ).fetchFeed(_config(titlePath: 'title', summaryPath: 'summary'));

      expect(translateAdapter.requestCount, 0);
      expect(articles[0].title, 'Hello World');
      expect(articles[0].summary, 'First post');
    });

    test('翻译接口挂了 → 原样显示原文，不抛异常', () async {
      translateAdapter.fail = true;

      final articles = await repoWith(TranslationMode.bilingual).fetchFeed(
        _config(
          titlePath: 'title',
          summaryPath: 'summary',
          translateTitle: true,
          translateSummary: true,
        ),
      );

      expect(articles, hasLength(2));
      expect(articles[0].title, 'Hello World');
      expect(articles[0].summary, 'First post');
    });
  });

  group('数据源编辑页的"翻译"开关', () {
    /// 页面上第 0 个开关是标题的、第 1 个是摘要的
    /// （再往后还有一个"使用 AppDeepLink 直达 App"的开关，不算在字段翻译里）。
    List<Switch> fieldSwitches(WidgetTester tester) =>
        tester.widgetList<Switch>(find.byType(Switch)).take(2).toList();

    testWidgets('两个字段旁边各有一个开关，默认都是关的', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DataSourceEditPage())),
      );
      await tester.pump();

      final switches = fieldSwitches(tester);
      expect(switches, hasLength(2));
      expect(switches[0].value, isFalse); // 标题
      expect(switches[1].value, isFalse); // 摘要
      expect(find.text('翻译'), findsNWidgets(2));
    });

    testWidgets('编辑已有配置时，开关按存下来的值回显', (tester) async {
      final initial = DataSourceConfig(
        id: 's1',
        name: '测试源',
        apiUrl: 'http://api/list',
        fieldMapping: const FieldMapping(
          listPath: 'data.list',
          titlePath: 'title',
          thumbPath: 'thumb',
          summaryPath: 'summary',
          translateTitle: true, // 只开了标题
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: DataSourceEditPage(initial: initial)),
        ),
      );
      await tester.pump();

      final switches = fieldSwitches(tester);
      expect(switches[0].value, isTrue);
      expect(switches[1].value, isFalse);
    });

    testWidgets('点一下开关能切换状态', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DataSourceEditPage())),
      );
      await tester.pump();

      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      final switches = fieldSwitches(tester);
      expect(switches[0].value, isTrue); // 标题开关被打开了
      expect(switches[1].value, isFalse); // 摘要开关不受影响
    });
  });
}
