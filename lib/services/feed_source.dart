import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import 'feed_repository.dart';
import 'rss_feed_repository.dart';

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

  /// 该源是否支持按页加载（true 时才参与 FeedNotifier 的"加载更多"）。
  ///
  /// JSON API 用 {page} 占位符翻页、JS 插件在 ctx 里拿 page，都是分页源；
  /// RSS/Atom 一次请求就返回全部条目，没有"下一页"概念，返回 false ——
  /// FeedNotifier 据此跳过它的加载更多，避免重复请求同一份全量数据。
  bool get supportsPagination;

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
  bool get supportsPagination => true;

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

/// RSS/Atom 订阅数据源（第三种接入方式，零配置）。
///
/// 用户只要给一个 feed 地址就能订阅；实现同 [JsonPathFeedSource] 一样薄——
/// 把请求转交给 [RssFeedRepository]（它内部做 dio 拉取 → XML 解析 → 屏蔽词过滤）。
class RssFeedSource implements FeedSource {
  final DataSourceConfig config;
  final RssFeedRepository repo;

  RssFeedSource({required this.config, required this.repo});

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  bool get enabled => config.enabled;

  // RSS 条目天然有链接，详情页默认走 WebView 加载原文；
  // 全文输出的 feed（如 Atom content）也可以在编辑页切成原生渲染。
  @override
  DetailRenderMode get detailMode => config.detailMode;

  @override
  String? get detailUrlTemplate => config.detailUrlTemplate;

  @override
  bool get supportsPagination => false;

  // page/pageSize 是接口要求的形参，RSS 没有分页语义，直接忽略：
  // 每次调用都拉取并返回 feed 的全部条目（只在首次加载/下拉刷新时发生）。
  @override
  Future<List<FeedArticle>> fetchFeed({required int page, int pageSize = 20}) =>
      repo.fetchFeed(config);

  /// 同 [JsonPathFeedSource]：基于 config 做相等判断。
  /// 注意必须实现——feedTabProvider 用 FeedSource 实例当 family key，
  /// 漏了 == 会导致任意数据源增删改后所有 Tab 全量重拉。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RssFeedSource && other.config == config;

  @override
  int get hashCode => config.hashCode;
}
