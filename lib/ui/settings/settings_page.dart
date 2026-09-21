import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/translation_mode.dart';
import '../../providers/feed_list_provider.dart';
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
            leading: const Icon(Icons.palette),
            title: const Text('主题色'),
            subtitle: const Text('选择主色调，也支持自定义取色'),
            // 右侧先放一个当前主题色的小圆点，让用户一眼看到现在用的颜色
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: settings.themeColor,
                    shape: BoxShape.circle,
                    // 描边用主题的 outlineVariant：深色模式下也能看出圆点边界
                    // （写死 Colors.black12 在深底上等于没有描边）
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/settings/theme'),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('外观设置'),
            // 副标题直接显示当前选的是哪一种，不用点进去也知道
            subtitle: Text('当前：${_themeModeLabel(settings.themeMode)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickThemeMode(context, ref, settings.themeMode),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('翻译模式'),
            // 副标题说明当前模式 + 影响范围，用户不用点进去就能看懂这个开关管什么
            subtitle: Text(
              '当前：${_translationModeLabel(settings.translationMode)}'
              '（作用于数据源里打开了"翻译"的标题 / 摘要）',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _pickTranslationMode(context, ref, settings.translationMode),
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

  /// 把外观模式翻译成人话（给设置页副标题和弹层用）。
  static String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  /// 弹出底部菜单让用户选外观模式：跟随系统 / 浅色 / 深色。
  /// 选中后立刻保存，App 根组件会重建整套主题，无需重启。
  void _pickThemeMode(BuildContext context, WidgetRef ref, ThemeMode current) {
    // 三个选项固定顺序，和下面的图标一一对应
    const modes = <ThemeMode>[
      ThemeMode.system,
      ThemeMode.light,
      ThemeMode.dark,
    ];
    const icons = <IconData>[
      Icons.brightness_auto, // 跟随系统
      Icons.light_mode, // 浅色
      Icons.dark_mode, // 深色
    ];

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
                  Text('外观设置', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            // 三个选项平铺，当前选中的打勾
            for (int i = 0; i < modes.length; i++)
              ListTile(
                leading: Icon(icons[i]),
                title: Text(_themeModeLabel(modes[i])),
                trailing: modes[i] == current ? const Icon(Icons.check) : null,
                onTap: () {
                  ref
                      .read(feedSettingsProvider.notifier)
                      .setThemeMode(modes[i]);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 把翻译模式翻译成人话（给设置页副标题和弹层用）。
  static String _translationModeLabel(TranslationMode mode) {
    switch (mode) {
      case TranslationMode.replace:
        return '原文替换（只显示译文）';
      case TranslationMode.bilingual:
        return '双语共存（上原文、下译文）';
    }
  }

  /// 弹出底部菜单让用户选翻译模式：原文替换 / 双语共存。
  ///
  /// 选中后除了存设置，还要把信息流 provider 作废：已经拉下来的文章里装的
  /// 是按旧模式拼好的文字，不作废的话要等下次刷新才看得到新效果。
  void _pickTranslationMode(
    BuildContext context,
    WidgetRef ref,
    TranslationMode current,
  ) {
    // 选项顺序固定，和下面的图标一一对应
    const modes = <TranslationMode>[
      TranslationMode.replace,
      TranslationMode.bilingual,
    ];
    const icons = <IconData>[
      Icons.find_replace, // 原文替换：译文把原文换掉
      Icons.view_agenda, // 双语共存：两条文字上下摞着
    ];

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
                  Text('翻译模式', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            // 两个选项平铺，当前选中的打勾
            for (int i = 0; i < modes.length; i++)
              ListTile(
                leading: Icon(icons[i]),
                title: Text(_translationModeLabel(modes[i])),
                trailing: modes[i] == current ? const Icon(Icons.check) : null,
                onTap: () async {
                  // 先等设置真正写进 SharedPreferences：下面的作废会立刻触发重拉，
                  // 必须保证重拉时读到的是新模式，否则会拿旧模式再拉一遍。
                  await ref
                      .read(feedSettingsProvider.notifier)
                      .setTranslationMode(modes[i]);
                  // 弹层可能已经被用户点别处关掉了，关之前先判断一下
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  // 作废信息流：聚合流 + 所有单源 Tab，下次渲染时按新模式重新抓取
                  ref.invalidate(feedAggregateProvider);
                  ref.invalidate(feedTabProvider);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
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
