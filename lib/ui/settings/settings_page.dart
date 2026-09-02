import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/feed_settings_provider.dart';

/// 设置主页：入口聚合 + 全局开关。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(feedSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('数据源管理'),
            subtitle: const Text('管理 API 数据源与已安装插件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/sources'),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('屏蔽词管理'),
            subtitle: const Text('标题或摘要包含这些词的内容不展示'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/blocked'),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('字体设置'),
            subtitle: const Text('调整全局字号并实时预览'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/font'),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份与恢复'),
            subtitle: const Text('导出 / 导入全部配置（含订阅源与屏蔽词）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/backup'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.merge_type),
            title: const Text('聚合模式'),
            subtitle: const Text('开启后把所有启用的源混成一条信息流'),
            value: settings.aggregateMode,
            onChanged: (v) =>
                ref.read(feedSettingsProvider.notifier).setAggregateMode(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image),
            title: const Text('显示缩略图'),
            subtitle: const Text('关闭可节省流量'),
            value: settings.showThumb,
            onChanged: (v) =>
                ref.read(feedSettingsProvider.notifier).setShowThumb(v),
          ),
        ],
      ),
    );
  }
}
