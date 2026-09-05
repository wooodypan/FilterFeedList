import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import '../services/feed_source.dart';
import 'models/installed_plugin.dart';
import 'plugin_feed_repository.dart';

/// JS 插件型数据源（复杂 API：需要签名 / 时间戳 / 加密的走这套）。
///
/// 它实现 [FeedSource] 接口，所以 UI 层对它和 JSONPath 数据源一视同仁。
/// 内部把 `fetchFeed` 委托给 [PluginFeedRepository]——
/// 由它去沙箱里跑 buildRequest/parseResponse，并在 Dart 侧完成网络与过滤。
///
/// 详情页渲染方式：插件解析出的文章可能带 `contentHtml`（走原生渲染更顺滑）
/// 也可能只有 `detailUrl`（走 WebView）。这里默认 webview，
/// 详情页会进一步根据文章实际字段智能选择（见 ArticleDetailPage）。
class JsPluginFeedSource implements FeedSource {
  final InstalledPlugin plugin;
  final PluginFeedRepository repo;

  JsPluginFeedSource({required this.plugin, required this.repo});

  @override
  String get id => plugin.id;

  @override
  String get name => plugin.name;

  @override
  bool get enabled => plugin.enabled;

  @override
  DetailRenderMode get detailMode => DetailRenderMode.webview;

  @override
  String? get detailUrlTemplate => null;

  // 深链直达开关透传插件自身设置（默认 true）
  @override
  bool get useAppDeepLink => plugin.useAppDeepLink;

  // 插件存在 installed_plugins 表，和数据源配置不是同一张表
  @override
  FeedSourceStorage get storage => FeedSourceStorage.plugin;

  @override
  bool get supportsPagination => true;

  @override
  Future<List<FeedArticle>> fetchFeed({required int page, int pageSize = 20}) =>
      repo.fetchFeed(plugin, page: page, pageSize: pageSize);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsPluginFeedSource && other.plugin == plugin;

  @override
  int get hashCode => plugin.hashCode;
}
