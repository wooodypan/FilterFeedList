import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/db/app_database.dart';
import '../core/error/feed_parse_exception.dart';
import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import 'generic_feed_parser.dart';
import 'keyword_filter_engine.dart';
import 'translator_service.dart';

/// 信息流仓库：把"请求 -> 解析 -> 过滤"三步串起来，对外只给干净的文章列表。
///
/// 这是 UI 层唯一需要打交道的数据入口（Repository 模式），
/// UI 不需要知道 dio、JSONPath、屏蔽词这些细节。
class FeedRepository {
  final Dio _dio;
  final AppDatabase _db;
  final TranslatorService _translator;

  FeedRepository(this._dio, this._db, this._translator);

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

    // 6) 翻译：仅当 summaryPath 是翻译标记（如 title.tttttranslate）时触发。
    //    规则：标记里的字段名是要"翻译的源"（如 title），译文写回 summaryPath 对应的
    //    summary 字段——标题保留原文，第二行摘要显示译文。
    //    先过滤再做翻译，避免把要被屏蔽的标题也送去翻译，省一次请求。
    final marker = TranslatorService.parseMarker(
      config.fieldMapping?.summaryPath,
    );
    if (marker != null && articles.isNotEmpty) {
      articles = await _translateField(
        articles,
        sourceField: marker.field,
        targetField: 'summary',
        from: marker.from,
        to: marker.to,
      );
    }

    return articles;
  }

  /// 批量翻译：把 sourceField 的原文翻译后写回 targetField。
  ///
  /// 收集 sourceField 原文 → 交给 [TranslatorService] 一次性翻完 → 按原顺序写回 targetField。
  /// 例如 summaryPath=title.tttttranslate 时：sourceField=title、targetField=summary，
  /// 即"标题保留原文，摘要显示译文"。
  Future<List<FeedArticle>> _translateField(
    List<FeedArticle> articles, {
    required String sourceField,
    required String targetField,
    required String from,
    required String to,
  }) async {
    final originals = articles.map((a) => _readField(a, sourceField)).toList();
    final translated = await _translator.translate(
      originals,
      from: from,
      to: to,
    );
    return [
      for (var i = 0; i < articles.length; i++)
        _writeField(articles[i], targetField, translated[i]),
    ];
  }

  /// 从文章里读出要翻译的字段（标记里写的 field 对应到 FeedArticle 的属性）。
  static String _readField(FeedArticle a, String field) {
    switch (field) {
      case 'title':
        return a.title;
      case 'summary':
        return a.summary ?? '';
      case 'author':
        return a.author ?? '';
      default:
        return '';
    }
  }

  /// 把译文写回文章的对应字段（返回新对象，不改原对象）。
  static FeedArticle _writeField(FeedArticle a, String field, String value) {
    switch (field) {
      case 'title':
        return a.copyWith(title: value);
      case 'summary':
        return a.copyWith(summary: value);
      case 'author':
        return a.copyWith(author: value);
      default:
        return a;
    }
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
