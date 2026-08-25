/// 一条信息流文章（运行时 DTO，不入库）。
///
/// 由 [GenericFeedParser] 根据 DataSourceConfig 从 JSON 解析而来。
/// 注意它不是 freezed 模型——它只是解析后的"用完即走"的数据对象。
class FeedArticle {
  /// 唯一 id（来自 uniqueIdPath，或 title+thumb 的 md5 兜底）
  final String id;

  /// 标题
  final String title;

  /// 缩略图 URL（可能为空，UI 用占位图兜底）
  final String thumbUrl;

  /// 摘要（可能为空）
  final String? summary;

  /// 作者（可能为空）
  final String? author;

  /// 发布时间（可能为空，原始字符串）
  final String? publishTime;

  /// 原生渲染时的正文 HTML（WebView 模式下为 null）
  final String? contentHtml;

  /// WebView 模式下的详情链接（原生模式下为 null）
  final String? detailUrl;

  /// 归属哪个数据源（数据源 id）
  final String sourceId;

  const FeedArticle({
    required this.id,
    required this.title,
    required this.thumbUrl,
    this.summary,
    this.author,
    this.publishTime,
    this.contentHtml,
    this.detailUrl,
    required this.sourceId,
  });

  /// 方便打印调试
  @override
  String toString() =>
      'FeedArticle(id: $id, title: $title, sourceId: $sourceId)';

  /// 用 id 判断两条是否相同（多数据源聚合去重时用）
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedArticle && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
