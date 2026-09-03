import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/data_source_config.dart';
import '../../providers/data_source_provider.dart';
import '../../services/opml_parser.dart';

/// OPML 导入页：选文件 → 解析 → 预览（含重复检测）→ 勾选 → 批量导入。
///
/// 设计目标（对齐需求）：
/// - 文件上传：系统文件面板，只允许 .opml / .xml
/// - 格式校验：解析失败给明确文案（不是 XML / 没有 body / 没有可导入订阅）
/// - 重复检测：按订阅地址（大小写不敏感）和现有源比对，重复项默认不勾选、单独分组
/// - 导入结果反馈：弹窗统计"成功 N / 已存在跳过 M / 地址无效 K"
class OpmlImportPage extends ConsumerStatefulWidget {
  const OpmlImportPage({super.key});

  @override
  ConsumerState<OpmlImportPage> createState() => _OpmlImportPageState();
}

class _OpmlImportPageState extends ConsumerState<OpmlImportPage> {
  bool _loading = false; // 选文件/解析/导入期间禁用按钮
  String? _error; // 解析或读取失败时的提示
  String? _fileName; // 已选文件名，回显给用户
  OpmlParseResult? _result; // 解析结果（含可导入订阅 + 统计）
  List<_Candidate> _candidates = []; // 预览列表（已和现有源比过重复）

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入 OPML')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ---- 1) 选文件 ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _pickAndParse,
              icon: const Icon(Icons.file_upload),
              label: Text(_fileName == null ? '选择 OPML 文件' : '重新选择文件'),
            ),
          ),
          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '已选择：$_fileName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

          // ---- 2) 错误提示 ----
          if (_error != null)
            _Banner(
              color: Colors.red,
              icon: Icons.error_outline,
              child: Text(_error!),
            ),

          // ---- 3) 解析结果：统计 + 预览 ----
          if (_result != null) ...[
            _SummaryBanner(result: _result!),
            _buildCandidateList(context),
          ],

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      // ---- 底部导入栏：始终可见，实时显示将导入数量 ----
      bottomNavigationBar: _result == null
          ? null
          : _ImportBar(
              selectedCount: _candidates.where((c) => c.selected).length,
              onImport: _loading ? null : _importSelected,
            ),
    );
  }

  /// 预览列表：先列"新订阅"（默认勾选），再列"已存在"（默认不勾选）。
  Widget _buildCandidateList(BuildContext context) {
    final news = _candidates.where((c) => !c.duplicate).toList();
    final dups = _candidates.where((c) => c.duplicate).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (news.isNotEmpty) ...[
          const _SectionTitle('待导入（新订阅）'),
          ...news.map(
            (c) => _CandidateTile(candidate: c, onChanged: _onToggle),
          ),
        ],
        if (dups.isNotEmpty) ...[
          const _SectionTitle('已存在（重复，默认不导入）'),
          ...dups.map(
            (c) => _CandidateTile(candidate: c, onChanged: _onToggle),
          ),
        ],
      ],
    );
  }

  void _onToggle() {
    // 只要某一项被勾选状态变化，setState 让底部按钮的计数刷新即可
    setState(() {});
  }

  /// 选文件 → 读文本 → 解析 → 生成预览（含重复检测）。
  Future<void> _pickAndParse() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: '选择 OPML 文件',
        type: FileType.custom,
        // 只允许 opml / xml，避免误选图片等二进制导致一堆乱码错
        allowedExtensions: ['opml', 'xml'],
      );
      if (files.isEmpty) {
        // 用户在面板里取消 = 静默结束，不报错
        if (mounted) setState(() => _loading = false);
        return;
      }
      final file = files.first;
      // 读字节再 UTF-8 解码：比直接读路径更可靠（macOS 沙盒下路径可能受限）
      final bytes = await file.readAsBytes();
      final text = utf8.decode(bytes);

      final result = OpmlParser.parse(text);
      // 和现有数据源比对，标出"已存在"（按订阅地址大小写不敏感判断）
      final existing = ref.read(dataSourcesProvider).valueOrNull ?? const [];
      final candidates = result.valid.map((feed) {
        final dup = existing.any(
          (s) => _normalizeUrl(s.apiUrl) == _normalizeUrl(feed.xmlUrl),
        );
        // 新订阅默认勾选、重复项默认不勾选
        return _Candidate(feed: feed, duplicate: dup, selected: !dup);
      }).toList();

      if (mounted) {
        setState(() {
          _fileName = file.name;
          _result = result;
          _candidates = candidates;
        });
      }
    } on OpmlParseException catch (e) {
      // 解析相关的错误文案已经很友好，直接展示
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '读取或解析失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 把勾选中的订阅落库，并弹结果反馈。
  Future<void> _importSelected() async {
    final selected = _candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) {
      setState(() => _error = '请先勾选要导入的订阅');
      return;
    }

    setState(() => _loading = true);
    try {
      // 生成唯一 id：时间戳 + 序号，保证同一批内互不冲突
      final base = DateTime.now().microsecondsSinceEpoch;
      final configs = <DataSourceConfig>[];
      for (var i = 0; i < selected.length; i++) {
        final feed = selected[i].feed;
        configs.add(
          DataSourceConfig(
            id: '$base-$i',
            name: feed.name,
            sourceType: DataSourceType.rss,
            apiUrl: feed.xmlUrl,
            detailMode: DetailRenderMode.webview,
          ),
        );
      }
      await ref.read(dataSourcesProvider.notifier).addMultiple(configs);

      // 统计反馈：本次导入里有多少是"新"、多少是"原本就重复"（用户手动勾了的）
      final importedNew = selected.where((c) => !c.duplicate).length;
      final importedDup = selected.where((c) => c.duplicate).length;
      final skippedDup = _candidates
          .where((c) => c.duplicate && !c.selected)
          .length;
      final invalidCount = _result?.invalid.length ?? 0;

      if (!mounted) return;
      setState(() => _loading = false);
      await _showResult(
        importedNew: importedNew,
        importedDup: importedDup,
        skippedDup: skippedDup,
        invalidCount: invalidCount,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '导入失败：$e';
      });
    }
  }

  /// 导入结果反馈弹窗。
  Future<void> _showResult({
    required int importedNew,
    required int importedDup,
    required int skippedDup,
    required int invalidCount,
  }) async {
    final total = importedNew + importedDup;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('共导入 $total 个订阅：'),
            const SizedBox(height: 8),
            _infoRow('新增', '$importedNew 个'),
            if (importedDup > 0) _infoRow('重复项（已强制导入）', '$importedDup 个'),
            if (skippedDup > 0) _infoRow('已存在、跳过', '$skippedDup 个'),
            if (invalidCount > 0) _infoRow('地址无效、未导入', '$invalidCount 个'),
            const SizedBox(height: 12),
            const Text('导入的订阅已出现在「数据源管理」列表中。', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('完成'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 回到数据源管理列表，让用户立刻看到新增的订阅
              context.pop();
            },
            child: const Text('去管理页'),
          ),
        ],
      ),
    );
  }

  /// 归一化地址：小写 + 去首尾空白 + 去掉结尾斜杠，用于"重复检测"。
  String _normalizeUrl(String url) =>
      url.trim().toLowerCase().replaceAll(RegExp(r'/$'), '');
}

/// 预览里的单个订阅项（已和现有源比对过是否重复）。
class _Candidate {
  final OpmlFeed feed;
  final bool duplicate; // 与现有源地址重复
  bool selected; // 用户是否勾选导入

  _Candidate({
    required this.feed,
    required this.duplicate,
    required this.selected,
  });
}

/// 顶部彩色提示条（错误 / 普通信息通用）。
class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Widget child;
  const _Banner({required this.color, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// 解析完成的统计条：一眼看到"能导入 / 已存在 / 无效"的数量。
class _SummaryBanner extends StatelessWidget {
  final OpmlParseResult result;
  const _SummaryBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final invalid = result.invalid.length;
    return _Banner(
      color: Colors.teal,
      icon: Icons.check_circle_outline,
      child: Text(
        '解析到 ${result.valid.length} 个订阅'
        '${result.folderCount > 0 ? '，另有 ${result.folderCount} 个文件夹节点' : ''}'
        '${invalid > 0 ? '，$invalid 个地址无效' : ''}。',
      ),
    );
  }
}

/// 预览列表的分段标题。
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

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

/// 单个订阅的勾选行。
class _CandidateTile extends StatelessWidget {
  final _Candidate candidate;
  final VoidCallback onChanged;

  const _CandidateTile({required this.candidate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final feed = candidate.feed;
    return CheckboxListTile(
      // 重复项用淡一点的颜色，提示"它已经存在了"
      title: Text(
        feed.name,
        style: candidate.duplicate
            ? TextStyle(color: Colors.grey.shade600)
            : null,
      ),
      subtitle: Text(
        feed.xmlUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      // 重复项默认不勾选，用户仍可手动勾上强制导入
      value: candidate.selected,
      onChanged: (_) {
        candidate.selected = !candidate.selected;
        onChanged();
      },
      secondary: candidate.duplicate
          ? const Tooltip(
              message: '已存在相同地址的订阅',
              child: Icon(Icons.copy_outlined, color: Colors.grey),
            )
          : const Icon(Icons.rss_feed),
    );
  }
}

/// 底部导入栏：始终显示"将导入 N 个"，点一下执行导入。
class _ImportBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onImport;

  const _ImportBar({required this.selectedCount, this.onImport});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: selectedCount == 0 ? null : onImport,
          icon: const Icon(Icons.download_done),
          label: Text(
            selectedCount == 0 ? '请勾选要导入的订阅' : '导入选中（$selectedCount 个）',
          ),
        ),
      ),
    );
  }
}

/// 反馈弹窗里的一行："字段名  值"
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
