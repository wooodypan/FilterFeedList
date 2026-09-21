import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/db/app_database.dart';
import '../core/error/feed_parse_exception.dart';
import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import '../models/field_mapping.dart';
import '../models/translation_mode.dart';
import 'generic_feed_parser.dart';
import 'keyword_filter_engine.dart';
import 'translator_service.dart';

/// 信息流仓库：把"请求 -> 解析 -> 过滤 -> 翻译"四步串起来，对外只给干净的文章列表。
///
/// 这是 UI 层唯一需要打交道的数据入口（Repository 模式），
/// UI 不需要知道 dio、JSONPath、屏蔽词、翻译这些细节。
class FeedRepository {
  final Dio _dio;
  final AppDatabase _db;
  final TranslatorService _translator;

  /// 读取"当前翻译模式"（原文替换 / 双语共存）的回调。
  ///
  /// 做成回调而不是直接传一个值，是因为翻译模式存在全局设置里、而且用户随时会改：
  /// 每次真正抓取时现读一次，才能拿到最新值，同时又不会让这个仓库对象被重建
  /// （重建会导致所有数据源被重新拉取一遍，见 core_providers.dart 的说明）。
  final TranslationMode Function() _readTranslationMode;

  FeedRepository(
    this._dio,
    this._db,
    this._translator, {
    required TranslationMode Function() translationMode,
  }) : _readTranslationMode = translationMode;

  /// 拉取某个数据源某一页的信息流，并完成屏蔽词过滤。
  ///
  /// [page] 从 1 开始。URL 里的 {page} / {pageSize} 占位符会被自动替换。
  Future<List<FeedArticle>> fetchFeed(
    DataSourceConfig config, {
    int page = 1,
    int pageSize = 20,
  }) async {
    // 1) 拼 URL：替换分页占位符
    final url = config.apiUrl
        .replaceAll('{page}', page.toString())
        .replaceAll('{pageSize}', pageSize.toString());

    // 2) 发请求（GET/POST 由 config 决定）
    late final Response response;
    try {
      response = await _dio.request(
        url,
        options: Options(method: config.method),
        queryParameters: config.queryParams,
        // 对 POST 等情况，headers 也带上
        data: config.method.toUpperCase() == 'POST' ? config.queryParams : null,
      );
    } on DioException catch (e) {
      // 网络层面的错（超时/断网/404）单独抛出，UI 能区分文案
      throw FeedFetchException('网络请求失败：${e.message}', cause: e);
    }

    // 3) 响应体统一转成 Map（dio 有时已经解析过，有时是字符串）
    final dynamic raw = response.data;
    final Map<String, dynamic> json;
    if (raw is Map<String, dynamic>) {
      json = raw;
    } else if (raw is Map) {
      json = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } else {
      throw FeedParseException('响应体不是 JSON 对象，实际类型：${raw?.runtimeType}');
    }

    // 4) 通用解析
    List<FeedArticle> parsed;
    try {
      parsed = GenericFeedParser.parse(json, config);
    } on FeedParseException {
      // 字段映射错误原样往上抛，UI 提示"该数据源配置有误"
      rethrow;
    }

    // 5) 从数据库读"仍然生效"的屏蔽词，过滤后再返回
    //    （只取未过期的词，过期的会自动失效；过滤放在 Repository 而非 UI，
    //    保证分页/去重逻辑都绕不过过滤）
    final keywords = await _db.getActiveBlockedKeywords();
    var articles = KeywordFilterEngine(keywords).filter(parsed);

    // 6) 翻译：数据源的字段映射里给"标题""摘要"打开了"翻译"开关时，把对应内容翻成中文。
    //    开关本身只决定"翻不翻"，译文是替换原文还是原文+译文一起显示，由全局
    //    "翻译模式"（TranslationMode）决定。
    //    先过滤再翻译，避免把马上要被屏蔽掉的内容也送去翻译，白花一次请求。
    final mapping = config.fieldMapping;
    if (mapping != null &&
        (mapping.translateTitle || mapping.translateSummary) &&
        articles.isNotEmpty) {
      articles = await _translateArticles(articles, mapping);
    }

    return articles;
  }

  /// 按数据源的翻译开关，批量翻译标题 / 摘要。
  ///
  /// 为什么要"一次请求翻两批"：标题和摘要是两批文本，而翻译接口本来就支持一次传多个，
  /// 所以把它们拼成一个大数组发一次请求，拿到结果再按下标拆回去——
  /// 这样每页文章只花一次翻译请求，而不是标题一次、摘要一次。
  ///
  /// 翻译失败（接口报错 / 断网 / 返回条数对不上）时【原样返回】，
  /// 界面上继续显示原文，不会因为翻译服务挂了就整页报错。
  Future<List<FeedArticle>> _translateArticles(
    List<FeedArticle> articles,
    FieldMapping mapping,
  ) async {
    final mode = _readTranslationMode();
    final count = articles.length;

    // 先取出两批原文（摘要为空时用空串，保证下标能一一对上）
    final titles = articles.map((a) => a.title).toList();
    final summaries = articles.map((a) => a.summary ?? '').toList();

    // 只把打开了开关的那批文本拼进去（没打开的字段没必要送去翻译，白费流量）。
    // 布局就是"先标题、后摘要"两段，下面按这个布局算摘要的起始下标。
    final batch = <String>[
      if (mapping.translateTitle) ...titles,
      if (mapping.translateSummary) ...summaries,
    ];

    final translated = await _translator.translate(batch);
    // 长度对不上就当作翻译失败（翻译失败时返回的是空数组），直接放弃这一轮翻译
    if (translated.length != batch.length) return articles;

    // 摘要那批在数组里的起始下标：标题也开了开关时，前面正好隔着一整段标题
    final summaryOffset = mapping.translateTitle ? count : 0;

    return [
      for (var i = 0; i < count; i++)
        articles[i].copyWith(
          // copyWith 收到 null 表示"这个字段不动"，所以没开开关的字段就传 null
          title: mapping.translateTitle
              ? mode.combine(titles[i], translated[i])
              : null,
          summary: mapping.translateSummary
              ? mode.combine(summaries[i], translated[summaryOffset + i])
              : null,
        ),
    ];
  }
}

/// 网络请求失败的异常（和字段解析失败区分开）。
class FeedFetchException implements Exception {
  final String message;
  final Object? cause;

  FeedFetchException(this.message, {this.cause});

  @override
  String toString() => 'FeedFetchException: $message';
}
