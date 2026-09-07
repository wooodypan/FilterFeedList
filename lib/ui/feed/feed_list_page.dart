import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      // 不写死背景色，交给主题的 scaffoldBackgroundColor：
      // 这样切到深色模式时整页会自动变深（写死 Colors.white 会是一片白）。
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

  /// 上一次选中的 Tab 下标：用来检测「页码真的变了」。
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.sources.length, vsync: this);
    // 监听控制器：页码一变（拖动翻页落定 / 点击切换）就回调 _onControllerTick
    _tabController!.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(covariant _TabbedFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.sources;
    final next = widget.sources;

    if (old.length != next.length) {
      // 数据源数量变了（新增 / 删除 / 启停）：旧索引已失效，重建控制器回到第一个
      _tabController?.removeListener(_onControllerTick);
      _tabController?.dispose();
      _tabController = TabController(length: next.length, vsync: this);
      _tabController!.addListener(_onControllerTick);
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
    _tabController?.removeListener(_onControllerTick);
    _tabController?.dispose();
    super.dispose();
  }

  /// TabController 回调：页码真的变了才振一次（振动跟随"翻页结果"）。
  ///
  /// 为什么用结果而不是过程判定：TabBarView 翻页的触发条件是
  /// 「位移过半 或 甩动速度够快」（PageScrollPhysics 内部逻辑），
  /// 自己用位移猜会漏掉"快速轻扫"这种小位移高速翻页的情况。
  /// 监听 index 变化则无论用户怎么滑，页码变了就是切了源，跟着振，
  /// 和 Flutter 内部判定天然一致。
  void _onControllerTick() {
    final c = _tabController;
    if (c == null) return;

    final current = c.index;
    final last = _lastIndex;
    _lastIndex = current;
    // 页码没变（拖动中途未过界、点击当前 Tab 等）→ 不振
    if (last == null || current == last) return;

    // 闸门关着 = 点击路径已经在 onTap 里振过了 → 跳过，防止双震。
    // 拖动路径：手指按下开始拖时闸门已开（见 _onTabScrollNotification），
    // 这里振一次并关闸；快速轻扫、慢拖过半、直接甩出去全都覆盖。
    if (TabSwitchHapticGate.consumed) return;
    TabSwitchHapticGate.consumed = true;

    final settings = ref.read(feedSettingsProvider);
    if (settings.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  /// TabBarView 的滚动通知：只做一件事——手指开始拖动时开闸，
  /// 允许随后的「页码变化」触发一次振动（点击路径的补间动画没有
  /// dragDetails，不会开闸，所以点完 Tab 不会再震）。
  bool _onTabScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      TabSwitchHapticGate.consumed = false;
    }
    return false;
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
          // NotificationListener 只负责一件事：手指开始拖动 TabBarView 时
          // 打开振动闸门（见 _onTabScrollNotification 的注释）
          child: NotificationListener<ScrollNotification>(
            onNotification: _onTabScrollNotification,
            child: TabBarView(
              controller: controller,
              // 给每个子页按源 id 加 key：顺序变化后 Flutter 才能把状态跟对源，
              // 否则"第 2 页"可能错误地复用"第 3 页"的滚动位置等状态
              children: widget.sources
                  .map(
                    (s) =>
                        _SingleSourceFeedView(key: ValueKey(s.id), source: s),
                  )
                  .toList(),
            ),
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

  /// 是否显示「回到顶部」按钮：滑过一定距离后出现，接近顶部时消失。
  bool _showBackToTop = false;

  /// 滚动超过这个距离（逻辑像素）就显示「回到顶部」按钮
  static const double _backToTopThreshold = 800;

  @override
  void initState() {
    super.initState();
    // 滚动到底部附近时自动加载更多
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    // 滑得够远就亮出「回到顶部」按钮；状态没变就不 setState，避免每帧重建
    final far = _scroll.position.pixels > _backToTopThreshold;
    if (far != _showBackToTop) {
      setState(() => _showBackToTop = far);
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  /// 平滑滚回顶部（300ms 动画，比直接跳上去体验好）
  void _backToTop() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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

    // 悬浮按钮的配色取自主题：底色用 surfaceContainerHighest（浅色≈浅灰、
    // 深色≈深灰），描边用 outlineVariant。写死白底+浅灰边在深色模式下会很突兀。
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          // 用 separated 而不是 builder：可以在每两行之间插入一条 0.5px 的分割线，
          // 这是"无卡片、纯白扁平列表"样式的关键（分割线不属于任何一行）。
          child: ListView.separated(
            controller: _scroll,
            itemCount: state.articles.length + 1, // 多一个底部"加载更多"条目
            // 行之间的 0.5px 分割线：高度 0.5 逻辑像素，在高清屏上就是一条细线
            separatorBuilder: (context, index) => Container(
              height: 0.5,
              // 用主题的分割线色（浅色模式是淡灰、深色模式是淡白），
              // 两个模式下都能看得出分界，又不会太抢眼。
              // 之前这里写死了纯白 —— 白底上等于没有分割线，深色底上则变成刺眼的亮线。
              color: Theme.of(context).dividerColor,
            ),
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
                // 长按标题以外的区域：弹出「使用默认浏览器打开」菜单
                onRequestMenu: (position) => _showItemMenu(article, position),
              );
            },
          ),
        ),

        // 「回到顶部」悬浮按钮：滑过 800px 才出现，淡入淡出过渡。
        // IgnorePointer 在隐藏时把按钮整个"挖空"，避免透明状态下还能误点。
        Positioned(
          right: 16,
          bottom: 24,
          child: AnimatedOpacity(
            opacity: _showBackToTop ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showBackToTop,
              child: Material(
                // 底色 + 描边都取自主题，跟着深浅模式自动变
                color: scheme.surfaceContainerHighest,
                shape: CircleBorder(
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: '回到顶部',
                  onPressed: _backToTop,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 长按卡片（标题以外的区域）弹出的菜单。
  ///
  /// 目前只有一项：用系统默认浏览器打开原文。
  /// position 传的是手指按下的屏幕坐标，菜单就弹在手指那儿，长列表里也好认。
  Future<void> _showItemMenu(FeedArticle article, Offset position) async {
    // showMenu 的 position 是「相对于 Overlay 的矩形」，所以要拿 Overlay 尺寸当参照系
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'browser',
          child: Row(
            children: [
              Icon(Icons.open_in_browser),
              SizedBox(width: 12),
              Text('使用默认浏览器打开'),
            ],
          ),
        ),
      ],
    );
    // 点了菜单外的地方会返回 null，等于取消
    if (!mounted || choice == null) return;

    if (choice == 'browser') {
      await _openInBrowser(article);
    }
  }

  /// 用系统默认浏览器打开文章原文（跳出本 App）。
  ///
  /// LaunchMode.externalApplication = 交给系统挑一个能处理 http(s) 的 App，
  /// 也就是用户自己设的默认浏览器；不会像 platformDefault 那样在 App 内嵌页面。
  Future<void> _openInBrowser(FeedArticle article) async {
    final url = article.detailUrl;
    if (url == null || url.isEmpty) {
      _showToast('这篇文章没有可用的详情链接');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showToast('链接格式不正确：$url');
      return;
    }

    // 既然要跳出去看原文了，就算「读过了」，跟进入详情页的处理保持一致
    ref.read(readArticlesProvider.notifier).markRead(article.id);

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _showToast('没有找到能打开该链接的应用');
    } catch (e) {
      // 个别机型/系统上唤起外部浏览器会抛异常，提示出来别静默
      _showToast('打开失败：$e');
    }
  }

  /// 底部轻提示（页面已销毁时直接忽略，避免报错）
  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
