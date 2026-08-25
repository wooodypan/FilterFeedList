import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import 'feed_repository.dart';

/// 信息流数据源的统一抽象。
///
/// 这是 task2 方案里"两套体系并存"的核心：无论是原来的 JSONPath 声明式配置，
/// 还是新增的 JS 插件，对外都表现为同一个 [FeedSource]——
/// UI 层（信息流列表、Tab 切换）完全不用关心底层是哪种实现，
/// 只要 `fetchFeed` 能给出干净的 [FeedArticle] 列表就行。
///
/// 这样后续再加第三种数据源（比如 RSS、本地文件）也只需多实现一个 [FeedSource]。
abstract class FeedSource {
  /// 唯一 id（去重 / Tab key）
  String get id;

  /// 展示名称
  String get name;

  /// 是否启用
  bool get enabled;

  /// 详情页渲染方式（webview / native）
  DetailRenderMode get detailMode;

  /// 详情页 URL 拼接模板（webview 模式且需要二次拼接时用）
  String? get detailUrlTemplate;

  /// 拉取某一页信息流（page 从 1 开始）
  Future<List<FeedArticle>> fetchFeed({required int page, int pageSize = 20});
}

/// 原来的 JSONPath 声明式数据源（零代码接入，普通用户友好）。
///
/// 实现很简单：把请求转交给既有的 [FeedRepository]（它内部做
/// URL 占位符替换 → dio 请求 → 通用解析 → 屏蔽词过滤）。
class JsonPathFeedSource implements FeedSource {
  final DataSourceConfig config;
  final FeedRepository repo;

  JsonPathFeedSource({required this.config, required this.repo});

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  bool get enabled => config.enabled;

  @override
  DetailRenderMode get detailMode => config.detailMode;

  @override
  String? get detailUrlTemplate => config.detailUrlTemplate;

  @override
  Future<List<FeedArticle>> fetchFeed({required int page, int pageSize = 20}) =>
      repo.fetchFeed(config, page: page, pageSize: pageSize);

  /// 用 config 的内容做相等判断：配置被改（哪怕 id 不变）就会判为不相等，
  /// 这样信息流 Tab / 缓存能据此判断"需要重建拉取逻辑"。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonPathFeedSource && other.config == config;

  @override
  int get hashCode => config.hashCode;
}
