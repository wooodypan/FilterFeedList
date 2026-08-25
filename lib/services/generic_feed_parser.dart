import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/error/feed_parse_exception.dart';
import '../core/network/json_path_resolver.dart';
import '../models/data_source_config.dart';
import '../models/feed_article.dart';

/// 通用信息流解析器。
///
/// 输入：API 返回的 JSON + 一份 DataSourceConfig（字段映射规则）
/// 输出：`List<FeedArticle>` 文章列表
///
/// 关键点：这里【不认识任何具体 API】，完全靠 config 里的路径规则工作，
/// 所以新增数据源不需要改这一层代码。
class GenericFeedParser {
  /// 把响应 JSON 解析成文章列表。
  ///
  /// 容错约定（见 task.md 3.3）：
  /// 1. listPath 取不到数组 -> 抛 FeedParseException（明确报错，不静默返回空）
  /// 2. 单条 title 为空的脏数据 -> 直接过滤掉，避免空白卡片
  /// 3. 缩略图可能是字符串，也可能是数组取第一项 -> 自动兼容
  static List<FeedArticle> parse(
    Map<String, dynamic> responseJson,
    DataSourceConfig config,
  ) {
    final mapping = config.fieldMapping;

    // 1) 先按 listPath 定位数组
    final listRaw = JsonPathResolver.resolve(responseJson, mapping.listPath);
    if (listRaw is! List) {
      throw FeedParseException(
        'listPath "${mapping.listPath}" 未定位到数组，'
        '实际取到的类型是 ${listRaw?.runtimeType ?? 'null'}',
      );
    }

    // 2) 遍历数组每一行，套用相对路径规则
    final articles = listRaw.map<FeedArticle?>((item) {
      // 数组里每行应该是个 Map；不是 Map 的脏数据跳过
      if (item is! Map) return null;

      final title = JsonPathResolver.resolveAsString(item, mapping.titlePath);
      // title 为空 -> 丢弃这条脏数据
      if (title.isEmpty) return null;

      final thumb = _resolveThumb(item, mapping.thumbPath);

      // id 优先取 uniqueIdPath，否则用 title+thumb 兜底算 md5
      final id = mapping.uniqueIdPath != null
          ? JsonPathResolver.resolveAsString(item, mapping.uniqueIdPath)
          : _fallbackId(title, thumb);

      return FeedArticle(
        id: id,
        title: title,
        thumbUrl: thumb,
        summary: JsonPathResolver.resolveAsString(item, mapping.summaryPath),
        author: JsonPathResolver.resolveAsString(item, mapping.authorPath),
        publishTime:
            JsonPathResolver.resolveAsString(item, mapping.publishTimePath),
        // 只有原生渲染模式才关心正文 HTML
        contentHtml: mapping.contentPath != null
            ? JsonPathResolver.resolveAsString(item, mapping.contentPath)
            : null,
        detailUrl: mapping.detailUrlPath != null
            ? JsonPathResolver.resolveAsString(item, mapping.detailUrlPath)
            : null,
        sourceId: config.id,
      );
    }).whereType<FeedArticle>().toList();

    return articles;
  }

  /// 解析缩略图：兼容"字符串"和"数组取第一项"两种形态。
  static String _resolveThumb(dynamic item, String path) {
    final v = JsonPathResolver.resolve(item, path);
    if (v is String) return v;
    if (v is List && v.isNotEmpty) return v.first.toString();
    return '';
  }

  /// 兜底 id：用 title + thumb 算 md5，保证同一条内容 id 稳定（去重/已读用）。
  static String _fallbackId(String title, String thumb) {
    final bytes = utf8.encode('$title|$thumb');
    return md5.convert(bytes).toString();
  }
}
