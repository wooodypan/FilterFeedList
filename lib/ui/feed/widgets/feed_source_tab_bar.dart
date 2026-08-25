import 'package:flutter/material.dart';

import '../../../services/feed_source.dart';

/// 数据源 Tab 栏：每个启用的数据源对应一个标签。
///
/// 源多时可横向滚动（isScrollable）。放在 DefaultTabController 下使用。
/// 注意：参数是统一的 [FeedSource] 抽象（JSONPath 配置源 / JS 插件源都能用）。
class FeedSourceTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<FeedSource> sources;

  const FeedSourceTabBar({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: sources.map((s) => Tab(text: s.name)).toList(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
