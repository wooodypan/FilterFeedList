import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/feed_article.dart';
import '../../providers/feed_list_provider.dart';
import '../../providers/feed_settings_provider.dart';
import '../../providers/read_articles_provider.dart';
import '../../services/feed_source.dart';
import 'widgets/all_sources_sheet.dart';
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
    // Tab 顺序只在"分源 Tab 模式"下有意义，所以在这里按需排序，
    // 避免影响聚合模式的信息流（原因见 allFeedSourcesProvider 的注释）
    final tabOrders = ref.watch(sourceSortOrdersProvider);

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
            return const Center(child: Text('还没有启用任何数据源，去"设置"添加或安装插件吧'));
          }
          // 按设置选择聚合 / 分 Tab（Tab 模式才需要按用户排好的顺序显示）
          return settings.aggregateMode
              ? _AggregateFeedView(sources: sources)
              : _TabbedFeedView(
                  sources: sortSourcesByTabOrder(sources, tabOrders),
                );
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

/// 分源 Tab 模式：每个源一个 Tab（长按标签可左右拖动排序）。
///
/// 自己持有 [TabController] 而不用 DefaultTabController，是为了在
/// "数据源数量变化"时重建控制器、在"拖动排序"时把选中项跟住原来的数据源。
class _TabbedFeedView extends ConsumerStatefulWidget {
  final List<FeedSource> sources;
  const _TabbedFeedView({required this.sources});

  @override
  ConsumerState<_TabbedFeedView> createState() => _TabbedFeedViewState();
}

class _TabbedFeedViewState extends ConsumerState<_TabbedFeedView>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.sources.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _TabbedFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.sources;
    final next = widget.sources;

    if (old.length != next.length) {
      // 数据源数量变了（新增 / 删除 / 启停）：旧索引已失效，重建控制器回到第一个
      _tabController?.dispose();
      _tabController = TabController(length: next.length, vsync: this);
      return;
    }
    if (old.isEmpty) return;

    // 数量没变但顺序变了（用户拖动了 Tab）：
    // 让"当前正在看的那个源"继续被选中，而不是停在原索引上看到别的源
    if (!_isSameOrder(old, next)) {
      final currentId = old[_tabController!.index].id;
      final newIndex = next.indexWhere((s) => s.id == currentId);
      if (newIndex >= 0 && newIndex != _tabController!.index) {
        _tabController!.animateTo(newIndex);
      }
    }
  }

  /// 按 id 比较两个列表的顺序是否完全一致
  bool _isSameOrder(List<FeedSource> a, List<FeedSource> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _tabController!;
    return Column(
      children: [
        Row(
          children: [
            // Tab 栏本身还是左右滑动 + 长按拖动，用于日常"临时微调"；
            // 数量一多难以滑到目标位置的问题交给右侧的"全部"入口解决。
            Expanded(
              child: FeedSourceTabBar(
                sources: widget.sources,
                controller: controller,
                onReorder: _onReorder,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: '全部数据源',
              onPressed: () => _showAllSources(context, controller),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            // 给每个子页按源 id 加 key：顺序变化后 Flutter 才能把状态跟对源，
            // 否则"第 2 页"可能错误地复用"第 3 页"的滚动位置等状态
            children: widget.sources
                .map(
                  (s) => _SingleSourceFeedView(key: ValueKey(s.id), source: s),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  /// 弹出"全部数据源"面板：一次性看全所有源，点击可直接跳转到对应 Tab，
  /// 长按拖动可批量整理顺序（与 Tab 栏共用同一套排序数据）。
  void _showAllSources(BuildContext context, TabController controller) {
    AllSourcesSheet.show(
      context,
      sources: widget.sources,
      currentIndex: controller.index,
      onSelect: (index) => controller.animateTo(index),
      onReorder: _onReorder,
      onManage: () => context.push('/settings/sources'),
    );
  }

  /// 拖动排序：算出新顺序后交给 Provider 保存。
  ///
  /// Provider 会先更新内存里的序号映射（Tab 立刻按新顺序重排），
  /// 再把新序号写回 SQLite，下次启动顺序保持一致。
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final ordered = List<FeedSource>.of(widget.sources);
    // SliverReorderableList 给的 newIndex 已按"移除旧项"修正过，直接插入即可
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    await ref.read(sourceSortOrdersProvider.notifier).saveOrder(ordered);
  }
}

/// 单个源 Tab 的内容
class _SingleSourceFeedView extends ConsumerWidget {
  final FeedSource source;
  const _SingleSourceFeedView({super.key, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedTabProvider(source));
    final showThumb = ref.watch(feedSettingsProvider).showThumb;
    return _FeedListView(
      state: state,
      showThumb: showThumb,
      onRefresh: () => ref.read(feedTabProvider(source).notifier).loadInitial(),
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
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
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
    // 已读集合：用来给点开过的卡片标题染灰。这里 watch 一下，
    // 标记已读后这个列表会自动刷新（但此时详情页盖在上面，返回后才看到灰色）。
    final readIds = ref.watch(readArticlesProvider);

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
            // 看一眼这篇有没有被标记成已读，决定标题要不要变灰
            isRead: readIds.contains(article.id),
            onTap: () => _openDetail(context, article),
          );
        },
      ),
    );
  }

  /// 打开详情页：优先用已知源，否则按 sourceId 在已加载的数据源里反查。
  /// 这里用的是统一的 [FeedSource]（JSONPath 配置源 / JS 插件源都能传）。
  Future<void> _openDetail(BuildContext context, FeedArticle article) async {
    FeedSource? source = widget.sourceConfig;
    if (source == null) {
      final sources = ref.read(allFeedSourcesProvider);
      source = sources.where((s) => s.id == article.sourceId).firstOrNull;
    }
    if (source == null) return;
    // 进入详情即视为"已读"：先把这篇文章 id 记进已读集合，
    // 这样返回列表时它的标题已经变成灰色（区分未读）。
    ref.read(readArticlesProvider.notifier).markRead(article.id);

    // 尝试"App 深链直达"：开关开启 + 文章带深链（如 smzdm://youhui/123）。
    // 成功拉起第三方 App 就直接返回（用户已离开本 App，无需再开 WebView）；
    // 拉起失败（没装对应 App 等）则落到下面的 WebView 兜底。
    final deepLink = article.appDeepLink;
    if (source.useAppDeepLink && deepLink != null && deepLink.isNotEmpty) {
      try {
        final launched = await launchUrl(
          Uri.parse(deepLink),
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {
        // 唤起失败（例如该深链协议本机没有 App 能处理），无视异常走 WebView
      }
    }

    // 兜底：用详情链接打开 WebView 详情页
    if (context.mounted) {
      context.push('/detail', extra: {'article': article, 'source': source});
    }
  }
}
