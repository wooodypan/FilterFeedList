import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/db/app_database.dart';
import '../core/error/feed_parse_exception.dart';
import '../models/feed_article.dart';
import '../services/keyword_filter_engine.dart';
import 'js_runtime/js_engine_pool.dart';
import 'models/installed_plugin.dart';
import 'models/plugin_article.dart';
import 'models/plugin_request.dart';

/// 插件信息流仓库：把"跑 JS 算请求 → Dart 发网络请求 → 跑 JS 解析 → 屏蔽词过滤"串起来。
///
/// 核心安全模型（务必理解）：
/// - JS 沙箱**只做纯数据变换**（buildRequest 算出请求描述、parseResponse 算出文章数组），
///   它**没有网络能力**；
/// - 真正的 dio 网络请求在 Dart 层发起，响应再回传给沙箱解析。
/// 这样恶意插件最多只能"算出"请求参数，却无法在 JS 里偷偷把用户数据发到别的服务器。
class PluginFeedRepository {
  final JsEnginePool _pool;
  final Dio _dio;
  final AppDatabase _db;

  PluginFeedRepository(this._pool, this._dio, this._db);

  /// 拉取某个插件某一页的信息流，并完成屏蔽词过滤。
  ///
  /// [page] 从 1 开始；[pageSize] 默认 20，会作为 ctx 传给插件的 buildRequest。
  Future<List<FeedArticle>> fetchFeed(
    InstalledPlugin plugin, {
    int page = 1,
    int pageSize = 20,
  }) async {
    // ---- 阶段 1：在沙箱里执行 buildRequest，拿到"请求描述" ----
    final ctx = {
      'page': page,
      'pageSize': pageSize,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final reqRaw = await _pool.callFunction(
      script: plugin.scriptContent,
      functionName: 'buildRequest',
      args: [ctx],
    );
    if (reqRaw is! Map<String, dynamic>) {
      throw const FeedParseException('buildRequest 返回值不是对象');
    }
    final req = PluginRequest.fromJson(reqRaw);

    // ---- 阶段 2：Dart 层真正发起网络请求（沙箱无网络能力，这一步必须在 Dart 侧）----
    late final Response response;
    try {
      response = await _dio.request(
        req.url,
        options: Options(method: req.method, headers: req.headers),
        queryParameters: req.params,
        data: req.body,
      );
    } on DioException catch (e) {
      throw FeedFetchException('插件网络请求失败：${e.message}', cause: e);
    }

    // ---- 阶段 3：把响应 JSON 回传沙箱，执行 parseResponse，拿到文章数组 ----
    final data = _decode(response.data);
    final articlesRaw = await _pool.callFunction(
      script: plugin.scriptContent,
      functionName: 'parseResponse',
      args: [
        {'data': data},
        ctx,
      ],
    );
    if (articlesRaw is! List) {
      throw const FeedParseException('parseResponse 返回值不是数组');
    }

    // 单条解析失败（畸形数据）直接跳过，不让整个信息流崩掉
    final articles =
        articlesRaw
            .whereType<Map<String, dynamic>>()
            .map((e) => PluginArticle.fromJson(e, plugin.id))
            .whereType<PluginArticle>()
            .map((a) => a.toFeedArticle(plugin.id))
            .toList();

    // ---- 阶段 4：屏蔽词过滤（和 JSONPath 数据源走同一套逻辑，保证一致）----
    final keywords = await _db.getAllBlockedKeywords();
    return KeywordFilterEngine(keywords).filter(articles);
  }

  /// 把 dio 的响应体统一成 Dart 对象（Map / List / 基础类型）。
  /// 顺序：已经是 Map/List 就直接用；是字符串就 jsonDecode；否则抛错。
  dynamic _decode(dynamic raw) {
    if (raw is Map || raw is List) return raw;
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        // 后期可能支持RSS订阅的xml，不是合法 JSON的字符串也返回
        return raw;
        // throw FeedParseException('插件响应体不是合法 JSON：${raw.runtimeType}');
      }
    }
    throw FeedParseException('插件响应体类型无法处理：${raw?.runtimeType}');
  }
}

/// 插件网络请求失败的异常（和 FeedFetchException 命名一致便于上层统一处理）。
class FeedFetchException implements Exception {
  final String message;
  final Object? cause;
  FeedFetchException(this.message, {this.cause});
  @override
  String toString() => 'FeedFetchException: $message';
}
