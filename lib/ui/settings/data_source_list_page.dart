import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/data_source_config.dart';
import '../../plugin/models/installed_plugin.dart';
import '../../plugin/models/plugin_manifest.dart';
import '../../plugin/plugin_downloader.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_source_provider.dart';
import '../../providers/plugin_provider.dart';

/// 数据源列表：展示所有已配置的数据源，可编辑 / 删除 / 开关启用。
///
/// 右下角加号支持两种添加方式：
/// 1. 手动配置：跳转表单页填 API 地址 + 字段映射（适合简单的公开 API）
/// 2. 安装插件：输入插件脚本 URL，下载并校验后装到本地（适合需要签名/加密的 API）
class DataSourceListPage extends ConsumerWidget {
  const DataSourceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 同时监听两类"信息源"：JSONPath 数据源 + 已安装插件
    final sourcesAsync = ref.watch(dataSourcesProvider);
    final pluginsAsync = ref.watch(installedPluginsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('数据源管理')),
      // 右下角浮动按钮：新增数据源（点击弹出两种添加方式）
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSourceSheet(context, ref),
        tooltip: '新增数据源',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context, ref, sourcesAsync, pluginsAsync),
    );
  }

  /// 把"API 数据源"与"插件"合并展示在同一个列表里（分段标题 + 各自条目）。
  ///
  /// 任一列表正在加载就转圈；任一加载失败就提示错误。两类都为空时才显示空态。
  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<DataSourceConfig>> sourcesAsync,
    AsyncValue<List<InstalledPlugin>> pluginsAsync,
  ) {
    if (sourcesAsync.isLoading || pluginsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = sourcesAsync.error ?? pluginsAsync.error;
    if (err != null) {
      return Center(child: Text('加载失败：$err'));
    }

    final sources = sourcesAsync.value!;
    final plugins = pluginsAsync.value!;
    // 按类型拆成两段（同存一张表，靠 sourceType 区分）
    final rssSources = sources.where((s) => s.sourceType == DataSourceType.rss);
    final jsonSources = sources.where(
      (s) => s.sourceType == DataSourceType.json,
    );
    if (sources.isEmpty && plugins.isEmpty) {
      return const Center(child: Text('还没有数据源，点右下角 + 添加一个'));
    }

    return ListView(
      children: [
        if (rssSources.isNotEmpty) ...[
          const _SectionHeader('RSS 订阅'),
          ...rssSources.map((s) => _SourceTile(config: s)),
        ],
        if (jsonSources.isNotEmpty) ...[
          const _SectionHeader('API 数据源'),
          ...jsonSources.map((s) => _SourceTile(config: s)),
        ],
        if (plugins.isNotEmpty) ...[
          const _SectionHeader('插件'),
          ...plugins.map((p) => _PluginTile(plugin: p)),
        ],
      ],
    );
  }

  /// 点加号：底部弹出"选择添加方式"的面板。
  void _showAddSourceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                '添加数据源',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            // 引导：不知道订什么？打开推荐列表，可一键导入
            ListTile(
              leading: const Icon(Icons.explore),
              title: const Text('不知道订阅什么？点击查看推荐'),
              subtitle: const Text('浏览热门 RSS 源，一键导入'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                context.push('/settings/sources/rss-recommend');
              },
            ),
            const Divider(height: 1),
            // 方式一：订阅 RSS（填一个 feed 地址即可）
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('订阅 RSS'),
              subtitle: const Text('输入 RSS / Atom 地址，一键订阅'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                context.push('/settings/sources/rss-edit');
              },
            ),
            // 方式：从 OPML 文件批量导入（兼容 Feedly / Inoreader 等阅读器导出）
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('从 OPML 导入'),
              subtitle: const Text('选择 .opml 文件，批量添加订阅源'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                context.push('/settings/sources/opml-import');
              },
            ),
            // 方式二：手动配置（原有的表单流程）
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('手动配置'),
              subtitle: const Text('填写 API 地址和字段映射规则'),
              onTap: () {
                Navigator.of(sheetCtx).pop(); // 先关掉底部面板
                context.push('/settings/sources/edit');
              },
            ),
            // 方式三：安装插件（下载 JS 脚本）
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('安装插件'),
              subtitle: const Text('输入插件脚本 URL，下载并安装'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _showInstallPluginDialog(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 弹出"输入插件 URL"的对话框。
  void _showInstallPluginDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _InstallPluginDialog(),
    );
  }
}

/// 安装插件对话框：输入 URL → 下载校验 → 确认安装。
///
/// 使用 ConsumerStatefulWidget 是为了管理自己的异步状态
/// （下载中 loading、错误提示），同时能通过 ref 拿插件系统的 Provider。
class _InstallPluginDialog extends ConsumerStatefulWidget {
  const _InstallPluginDialog();

  @override
  ConsumerState<_InstallPluginDialog> createState() =>
      _InstallPluginDialogState();
}

class _InstallPluginDialogState extends ConsumerState<_InstallPluginDialog> {
  final _urlController = TextEditingController();
  bool _loading = false; // 是否正在下载
  String? _error; // 下载/解析失败时的提示

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// 下载插件脚本并引导用户确认安装。
  Future<void> _downloadAndInstall() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入插件脚本 URL');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) 下载脚本 + 解析 manifest + 校验 buildRequest/parseResponse 存在
      //    （这些校验都在 PluginDownloader.fetch 内部完成，失败会抛异常）
      final result = await ref.read(pluginDownloaderProvider).fetch(url);

      // 2) 弹出"确认安装"对话框，用户点头才真正落库
      final confirmed = await _confirmInstall(result);
      if (!confirmed) return;

      // 3) 组装成 InstalledPlugin 存进数据库（id 相同则覆盖更新）
      final plugin = InstalledPlugin(
        id: result.manifest.id,
        name: result.manifest.name,
        scriptContent: result.script, // 完整 JS 源码，本地持久化
        manifest: result.manifest,
        sourceUrl: result.sourceUrl, // 来源 URL，供"检查更新"用
        enabled: true, // 装完默认启用，信息流立刻能拉到
        installedAt: DateTime.now(),
        version: result.manifest.version ?? '0.0.0',
      );
      await ref.read(installedPluginsProvider.notifier).install(plugin);

      if (!mounted) return;
      // 先拿 messenger 再关对话框，避免 context 失效
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('插件「${plugin.name}」安装成功')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 把异常里的 message 提取出来展示（如"下载失败：xxx"）。
        // 注意不能用 `e is A || e is B ? e.message : ...`：Dart 在 || 里不会做类型提升，
        // 所以这里分开判断，两个下载/解析异常都带 message 字段。
        String msg;
        if (e is PluginDownloadException) {
          msg = e.message;
        } else if (e is PluginManifestException) {
          msg = e.message;
        } else {
          msg = '安装失败：$e';
        }
        _error = msg;
      });
    }
  }

  /// 确认安装对话框：把插件的清单信息展示给用户 + 风险提示。
  Future<bool> _confirmInstall(PluginDownloadResult result) async {
    final manifest = result.manifest;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认安装插件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 插件名称 + 版本
            Row(
              children: [
                const Icon(Icons.extension, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    manifest.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('ID', manifest.id),
            if (manifest.version != null) _infoRow('版本', manifest.version!),
            if (manifest.author != null) _infoRow('作者', manifest.author!),
            if (manifest.description != null &&
                manifest.description!.isNotEmpty)
              _infoRow('描述', manifest.description!),
            const Divider(height: 24),
            // 来源 URL 用小字展示，方便用户核实可信度
            Text(
              '来源：${result.sourceUrl}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // 安全提示：插件会在本地沙箱执行，只装可信来源
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '插件将在本地沙箱中执行（无网络/文件访问权限），'
                    '但仍建议只安装可信来源的脚本',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('安装'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// 清单信息里的一行："字段名  值"
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('安装插件'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // URL 输入框：支持粘贴完整脚本地址
          TextField(
            controller: _urlController,
            autofocus: true,
            enabled: !_loading, // 下载中禁止再改
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '插件脚本 URL',
              hintText: 'https://example.com/plugin.js',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _downloadAndInstall(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading ? null : _downloadAndInstall,
          // 下载中显示小转圈，提示用户在干活
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('下载并安装'),
        ),
      ],
    );
  }
}

/// 列表分段标题（"API 数据源" / "插件" 两段）。
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 单个已安装插件的列表项：启用开关 + 编辑 + 删除。
///
/// 插件不像 API 数据源那样有"表单字段"，它的核心就是一段 JS 脚本，
/// 因此这里的"编辑"是打开一个对话框，让用户直接改**显示名**和**脚本正文**，
/// 保存前会校验脚本仍包含 buildRequest / parseResponse，避免改坏后跑不起来。
class _PluginTile extends ConsumerWidget {
  final InstalledPlugin plugin;
  const _PluginTile({required this.plugin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = plugin.manifest;
    return ListTile(
      leading: Checkbox(
        value: plugin.enabled,
        onChanged: (v) => ref
            .read(installedPluginsProvider.notifier)
            .setEnabled(plugin.id, v ?? false),
      ),
      title: Text(plugin.name),
      subtitle: Text(
        '插件 · ${manifest.id}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // 整行可点 = 打开编辑；也保留了明确的编辑/删除图标
      onTap: () => _showEditDialog(context, plugin),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: () => _showEditDialog(context, plugin),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  /// 弹出"编辑插件"对话框。
  void _showEditDialog(BuildContext context, InstalledPlugin plugin) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditPluginDialog(plugin: plugin),
    );
  }

  /// 删除插件前确认
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除插件'),
        content: Text('确定删除"${plugin.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(installedPluginsProvider.notifier).delete(plugin.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 编辑插件对话框：修改显示名 + JS 脚本正文，保存前做安全校验。
///
/// 设计取舍：
/// - 只暴露"显示名"和"脚本正文"两个可改项，[id] / [manifest.id] 保持不变，
///   避免改了 id 后和已落库的那一行对不上（覆盖写入依赖 id 作为主键）。
/// - 保存时调用 [PluginDownloader.validateScript] 复用与"安装"完全一致的校验，
///   保证改完的脚本仍能跑（至少含 buildRequest / parseResponse）。
class _EditPluginDialog extends ConsumerStatefulWidget {
  final InstalledPlugin plugin;
  const _EditPluginDialog({required this.plugin});

  @override
  ConsumerState<_EditPluginDialog> createState() => _EditPluginDialogState();
}

class _EditPluginDialogState extends ConsumerState<_EditPluginDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _scriptController;
  bool _saving = false; // 是否正在保存
  String? _error; // 校验/保存失败时的提示
  bool _useAppDeepLink = true; // 是否启用"App 深链直达"（默认开启）

  @override
  void initState() {
    super.initState();
    // 初始化为当前插件的值，用户在此基础上改
    _nameController = TextEditingController(text: widget.plugin.name);
    _scriptController = TextEditingController(
      text: widget.plugin.scriptContent,
    );
    _useAppDeepLink = widget.plugin.useAppDeepLink;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  /// 保存：先校验，再覆盖写入数据库。
  Future<void> _save() async {
    final name = _nameController.text.trim();
    final script = _scriptController.text;
    if (name.isEmpty) {
      setState(() => _error = '显示名不能为空');
      return;
    }
    // 复用下载器的校验：脚本不能为空且必须含两个核心函数
    try {
      PluginDownloader.validateScript(script);
    } on PluginDownloadException catch (e) {
      setState(() => _error = e.message);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // 用 copyWith 生成改后的实例：id / manifest / 版本号等都保持原值，
      // 只换 name 和 scriptContent，然后按 id 覆盖写入。
      final updated = widget.plugin.copyWith(
        name: name,
        scriptContent: script,
        useAppDeepLink: _useAppDeepLink,
      );
      await ref.read(installedPluginsProvider.notifier).update(updated);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('插件「$name」已保存')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 让对话框宽一点，脚本才有足够的横向空间
    return AlertDialog(
      title: const Text('编辑插件'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 显示名
              TextField(
                controller: _nameController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: '显示名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // 脚本正文：等宽字体 + 多行，方便看 JS 结构；至少 8 行高
              const Text(
                '脚本正文',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _scriptController,
                enabled: !_saving,
                maxLines: 12,
                minLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'function buildRequest(...) { ... }',
                ),
              ),
              const SizedBox(height: 12),
              // App 深链直达开关：开启后，若插件产出的文章带 appDeepLink
              // （如 smzdm://youhui/123），点开时优先拉起对应 App，拉起失败再退回 WebView。
              SwitchListTile(
                title: const Text('使用 AppDeepLink 直达 App'),
                subtitle: const Text('开启后优先用文章的深链拉起对应 App'),
                value: _useAppDeepLink,
                onChanged: (v) => setState(() => _useAppDeepLink = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

/// 单个数据源的列表项
class _SourceTile extends ConsumerWidget {
  final DataSourceConfig config;
  const _SourceTile({required this.config});

  /// 编辑入口按类型分流：RSS 源走精简表单，JSONPath 源走完整映射表单
  String get _editRoute => config.sourceType == DataSourceType.rss
      ? '/settings/sources/rss-edit'
      : '/settings/sources/edit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      // 启用开关
      leading: Checkbox(
        value: config.enabled,
        onChanged: (v) => ref
            .read(dataSourcesProvider.notifier)
            .setEnabled(config.id, v ?? false),
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
            onPressed: () => context.push(_editRoute, extra: config),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      onTap: () => context.push(_editRoute, extra: config),
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
