import 'package:flutter/material.dart';
// 只为了拿 ScrollCacheExtent（缓存范围那个新类型，material 没有转出来）
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/feed_settings_provider.dart';
import '../../../services/feed_source.dart';

/// Tab 切换振动的「闸门」：保证一次切换只振一次。
///
/// 两条振动路径共用这个开关：
/// - 点击路径：Tab 栏 onTap 里振完立刻关闸（consumed = true），
///   之后 controller.index 变化时就不会再振；
/// - 拖动路径：手指按下开始拖时开闸（consumed = false），
///   之后页码真的变了（index 变化）才振一次并关闸。
/// 放成 static 是因为它描述的是"当前这一次切换手势"的状态，
/// 两个文件（Tab 栏 / 列表页）都要读写同一份。
class TabSwitchHapticGate {
  TabSwitchHapticGate._();

  /// true = 本次切换的振动已处理（或没有待处理的振动）
  static bool consumed = true;
}

/// 数据源 Tab 栏：每个启用的数据源对应一个标签。
///
/// 源多时可横向滚动，并且**长按标签可以左右拖动排序**（改完会写回数据库）。
/// 它不再是无状态的 TabBar，而是自己管理 [TabController]，
/// 这样才能在拖动排序后把"选中的那一项"跟住原来的数据源。
///
/// 注意：参数是统一的 [FeedSource] 抽象（JSONPath 配置源 / RSS 订阅源 / JS
/// 插件源都能用）。
class FeedSourceTabBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final List<FeedSource> sources;
  final TabController controller;

  /// 用户拖动某个标签到新位置时的回调（oldIndex / newIndex）。
  ///
  /// newIndex 已经由 SliverReorderableList 修正过（"移除旧项"后的下标），
  /// 调用方直接 removeAt + insert 即可得到新顺序。
  final void Function(int oldIndex, int newIndex) onReorder;

  const FeedSourceTabBar({
    super.key,
    required this.sources,
    required this.controller,
    required this.onReorder,
  });

  @override
  ConsumerState<FeedSourceTabBar> createState() => _FeedSourceTabBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);
}

class _FeedSourceTabBarState extends ConsumerState<FeedSourceTabBar> {
  /// Tab 栏自己的滚动控制器。
  ///
  /// 为什么不用 [Scrollable.ensureVisible] 省事：它会沿祖先链把所有能滚的容器一起滚一遍。这里只需要动 Tab 栏这一条，自己拿控制器最不容易误伤。
  final ScrollController _scrollController = ScrollController();

  /// 每个 Tab 一把 [GlobalKey]，用来拿到"选中那一项"的渲染对象。
  ///
  /// 为什么不自己算偏移量：Tab 宽度取决于文字长度，而且选中项字重更粗（w600 和 normal 的宽度不一样），手算很容易算歪。让框架按真实布局反推才准。
  ///
  /// 用 source.id 而不是下标做索引：拖动排序后下标会变，用 id 才能跟住同一个源。
  final Map<String, GlobalKey> _tabKeys = <String, GlobalKey>{};

  /// 上一次已经居中好的下标。同一个下标不重复触发，避免来回滚。
  int? _centeredIndex;

  /// 目标 Tab 还没搭出来时的重试次数（见 [_tryCenter]）
  int _centerRetry = 0;

  @override
  void initState() {
    super.initState();
    // Tab 选中态变化（点击切换 / 拖动后重映射索引）时需要重绘下划线
    widget.controller.addListener(_onTick);
    // 首帧也居中一次：否则启动时如果恢复的是靠后的 Tab，它还在屏幕外看不见
    _requestCenter();
  }

  @override
  void didUpdateWidget(covariant FeedSourceTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
      // 换了控制器，之前的"已居中下标"作废，重新对一次
      _centeredIndex = null;
      _requestCenter();
    }
    // 数据源被删掉后顺手把它的 GlobalKey 丢掉，别让这个 Map 一直堆积
    final aliveIds = widget.sources.map((s) => s.id).toSet();
    _tabKeys.removeWhere((id, _) => !aliveIds.contains(id));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    _tabKeys.clear();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    // index 变化才需要重绘（拖动动画期间 offset 也会变，一并刷新更顺滑）
    setState(() {});
    // 选中的项换了 → 把它滚到正中间
    if (widget.controller.index != _centeredIndex) _requestCenter();
  }

  /// 请求"把当前选中的 Tab 滚到正中间"。
  ///
  /// 统一等帧末再执行，原因有两个：滚动动画不能在 build / layout 过程中启动；
  /// 而且首帧调用时 Tab 可能还没搭出来（拿不到渲染对象）。
  void _requestCenter() {
    _centerRetry = 0;
    _scheduleTryCenter();
  }

  /// 下一帧渲染完之后再试一次居中。
  void _scheduleTryCenter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryCenter();
    });
  }

  /// 真正干活的：找到选中项的真实位置，算出让它居中该滚多少。
  void _tryCenter() {
    final index = widget.controller.index;
    // 下标越界（数据源刚被删、列表还没刷新）→ 直接放弃，别崩
    if (index < 0 || index >= widget.sources.length) return;

    final renderObject = _tabKeys[widget.sources[index].id]?.currentContext
        ?.findRenderObject();
    if (renderObject == null || !_scrollController.hasClients) {
      // 还没搭出来 / 滚动视图还没挂上（首帧）→ 下一帧再试。
      // 试几次还不行就放弃，免得每帧都排一个回调在那儿空转。
      if (_centerRetry++ >= 5) return;
      _scheduleTryCenter();
      return;
    }

    // 记下来，避免同一项反复触发滚动动画
    _centeredIndex = index;

    final position = _scrollController.position;
    // 只滚自己这一条：
    // - 0.5 = 让这个 Tab 的中点落在视口正中；
    // - 偏移量由框架按真实布局算，并自动夹在"能滚的范围"内，所以最左/最右那几个 Tab 居中不了时就停在极限位置，不会滚出空白；
    // - 已经在中间时它内部会直接返回，不会白跑一趟动画。
    // 注意这里刻意不用 Scrollable.ensureVisible：那个会沿祖先链把上层能滚的容器也一起滚一遍，容易误伤页面本身。
    position.ensureVisible(
      renderObject,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTextTabBarHeight,
      child: CustomScrollView(
        controller: _scrollController,
        // 横向滚动：Tab 多了可以左右滑；拖动到边缘时列表会自动跟着滚
        scrollDirection: Axis.horizontal,
        // 让所有 Tab 都提前搭出来。列表默认是懒加载的：视口外的 Tab 没有渲染对象，那么"把屏幕外那个选中的 Tab 滚到中间"就无从下手（拿不到它的位置）。
        // 10 万逻辑像素足够装下几百个 Tab，而 Tab 数量 = 数据源数量，开销可以忽略；
        // 顺带让长按拖动排序时的间隙计算覆盖到所有项。
        scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
        slivers: [
          SliverReorderableList(
            itemCount: widget.sources.length,
            onReorderItem: widget.onReorder,
            itemBuilder: (context, index) => _buildTab(context, index),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final source = widget.sources[index];
    final selected = index == widget.controller.index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 用 ReorderableDelayedDragStartListener（长按触发）而不是
    // ReorderableDragStartListener（按下即触发）：
    // 后者会把"点击切换 Tab"的手势也吃掉，导致点不动。
    return ReorderableDelayedDragStartListener(
      // key 必须给：重排时框架靠它识别每个子项，否则顺序会错乱。
      // 这里刻意不把定位用的 GlobalKey 挂在这一层，免得干扰重排识别。
      key: ValueKey(source.id),
      index: index,
      // 每个 Tab 自带一个透明的 Material：
      // 拖动时被拖项会被搬到 Overlay（浮层）里渲染，而浮层上方没有 Scaffold
      // 提供的 Material——InkWell 找不到它就会抛 "No Material widget found"。
      // 自带 Material 后，无论在原列表里还是在浮层里，水波纹都有地方画。
      // 用透明色是为了不改变外观。
      child: Material(
        // 这把 GlobalKey 专门用来量这个 Tab 的真实位置（居中用），挂在 Material 上而不是外层，是为了不掺和上面那个重排用的 key。
        key: _tabKeys.putIfAbsent(source.id, () => GlobalKey()),
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 点击路径：立即振动，然后关闸——防止 index 变化时列表页那边再振一次
            final settings = ref.read(feedSettingsProvider);
            if (settings.hapticFeedback) {
              HapticFeedback.selectionClick();
            }
            TabSwitchHapticGate.consumed = true;
            // 先记下"点的是不是已经选中的那个"，因为 animateTo 会立刻改掉 index
            final alreadySelected = widget.controller.index == index;
            widget.controller.animateTo(index);
            // 点的是当前已选中的 Tab 时，控制器不会发通知（下标没变）→ 手动补一次居中，这样"把 Tab 栏滑远了、再点回当前项"也能把它拉回中间
            if (alreadySelected) _requestCenter();
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: selected ? 2 : 0,
                  color: selected ? colorScheme.primary : Colors.transparent,
                ),
              ),
            ),
            child: Text(
              source.name,
              // Material 会套一层默认文字样式，这里显式基于正文样式再改颜色，
              // 保证 Tab 文字大小不受所处位置影响
              style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                color: selected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
