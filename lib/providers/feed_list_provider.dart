import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/data_source_config.dart';
import '../models/feed_article.dart';
import '../services/feed_repository.dart';
import 'core_providers.dart';
import 'data_source_provider.dart';

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

/// 单个数据源的 Tab 信息流（按 sourceId 区分实例）。
/// key 用 DataSourceConfig 本身：配置被改了 -> 对象变了 -> 自动重建并重新拉取。
final feedTabProvider =
    StateNotifierProvider.family<FeedNotifier, FeedState, DataSourceConfig>(
  (ref, config) =>
      FeedNotifier(ref.watch(feedRepositoryProvider), [config]),
);

/// 聚合模式的信息流：合并所有启用数据源。
/// 非 family 的普通 provider，依赖 dataSourcesProvider，
/// 数据源增删改后会自动重建并重新拉取。
final feedAggregateProvider = StateNotifierProvider<FeedNotifier, FeedState>(
  (ref) {
    final repo = ref.watch(feedRepositoryProvider);
    final sources = ref.watch(dataSourcesProvider).valueOrNull ?? [];
    return FeedNotifier(repo, sources.where((s) => s.enabled).toList());
  },
);

/// 信息流状态机：负责"首次加载 / 上拉加载更多 / 多源合并去重"。
class FeedNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repo;
  final List<DataSourceConfig> _sources;
  final Map<String, int> _pages = {}; // 每个源当前加载到第几页

  FeedNotifier(this._repo, this._sources) : super(const FeedState()) {
    for (final s in _sources) {
      _pages[s.id] = 1;
    }
    // 有源才自动加载；没源（比如聚合模式但全部关闭）就保持空
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
        final list = await _repo.fetchFeed(s, page: 1);
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
        final list = await _repo.fetchFeed(s, page: p);
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
