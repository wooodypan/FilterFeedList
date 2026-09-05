import 'package:flutter/material.dart';

import '../../../services/feed_source.dart';

/// "全部数据源"面板：以网格形式一次性展示所有源，解决 Tab 栏在源数量
/// 多时"滑不全、拖不准"的问题。
///
/// - 点击某一项：直接跳转到该 Tab 并关闭面板（用于快速定位）。
/// - 长按并拖动：调整顺序，实时生效，不需要关闭面板（用于批量整理）。
///
/// 顺序的保存逻辑复用外部传入的 [onReorder]，与 Tab 栏长按拖动走的是
/// 同一条数据路径（sourceSortOrdersProvider），两处排序结果始终一致。
class AllSourcesSheet extends StatefulWidget {
  final List<FeedSource> sources;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  /// 跳转到"数据源管理"界面的回调（由调用方提供，用父级 context 导航，
  /// 这样弹层关闭后管理页能正常压在首页之上）。
  final VoidCallback onManage;

  const AllSourcesSheet({
    super.key,
    required this.sources,
    required this.currentIndex,
    required this.onSelect,
    required this.onReorder,
    required this.onManage,
  });

  /// 便捷调用：以 BottomSheet 形式弹出，占据大部分屏幕高度但可下滑收起。
  static Future<void> show(
    BuildContext context, {
    required List<FeedSource> sources,
    required int currentIndex,
    required ValueChanged<int> onSelect,
    required Future<void> Function(int oldIndex, int newIndex) onReorder,
    required VoidCallback onManage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AllSourcesSheet(
        sources: sources,
        currentIndex: currentIndex,
        onSelect: onSelect,
        onReorder: onReorder,
        onManage: onManage,
      ),
    );
  }

  @override
  State<AllSourcesSheet> createState() => _AllSourcesSheetState();
}

class _AllSourcesSheetState extends State<AllSourcesSheet> {
  // 面板内部维护一份本地副本用于拖动时的即时视觉反馈，
  // 真正的持久化仍然通过 widget.onReorder 交给外部 Provider 完成。
  late List<FeedSource> _localSources;

  @override
  void initState() {
    super.initState();
    _localSources = List.of(widget.sources);
  }

  @override
  void didUpdateWidget(covariant AllSourcesSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部数据源发生变化（比如在设置里增删了插件）时，同步刷新本地副本
    if (!_sameOrder(oldWidget.sources, widget.sources)) {
      _localSources = List.of(widget.sources);
    }
  }

  bool _sameOrder(List<FeedSource> a, List<FeedSource> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text('全部数据源', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Text(
                    '${_localSources.length} 个',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text('管理数据源', style: Theme.of(context).textTheme.bodySmall),
                  // 快捷入口：跳到"数据源管理"界面（增删 / 排序 / 装插件等都在那）。
                  // 先由父级 context 压入管理页路由，再关掉本弹层。
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: '管理数据源',
                    onPressed: () {
                      widget.onManage();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            // 关键修复：原来用 Flexible + GridView(shrinkWrap)，在源数量多时
            // 网格高度会超过屏幕，导致整个 BottomSheet 溢出（RenderFlex overflowed）
            // 且无法滚动。这里改用 ConstrainedBox 把网格高度限制在屏幕 70% 以内，
            // 超出部分由网格自身滚动，弹层不再溢出。
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: _ReorderableSourceGrid(
                sources: _localSources,
                currentIndex: widget.currentIndex,
                onTap: (index) {
                  widget.onSelect(index);
                  Navigator.of(context).pop();
                },
                onReorder: (oldIndex, newIndex) async {
                  setState(() {
                    final moved = _localSources.removeAt(oldIndex);
                    _localSources.insert(newIndex, moved);
                  });
                  await widget.onReorder(oldIndex, newIndex);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 网格形式的可拖拽排序视图。
///
/// 用 [ReorderableBuilder] 风格的手写实现（基于 [Wrap] + [LongPressDraggable] +
/// [DragTarget]），因为 Flutter 内置的 [ReorderableGridView] 并不是 SDK 自带组件，
/// 这样可以不引入额外依赖。
class _ReorderableSourceGrid extends StatelessWidget {
  final List<FeedSource> sources;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  const _ReorderableSourceGrid({
    required this.sources,
    required this.currentIndex,
    required this.onTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        // 名字按钮是扁的（高约 36），不再是"圆形头像+名字"的高格子，
        // 宽高比调大让格子刚好包住按钮
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        final isCurrent = index == currentIndex;

        final chip = _SourceChip(source: source, isCurrent: isCurrent);

        return DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != index,
          onAcceptWithDetails: (details) => onReorder(details.data, index),
          builder: (context, candidateData, rejectedData) {
            final isDropTarget = candidateData.isNotEmpty;
            return LongPressDraggable<int>(
              data: index,
              feedback: Material(
                color: Colors.transparent,
                // 拖拽浮影尺寸跟着按钮形状走（扁按钮）
                child: SizedBox(width: 72, height: 36, child: chip),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: chip),
              child: AnimatedScale(
                scale: isDropTarget ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: GestureDetector(onTap: () => onTap(index), child: chip),
              ),
            );
          },
        );
      },
    );
  }
}

/// 单个源按钮：直接显示源名称，淡灰色描边 + 白底；
/// 当前选中的源用主题色描边 + 浅色底，一眼能看出"你现在在这个 Tab"。
class _SourceChip extends StatelessWidget {
  final FeedSource source;
  final bool isCurrent;

  const _SourceChip({required this.source, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.center,
      // 内边距留一点，避免长名称贴边；超出宽度用省略号截断
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        // 普通项白底；选中项给一层浅色底，配合描边区分
        color: isCurrent ? theme.colorScheme.primaryContainer : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          // 普通项：淡灰色边框；选中项：主题色边框
          color: isCurrent
              ? theme.colorScheme.primary
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Text(
        source.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          // 普通项正文色，选中项主题色，和描边呼应
          color: isCurrent
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
