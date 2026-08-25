import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 把所有"启用中"的数据源汇总成统一的 [FeedSource] 列表：
/// - JSONPath 声明式配置 → [JsonPathFeedSource]
/// - 已安装的 JS 插件 → [JsPluginFeedSource]
///
/// UI 和 FeedNotifier 只认 [FeedSource]，从而两套体系无缝并存。
final allFeedSourcesProvider = Provider<List<FeedSource>>((ref) {
  final configs = ref.watch(dataSourcesProvider).valueOrNull ?? [];
  final plugins = ref.watch(installedPluginsProvider).valueOrNull ?? [];
  final repo = ref.watch(feedRepositoryProvider);
  final pluginRepo = ref.watch(pluginFeedRepositoryProvider);

  return [
    ...configs
        .where((c) => c.enabled)
        .map((c) => JsonPathFeedSource(config: c, repo: repo)),
    ...plugins
        .where((p) => p.enabled)
        .map((p) => JsPluginFeedSource(plugin: p, repo: pluginRepo)),
  ];
});

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
        _pages[s.id] = 2; // 下一页从 2 开始
        all.addAll(list);
      }
      state = state.copyWith(
        loading: false,
        articles: all,
        // 没有任何源返回数据，认为没有更多
        hasMore: _sources.isNotEmpty && all.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// 上拉加载更多
  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final more = <FeedArticle>[];
      for (final s in _sources) {
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
