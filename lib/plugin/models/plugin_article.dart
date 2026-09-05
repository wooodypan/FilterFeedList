import '../../models/feed_article.dart';

/// 插件 `parseResponse(json, ctx)` 里单条文章的映射。
///
/// 插件需要返回统一的文章数组，每条至少要有 id 和 title。
/// 为了不让某个劣质 / 恶意插件返回畸形数据就把整个信息流拖垮，
/// [fromJson] 用 try-catch 包裹，单条解析失败返回 null，由上层跳过。
class PluginArticle {
  final String id;
  final String title;
  final String thumbUrl;
  final String? summary;
  final String? author;
  final String? publishTime;
  final String? contentHtml;
  final String? detailUrl;
  final String? appDeepLink;

  const PluginArticle({
    required this.id,
    required this.title,
    required this.thumbUrl,
    this.summary,
    this.author,
    this.publishTime,
    this.contentHtml,
    this.detailUrl,
    this.appDeepLink,
  });

  /// 把 JS 返回的一条对象安全地转成 PluginArticle。
  /// 失败时返回 null（上层会跳过这条，而不是整体崩溃）。
  static PluginArticle? fromJson(Map<String, dynamic> json, String sourceId) {
    try {
      // id 兜底：优先用插件给的 id，没有就用 title+thumb 的 md5（复用 FeedArticle 的逻辑）
      final rawId = json['id']?.toString();
      final title = (json['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) return null; // 没标题的脏数据直接丢弃

      final thumb = json['thumb']?.toString() ?? '';
      final id = (rawId != null && rawId.isNotEmpty)
          ? rawId
          : FeedArticle.fallbackId(title, thumb);

      return PluginArticle(
        id: id,
        title: title,
        thumbUrl: thumb,
        summary: _opt(json['summary']),
        author: _opt(json['author']),
        publishTime: _opt(json['publishTime']),
        contentHtml: _opt(json['contentHtml'] ?? json['content']),
        detailUrl: _opt(json['detailUrl'] ?? json['url']),
        // 插件可返回 appDeepLink（如 smzdm://youhui/123），点开文章时优先用它拉起 App
        appDeepLink: _opt(json['appDeepLink']),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _opt(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// 转成 app 内部统一的 FeedArticle（带上归属数据源 id）。
  FeedArticle toFeedArticle(String sourceId) => FeedArticle(
    id: id,
    title: title,
    thumbUrl: thumbUrl,
    summary: summary,
    author: author,
    publishTime: publishTime,
    contentHtml: contentHtml,
    detailUrl: detailUrl,
    appDeepLink: appDeepLink,
    sourceId: sourceId,
  );
}
