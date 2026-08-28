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
/// RSS 协议没有分页语义，一次请求就返回 feed 的全部条目，
/// 所以这里不做任何分页处理，每次调用全量返回；
/// 调用方（FeedNotifier）通过 FeedSource.supportsPagination=false
/// 保证只在首次加载/下拉刷新时调用，不会重复请求。
///
/// 已知限制：
/// - dio 对响应体按 UTF-8 解码，GBK/GB2312 等编码的 feed 会乱码（v1 接受）
class RssFeedRepository {
  final Dio _dio;
  final AppDatabase _db;

  RssFeedRepository(this._dio, this._db);

  /// 拉取某个 RSS 源的全部条目，并完成屏蔽词过滤。
  Future<List<FeedArticle>> fetchFeed(DataSourceConfig config) async {
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
      // 屏蔽词过滤放在仓库层（对齐 FeedRepository），保证去重/展示都绕不过过滤
      final keywords = await _db.getAllBlockedKeywords();
      return KeywordFilterEngine(keywords).filter(articles);
    } on FeedParseException {
      rethrow;
    } catch (e) {
      throw FeedParseException('RSS 解析失败：$e');
    }
  }
}
