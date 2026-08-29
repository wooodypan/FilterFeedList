import 'package:flutter/material.dart';

import '../../../services/feed_source.dart';

/// 数据源 Tab 栏：每个启用的数据源对应一个标签。
///
/// 源多时可横向滚动，并且**长按标签可以左右拖动排序**（改完会写回数据库）。
/// 它不再是无状态的 TabBar，而是自己管理 [TabController]，
/// 这样才能在拖动排序后把"选中的那一项"跟住原来的数据源。
///
/// 注意：参数是统一的 [FeedSource] 抽象（JSONPath 配置源 / RSS 订阅源 / JS
/// 插件源都能用）。
class FeedSourceTabBar extends StatefulWidget implements PreferredSizeWidget {
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
  State<FeedSourceTabBar> createState() => _FeedSourceTabBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);
}

class _FeedSourceTabBarState extends State<FeedSourceTabBar> {
  @override
  void initState() {
    super.initState();
    // Tab 选中态变化（点击切换 / 拖动后重映射索引）时需要重绘下划线
    widget.controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant FeedSourceTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    // index 变化才需要重绘（拖动动画期间 offset 也会变，一并刷新更顺滑）
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTextTabBarHeight,
      child: CustomScrollView(
        // 横向滚动：Tab 多了可以左右滑；拖动到边缘时列表会自动跟着滚
        scrollDirection: Axis.horizontal,
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
      // key 必须给：重排时框架靠它识别每个子项，否则顺序会错乱
      key: ValueKey(source.id),
      index: index,
      // 每个 Tab 自带一个透明的 Material：
      // 拖动时被拖项会被搬到 Overlay（浮层）里渲染，而浮层上方没有 Scaffold
      // 提供的 Material——InkWell 找不到它就会抛 "No Material widget found"。
      // 自带 Material 后，无论在原列表里还是在浮层里，水波纹都有地方画。
      // 用透明色是为了不改变外观。
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.controller.animateTo(index),
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
