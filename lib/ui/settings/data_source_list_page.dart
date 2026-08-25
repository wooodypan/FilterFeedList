import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/data_source_config.dart';
import '../../providers/data_source_provider.dart';

/// 数据源列表：展示所有已配置的数据源，可编辑 / 删除 / 开关启用。
class DataSourceListPage extends ConsumerWidget {
  const DataSourceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dataSourcesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('数据源管理')),
      // 右下角浮动按钮：新增数据源
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/sources/edit'),
        tooltip: '新增数据源',
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('还没有数据源，点右下角 + 添加一个'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return _SourceTile(config: s);
            },
          );
        },
      ),
    );
  }
}

/// 单个数据源的列表项
class _SourceTile extends ConsumerWidget {
  final DataSourceConfig config;
  const _SourceTile({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      // 启用开关
      leading: Checkbox(
        value: config.enabled,
        onChanged: (v) =>
            ref.read(dataSourcesProvider.notifier).setEnabled(
                  config.id,
                  v ?? false,
                ),
      ),
      title: Text(config.name),
      subtitle: Text(
        config.apiUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: () =>
                context.push('/settings/sources/edit', extra: config),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      onTap: () => context.push('/settings/sources/edit', extra: config),
    );
  }

  /// 删除前确认
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除数据源'),
        content: Text('确定删除"${config.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(dataSourcesProvider.notifier).delete(config.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
