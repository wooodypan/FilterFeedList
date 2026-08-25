import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/feed_article.dart';
import '../../providers/feed_list_provider.dart';
import '../../providers/feed_settings_provider.dart';
import '../../services/feed_source.dart';
import 'widgets/feed_item_card.dart';
import 'widgets/feed_source_tab_bar.dart';

/// 聚合信息流主页。
///
/// 根据设置切换两种形态：
/// - 聚合模式：所有启用源（JSONPath + JS 插件）混成一条流（feedAggregateProvider）
/// - 分源 Tab 模式：每个源一个 Tab（feedTabProvider）
class FeedListPage extends ConsumerWidget {
  const FeedListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(feedSettingsProvider);
    final sources = ref.watch(allFeedSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('漏斗阅读'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (sources.isEmpty) {
            return const Center(
              child: Text('还没有启用任何数据源，去"设置"添加或安装插件吧'),
            );
          }
          // 按设置选择聚合 / 分 Tab
          return settings.aggregateMode
              ? _AggregateFeedView(sources: sources)
              : _TabbedFeedView(sources: sources);
        },
      ),
    );
  }
}

/// 聚合模式：单一信息流
class _AggregateFeedView extends ConsumerWidget {
  final List<FeedSource> sources;
  const _AggregateFeedView({required this.sources});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedAggregateProvider);
    final showThumb = ref.watch(feedSettingsProvider).showThumb;
    return _FeedListView(
      state: state,
      showThumb: showThumb,
      onRefresh: () => ref.read(feedAggregateProvider.notifier).loadInitial(),
      onLoadMore: () => ref.read(feedAggregateProvider.notifier).loadMore(),
      // 聚合模式下文章可能来自不同源，打开详情时按 sourceId 反查
      sourceConfig: null,
    );
  }
}

/// 分源 Tab 模式：每个源一个 Tab
class _TabbedFeedView extends StatelessWidget {
  final List<FeedSource> sources;
  const _TabbedFeedView({required this.sources});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: sources.length,
      child: Column(
        children: [
          FeedSourceTabBar(sources: sources),
          Expanded(
            child: TabBarView(
              children: sources
                  .map((s) => _SingleSourceFeedView(source: s))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个源 Tab 的内容
class _SingleSourceFeedView extends ConsumerWidget {
  final FeedSource source;
  const _SingleSourceFeedView({required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedTabProvider(source));
    final showThumb = ref.watch(feedSettingsProvider).showThumb;
    return _FeedListView(
      state: state,
      showThumb: showThumb,
      onRefresh: () =>
          ref.read(feedTabProvider(source).notifier).loadInitial(),
      onLoadMore: () => ref.read(feedTabProvider(source).notifier).loadMore(),
      // 单源模式下源已知，直接传给详情页
      sourceConfig: source,
    );
  }
}

/// 通用信息流列表（下拉刷新 + 上拉加载更多 + 错误/空态）。
class _FeedListView extends ConsumerStatefulWidget {
  final FeedState state;
  final bool showThumb;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final FeedSource? sourceConfig; // 已知源就直接用它，否则按 sourceId 反查
  const _FeedListView({
    required this.state,
    required this.showThumb,
    required this.onRefresh,
    required this.onLoadMore,
    this.sourceConfig,
  });

  @override
  ConsumerState<_FeedListView> createState() => _FeedListViewState();
}

class _FeedListViewState extends ConsumerState<_FeedListView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // 滚动到底部附近时自动加载更多
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    // 首屏加载中
    if (state.loading && state.articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // 首屏出错且无数据
    if (state.error != null && state.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('加载失败'),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => widget.onRefresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 列表为空（成功但没数据 / 全被屏蔽词过滤了）
    if (state.articles.isEmpty) {
      return const Center(child: Text('暂无内容（可能都被屏蔽词过滤了）'));
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scroll,
        itemCount: state.articles.length + 1, // 多一个底部"加载更多"条目
        itemBuilder: (context, index) {
          // 最后一条：加载更多指示器
          if (index == state.articles.length) {
            if (!state.hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('— 没有更多了 —')),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final article = state.articles[index];
          return FeedItemCard(
            article: article,
            showThumb: widget.showThumb,
            onTap: () => _openDetail(context, article),
          );
        },
      ),
    );
  }

  /// 打开详情页：优先用已知源，否则按 sourceId 在已加载的数据源里反查。
  /// 这里用的是统一的 [FeedSource]（JSONPath 配置源 / JS 插件源都能传）。
  void _openDetail(BuildContext context, FeedArticle article) {
    FeedSource? source = widget.sourceConfig;
    if (source == null) {
      final sources = ref.read(allFeedSourcesProvider);
      source = sources.where((s) => s.id == article.sourceId).firstOrNull;
    }
    if (source == null) return;
    context.push('/detail', extra: {'article': article, 'source': source});
  }
}
