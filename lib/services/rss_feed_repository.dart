import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../core/db/app_database.dart';
import '../core/error/feed_parse_exception.dart';
import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import 'feed_repository.dart' show FeedFetchException;
import 'keyword_filter_engine.dart';
import 'rss_feed_parser.dart';

/// RSS/Atom 订阅源仓库：拉取 feed -> XML 解析 -> 屏蔽词过滤。
///
/// 与 [FeedRepository]（JSONPath 源）平级，由 [RssFeedSource] 调用。
///
/// 分页说明：RSS 协议本身没有分页语义，一次请求就拿到全部条目。
/// 为了兼容 FeedNotifier "逐页 fetchFeed" 的游标模型，这里在内存里
/// 按 configId 缓存全量条目：page 1 时真正发请求并刷新缓存，
/// page > 1 时直接对缓存做 skip/take 切片（不发网络请求）。
///
/// 已知限制：
/// - dio 对响应体按 UTF-8 解码，GBK/GB2312 等编码的 feed 会乱码（v1 接受）
class RssFeedRepository {
  final Dio _dio;
  final AppDatabase _db;

  /// configId -> 该 feed 的全量条目（上限 [_maxCacheSize] 条，防异常大 feed 撑爆内存）
  final Map<String, List<FeedArticle>> _cache = {};
  static const int _maxCacheSize = 500;

  RssFeedRepository(this._dio, this._db);

  /// 拉取某个 RSS 源"第 [page] 页"的条目（page 从 1 开始），并完成屏蔽词过滤。
  Future<List<FeedArticle>> fetchFeed(
    DataSourceConfig config, {
    int page = 1,
    int pageSize = 20,
  }) async {
    // page 1（或缓存里还没有这个源，比如首次 loadMore 抢跑）时拉取刷新
    if (page == 1 || !_cache.containsKey(config.id)) {
      _cache[config.id] = await _fetchAll(config);
    }

    final all = _cache[config.id]!;
    final start = (page - 1) * pageSize;
    final slice = start >= all.length
        ? <FeedArticle>[]
        : all.skip(start).take(pageSize).toList();

    // 屏蔽词过滤放在仓库层（对齐 FeedRepository），保证分页/去重都绕不过过滤
    final keywords = await _db.getAllBlockedKeywords();
    return KeywordFilterEngine(keywords).filter(slice);
  }

  /// 真正发一次网络请求，拉取并解析整个 feed。
  Future<List<FeedArticle>> _fetchAll(DataSourceConfig config) async {
    // 用 ResponseType.plain 保证拿到原始字符串（xml 包自己解析），
    // 同时覆盖全局 Accept: application/json —— 部分服务器按 Accept 协商内容
    late final Response<String> response;
    try {
      response = await _dio.get<String>(
        config.apiUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept':
                'application/rss+xml, application/atom+xml, application/xml, */*',
          },
        ),
      );
    } on DioException catch (e) {
      throw FeedFetchException('网络请求失败：${e.message}', cause: e);
    }

    final body = response.data;
    if (body == null || body.isEmpty) {
      throw FeedParseException('RSS 响应体为空');
    }

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } on XmlParserException catch (e) {
      throw FeedParseException('不是合法的 XML 文档：${e.message}');
    }

    try {
      final articles = RssFeedParser.parse(doc, sourceId: config.id);
      return articles.length > _maxCacheSize
          ? articles.sublist(0, _maxCacheSize)
          : articles;
    } on FeedParseException {
      rethrow;
    } catch (e) {
      throw FeedParseException('RSS 解析失败：$e');
    }
  }
}
