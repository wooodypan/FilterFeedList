import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_backup.dart';
import '../../providers/backup_provider.dart';
import '../../providers/blocked_keyword_provider.dart';
import '../../providers/data_source_provider.dart';
import '../../providers/plugin_provider.dart';
import '../../services/backup_service.dart';

/// 配置备份与恢复页。
///
/// 两个能力：
/// - 导出：把数据源 / 插件 / 屏蔽词 / 全局设置打包成一个 .json 文件发出去
/// - 导入：读回一个 .json 备份文件，合并进本地或整体覆盖本地
///
/// 典型用途：换手机时把配好的订阅源搬过去，或者备份一份防止手滑删掉。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  /// 是否正在处理（导出 / 导入）——期间禁用按钮，避免重复点击
  bool _busy = false;

  /// 上次导出生成的文件路径（展示给用户，方便去找文件）
  String? _lastExportPath;

  @override
  Widget build(BuildContext context) {
    // 当前各类配置的条数，用于"当前配置"概览
    final sourcesAsync = ref.watch(dataSourcesProvider);
    final pluginsAsync = ref.watch(installedPluginsProvider);
    final keywordsAsync = ref.watch(blockedKeywordsProvider);

    final sourceCount = sourcesAsync.valueOrNull?.length ?? 0;
    final pluginCount = pluginsAsync.valueOrNull?.length ?? 0;
    final keywordCount = keywordsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ---- 当前配置概览 ----
          _SectionHeader('当前配置'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _CountRow(
                  icon: Icons.rss_feed,
                  label: '数据源',
                  count: sourceCount,
                ),
                _CountRow(
                  icon: Icons.extension,
                  label: '插件',
                  count: pluginCount,
                ),
                _CountRow(icon: Icons.block, label: '屏蔽词', count: keywordCount),
              ],
            ),
          ),

          // ---- 导出 ----
          _SectionHeader('导出'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('导出为文件'),
                  subtitle: const Text('生成 .json 备份文件，可通过系统分享保存或发送'),
                  enabled: !_busy,
                  onTap: _exportToFile,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.copy_all),
                  title: const Text('复制为文本'),
                  subtitle: const Text('把备份内容复制到剪贴板，适合粘贴给另一台设备'),
                  enabled: !_busy,
                  onTap: _copyToClipboard,
                ),
                // 导出成功后把文件路径告诉用户，免得他不知道文件去哪了
                if (_lastExportPath != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '已生成：$_lastExportPath',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ---- 导入 ----
          _SectionHeader('导入'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('从文件导入'),
                  subtitle: const Text('选择一个之前导出的 .json 备份文件'),
                  enabled: !_busy,
                  onTap: _importFromFile,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.paste),
                  title: const Text('从文本导入'),
                  subtitle: const Text('粘贴备份内容（跨设备不方便传文件时用）'),
                  enabled: !_busy,
                  onTap: _importFromText,
                ),
              ],
            ),
          ),

          // ---- 底部提示 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '备份包含：数据源配置、插件脚本、屏蔽词、全局设置。'
              '插件脚本会完整打包，导入后无需重新下载。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          // 处理中给一个明确进度，避免用户以为卡住了
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  /// 导出为文件并唤起系统分享面板。
  Future<void> _exportToFile() async {
    await _runBusy(() async {
      final path = await ref.read(backupControllerProvider).exportToFile();
      if (!mounted) return;
      setState(() => _lastExportPath = path);
      _showMessage('备份文件已生成，可在分享面板中选择保存位置');
    });
  }

  /// 导出为 JSON 文本并复制到剪贴板。
  Future<void> _copyToClipboard() async {
    await _runBusy(() async {
      final text = await ref.read(backupControllerProvider).exportToText();
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      _showMessage('备份内容已复制到剪贴板');
    });
  }

  /// 从文件导入：选文件 → 解析 → 确认 → 写入。
  Future<void> _importFromFile() async {
    await _runBusy(() async {
      // 用户在文件面板里取消选择时返回 null，静默结束即可
      final picked = await ref.read(backupControllerProvider).pickBackupFile();
      if (picked == null || !mounted) return;

      await _confirmAndImport(picked.backup, sourceName: picked.fileName);
    });
  }

  /// 从粘贴的文本导入：弹输入框 → 解析 → 确认 → 写入。
  Future<void> _importFromText() async {
    // 先在对话框里拿到用户粘贴的文本（这一步不需要 loading 遮罩）
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteBackupDialog(),
    );
    if (text == null || !mounted) return;

    await _runBusy(() async {
      AppBackup backup;
      try {
        backup = BackupService.parse(text);
      } on BackupFormatException catch (e) {
        if (!mounted) return;
        _showError(e.message);
        return;
      }
      if (!mounted) return;
      await _confirmAndImport(backup, sourceName: '粘贴的内容');
    });
  }

  /// 弹出"确认导入"对话框，用户选好方式后真正写库。
  Future<void> _confirmAndImport(
    AppBackup backup, {
    required String sourceName,
  }) async {
    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (_) =>
          _ImportConfirmDialog(backup: backup, sourceName: sourceName),
    );
    // 用户取消
    if (mode == null || !mounted) return;

    try {
      final result = await ref
          .read(backupControllerProvider)
          .importBackup(backup, mode: mode);
      if (!mounted) return;
      _showMessage('导入完成：${result.summary}');
      setState(() => _lastExportPath = null);
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    }
  }

  /// 统一的"忙时保护"：开关 loading + 兜底捕获异常。
  ///
  /// 任何一步抛异常都在这里变成一条错误提示，不会让页面卡在转圈状态。
  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on BackupFormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('操作失败：$e');
    } finally {
      // 页面可能已经被关掉（比如用户中途返回），写 setState 前先判断
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }
}

/// 分段标题（"当前配置" / "导出" / "导入"）。
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

/// 概览里的一行："图标  名称  N 条"
class _CountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _CountRow({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: Text(
        '$count',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 粘贴导入的输入框。
class _PasteBackupDialog extends StatefulWidget {
  const _PasteBackupDialog();

  @override
  State<_PasteBackupDialog> createState() => _PasteBackupDialogState();
}

class _PasteBackupDialogState extends State<_PasteBackupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 点"确定"前的本地校验：只查空，真正的格式校验交给 BackupService.parse
  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('粘贴备份内容'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          maxLines: 8,
          minLines: 5,
          // 等宽字体 + 小字号：JSON 一屏能多显示点
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            hintText: '把备份的 JSON 内容粘贴到这里',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('下一步')),
      ],
    );
  }
}

/// 导入前的确认对话框：告诉用户这份备份里有什么，并让他选导入方式。
///
/// 两种方式的差别必须说清楚，因为"覆盖"会清掉现有配置：
/// - 合并：保留现有，同 id 的更新、没有的追加
/// - 覆盖：先清空现有全部配置，再按备份原样重建（Tab 顺序也一起还原）
class _ImportConfirmDialog extends StatelessWidget {
  final AppBackup backup;
  final String sourceName;

  const _ImportConfirmDialog({required this.backup, required this.sourceName});

  /// 把导出时间格式化成"2026-08-29 23:35"
  String get _exportedAtText {
    final t = backup.exportedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('确认导入'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 备份内容摘要，让用户先确认"这确实是我要的那份"
          Text('来源：$sourceName', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('导出时间：$_exportedAtText', style: theme.textTheme.bodySmall),
          const Divider(height: 20),
          _infoRow('数据源', '${backup.dataSources.length} 个'),
          _infoRow('插件', '${backup.plugins.length} 个'),
          _infoRow('屏蔽词', '${backup.blockedKeywords.length} 个'),
          const SizedBox(height: 12),
          Text(
            '选择导入方式：',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // 方式一：合并（默认推荐，不破坏现有数据）
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(ImportMode.merge),
              child: const Text('合并（保留现有配置）'),
            ),
          ),
          const SizedBox(height: 8),
          // 方式二：覆盖（危险操作，用红色描边提示）
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              onPressed: () => Navigator.of(context).pop(ImportMode.replace),
              child: const Text('覆盖（清空后重建）'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  '「覆盖」会删除当前所有数据源、插件和屏蔽词，且不可撤销',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  /// 摘要里的一行："字段名  值"
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
