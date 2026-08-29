import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import '../plugin/plugin_feed_source.dart';
import '../services/feed_source.dart';
import 'core_providers.dart';
import 'data_source_provider.dart';
import 'plugin_provider.dart';

/// 信息流页的状态数据。
class FeedState {
  final bool loading; // 首次加载中
  final bool loadingMore; // 加载更多中
  final List<FeedArticle> articles; // 当前已加载的文章
  final String? error; // 错误信息（有则展示在页面上）
  final bool hasMore; // 是否还有下一页

  const FeedState({
    this.loading = false,
    this.loadingMore = false,
    this.articles = const [],
    this.error,
    this.hasMore = true,
  });

  FeedState copyWith({
    bool? loading,
    bool? loadingMore,
    List<FeedArticle>? articles,
    String? error,
    bool? hasMore,
    bool clearError = false,
  }) {
    return FeedState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      articles: articles ?? this.articles,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 顶部 Tab 的排序序号：sourceId -> 序号（越小越靠前）。
///
/// 为什么要单独存一份映射，而不是把序号塞进 DataSourceConfig？
/// 因为 JsonPathFeedSource / RssFeedSource 的相等判断基于 config，
/// config 一变，feedTabProvider(source) 这个 family 的 key 就变了，
/// 会导致所有 Tab 的信息流被重新拉取。排序只是"显示顺序"，不该触发重拉。
final sourceSortOrdersProvider =
    StateNotifierProvider<SourceSortOrderNotifier, Map<String, int>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final notifier = SourceSortOrderNotifier(db);
      // 数据源 / 插件有增删改时重新读取：新增的源要从库里拿到它的默认序号
      ref.listen(dataSourcesProvider, (_, __) => notifier.refresh());
      ref.listen(installedPluginsProvider, (_, __) => notifier.refresh());
      return notifier;
    });

/// 管理"顶部 Tab 顺序"的状态机：从 SQLite 读、拖动后写回。
class SourceSortOrderNotifier extends StateNotifier<Map<String, int>> {
  final AppDatabase _db;

  SourceSortOrderNotifier(this._db) : super(const {}) {
    refresh();
  }

  /// 从数据库重新读取序号映射
  Future<void> refresh() async {
    final orders = await _db.getAllSortOrders();
    // provider 可能已经被销毁（比如热重载），写 state 前先判断是否还活着
    if (mounted) state = orders;
  }

  /// 保存用户拖动后的新顺序：先更新内存（Tab 立刻重排），再写回数据库。
  ///
  /// 数据源和插件存在不同的表里，所以按 [FeedSource.storage] 分成两批写入。
  /// 写库失败也不会让界面回到旧顺序——最坏情况是下次启动沿用旧顺序。
  Future<void> saveOrder(List<FeedSource> ordered) async {
    final configOrders = <String, int>{};
    final pluginOrders = <String, int>{};

    // 用"在列表中的下标"当序号：0、1、2... 天然就是最终顺序
    for (var i = 0; i < ordered.length; i++) {
      final source = ordered[i];
      switch (source.storage) {
        case FeedSourceStorage.dataSource:
          configOrders[source.id] = i;
        case FeedSourceStorage.plugin:
          pluginOrders[source.id] = i;
      }
    }

    state = {...configOrders, ...pluginOrders};

    await _db.updateDataSourceSortOrders(configOrders);
    await _db.updatePluginSortOrders(pluginOrders);
  }
}

/// 把所有"启用中"的数据源汇总成统一的 [FeedSource] 列表：
/// - JSONPath 声明式配置 → [JsonPathFeedSource]
/// - RSS/Atom 订阅配置 → [RssFeedSource]
/// - 已安装的 JS 插件 → [JsPluginFeedSource]
///
/// UI 和 FeedNotifier 只认 [FeedSource]，从而三套体系无缝并存。
///
/// 注意：这里**故意不按 Tab 顺序排序**。因为 feedAggregateProvider 依赖本
/// provider，一旦这里吐出的值变化（哪怕只是顺序变了），聚合信息流就会被
/// 重建并重新拉取一遍。Tab 顺序只是"显示顺序"，交给 UI 层按需排序即可
/// （见 [sortSourcesByTabOrder]），聚合模式压根用不到它。
final allFeedSourcesProvider = Provider<List<FeedSource>>((ref) {
  final configs = ref.watch(dataSourcesProvider).valueOrNull ?? [];
  final plugins = ref.watch(installedPluginsProvider).valueOrNull ?? [];
  final repo = ref.watch(feedRepositoryProvider);
  final rssRepo = ref.watch(rssFeedRepositoryProvider);
  final pluginRepo = ref.watch(pluginFeedRepositoryProvider);

  return [
    // 同一张表里的配置按 sourceType 分流到各自的实现
    ...configs
        .where((c) => c.enabled && c.sourceType == DataSourceType.json)
        .map((c) => JsonPathFeedSource(config: c, repo: repo)),
    ...configs
        .where((c) => c.enabled && c.sourceType == DataSourceType.rss)
        .map((c) => RssFeedSource(config: c, repo: rssRepo)),
    ...plugins
        .where((p) => p.enabled)
        .map((p) => JsPluginFeedSource(plugin: p, repo: pluginRepo)),
  ];
});

/// 把数据源列表按用户拖动过的 Tab 顺序排序（供信息流页的 Tab 模式使用）。
///
/// 两个细节：
/// - 序号查不到的源（比如刚新增、还没写入映射）排到最后，而不是默认 0 挤到最前；
/// - Dart 的 [List.sort] 不保证稳定性，所以显式用"合并时的原始下标"做次要
///   排序键，保证序号相同的 Tab（老数据默认都是 0）不会随机跳动。
List<FeedSource> sortSourcesByTabOrder(
  List<FeedSource> sources,
  Map<String, int> orders,
) {
  const unknownOrder = 1 << 30;
  final indexed = sources.indexed.toList()
    ..sort((a, b) {
      final orderA = orders[a.$2.id] ?? unknownOrder;
      final orderB = orders[b.$2.id] ?? unknownOrder;
      final byOrder = orderA.compareTo(orderB);
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
    });
  return indexed.map((e) => e.$2).toList();
}

/// 单个数据源的 Tab 信息流（按 FeedSource 区分实例）。
/// key 用 FeedSource 本身：底层配置/脚本被改了 -> 对象变了 -> 自动重建并重新拉取。
final feedTabProvider =
    StateNotifierProvider.family<FeedNotifier, FeedState, FeedSource>(
      (ref, source) => FeedNotifier([source]),
    );

/// 聚合模式的信息流：合并所有启用的数据源（JSONPath + JS 插件）。
/// 非 family 的普通 provider，依赖 allFeedSourcesProvider，
/// 任意数据源增删改 / 插件安装卸载后都会自动重建并重新拉取。
final feedAggregateProvider = StateNotifierProvider<FeedNotifier, FeedState>(
  (ref) => FeedNotifier(ref.watch(allFeedSourcesProvider)),
);

/// 信息流状态机：负责"首次加载 / 上拉加载更多 / 多源合并去重"。
class FeedNotifier extends StateNotifier<FeedState> {
  final List<FeedSource> _sources;
  final Map<String, int> _pages = {}; // 每个源当前加载到第几页

  FeedNotifier(this._sources) : super(const FeedState()) {
    for (final s in _sources) {
      _pages[s.id] = 1;
    }
    // 有源才自动加载；没源（比如全关了）就保持空
    if (_sources.isNotEmpty) {
      loadInitial();
    }
  }

  /// 首次加载（第 1 页）
  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final all = <FeedArticle>[];
      for (final s in _sources) {
        final list = await s.fetchFeed(page: 1);
        _pages[s.id] = 2; // 下一页从 2 开始（仅对分页源有意义）
        all.addAll(list);
      }
      state = state.copyWith(
        loading: false,
        articles: all,
        // 只有存在分页源时才可能有"下一页"（RSS 等全量源不参与加载更多）
        hasMore: _sources.any((s) => s.supportsPagination) && all.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// 上拉加载更多（只对分页源生效；RSS 等全量源在第 1 页已拿全，直接跳过）
  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    final paginatedSources = _sources
        .where((s) => s.supportsPagination)
        .toList();
    if (paginatedSources.isEmpty) {
      state = state.copyWith(hasMore: false);
      return;
    }
    state = state.copyWith(loadingMore: true);
    try {
      final more = <FeedArticle>[];
      for (final s in paginatedSources) {
        final p = _pages[s.id] ?? 1;
        final list = await s.fetchFeed(page: p);
        _pages[s.id] = p + 1;
        more.addAll(list);
      }
      // 按 id 去重（多源可能抓到同一篇）
      final merged = {...state.articles, ...more}.toList();
      state = state.copyWith(
        loadingMore: false,
        articles: merged,
        hasMore: more.isNotEmpty, // 这一批空了，说明到底了
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }
}
