import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/feed_settings_provider.dart';
import '../../services/image_cache_manager.dart';

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
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('振动反馈'),
            subtitle: const Text('切换顶部数据源标签时轻微振动'),
            value: settings.hapticFeedback,
            onChanged: (v) =>
                ref.read(feedSettingsProvider.notifier).setHapticFeedback(v),
          ),
          // 图片缓存保留天数：列表最下面一行的配置入口
          ListTile(
            leading: const Icon(Icons.image_search),
            title: const Text('图片缓存保留天数'),
            subtitle: Text('当前保留 ${settings.imageCacheDays} 天，超期自动清理（修改后重启生效）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _pickImageCacheDays(context, ref, settings.imageCacheDays),
          ),
        ],
      ),
    );
  }

  /// 弹出底部菜单让用户选择图片缓存保留多少天。
  /// 选中后立刻保存到 SharedPreferences（真正按新天数清理要等下次启动）。
  void _pickImageCacheDays(BuildContext context, WidgetRef ref, int current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '图片缓存保留天数',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            // 遍历可选天数，当前选中项打勾
            for (final days in FeedImageCacheManager.kImageCacheDayOptions)
              ListTile(
                title: Text('$days 天'),
                trailing: days == current ? const Icon(Icons.check) : null,
                onTap: () {
                  ref
                      .read(feedSettingsProvider.notifier)
                      .setImageCacheDays(days);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
