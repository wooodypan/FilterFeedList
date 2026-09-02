import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../providers/blocked_keyword_provider.dart';

/// 屏蔽词管理页：添加 / 修改（改词 + 改时长）/ 删除屏蔽词。
///
/// 每个屏蔽词可以设成：
/// - 永久屏蔽（expiresAt 为 null）；
/// - 屏蔽指定时间（如 7 天），到期自动失效（但行仍留在库里，可续期/恢复）。
class BlockedKeywordPage extends ConsumerWidget {
  const BlockedKeywordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedKeywordsProvider);
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('屏蔽词管理')),
      body: Column(
        children: [
          // 顶部输入区：输入词后点"添加"会弹出对话框，让你选"永久/指定天数"
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '输入要屏蔽的词',
                      hintText: '例如：广告 / 带货 / 标题党',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) =>
                        _openAddDialog(context, ref, controller),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _openAddDialog(context, ref, controller),
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('还没有屏蔽词'));
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final expired = _isExpired(row);
                    return ListTile(
                      leading: Icon(
                        Icons.block,
                        // 过期了就灰掉，视觉上区分"还在生效"的词
                        color: expired ? Colors.grey : Colors.red,
                      ),
                      title: Text(row.word),
                      // 副标题显示到期信息，让用户一眼看清状态
                      subtitle: Text(_expiryText(row)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 编辑：改词面 / 改时长
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: '修改',
                            onPressed: () => _openEditDialog(context, ref, row),
                          ),
                          // 删除
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除',
                            onPressed: () => ref
                                .read(blockedKeywordsProvider.notifier)
                                .remove(row.word),
                          ),
                        ],
                      ),
                      // 点整行也能进入修改
                      onTap: () => _openEditDialog(context, ref, row),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 打开"添加"对话框（把输入框内容带过去预填）。
  void _openAddDialog(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => _BlockedKeywordDialog(
        isEdit: false,
        initialWord: text,
        onSave: (word, expiresAt) {
          ref
              .read(blockedKeywordsProvider.notifier)
              .add(word, expiresAt: expiresAt);
          controller.clear();
        },
      ),
    );
  }

  /// 打开"修改"对话框（把当前行的词面 / 到期时间带过去）。
  void _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    BlockedKeyword row,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _BlockedKeywordDialog(
        isEdit: true,
        initialWord: row.word,
        initialExpiresAt: row.expiresAt,
        onSave: (word, expiresAt) {
          ref
              .read(blockedKeywordsProvider.notifier)
              .update(row.word, word, expiresAt);
        },
      ),
    );
  }

  /// 判断某条屏蔽词是否已过期（NULL 永不过期）。
  bool _isExpired(BlockedKeyword row) {
    final exp = row.expiresAt;
    return exp != null && !exp.isAfter(DateTime.now());
  }

  /// 把到期时间翻译成给人看的中文文案。
  String _expiryText(BlockedKeyword row) {
    final exp = row.expiresAt;
    if (exp == null) return '永久屏蔽';
    if (!exp.isAfter(DateTime.now())) {
      return '已过期（到期：${_format(exp)}）';
    }
    // 还剩多少天：用小时算再向上取整，避免"剩 23 小时"显示成 0 天
    final hoursLeft = exp.difference(DateTime.now()).inHours;
    final daysLeft = (hoursLeft / 24).ceil();
    return '屏蔽至 ${_format(exp)}（约剩 $daysLeft 天）';
  }

  /// 简单的日期格式化：yyyy-MM-dd HH:mm，不引第三方库。
  String _format(DateTime dt) {
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }
}

/// 添加 / 修改屏蔽词的通用对话框。
///
/// 复用的好处：添加和修改的界面完全一致，只是"是否预填已有值"的区别。
/// [initialWord] 预填词面；[initialExpiresAt] 预填到期时间（NULL=永久）；
/// [onSave] 在用户点"保存"时回传最终词面与到期时间。
class _BlockedKeywordDialog extends StatefulWidget {
  final bool isEdit;
  final String initialWord;
  final DateTime? initialExpiresAt;
  final void Function(String word, DateTime? expiresAt) onSave;

  const _BlockedKeywordDialog({
    required this.isEdit,
    required this.initialWord,
    this.initialExpiresAt,
    required this.onSave,
  });

  @override
  State<_BlockedKeywordDialog> createState() => _BlockedKeywordDialogState();
}

class _BlockedKeywordDialogState extends State<_BlockedKeywordDialog> {
  // 词面输入框
  late final TextEditingController _wordController;
  // 时长模式：0=永久，1=指定天数
  late int _mode;
  // 指定天数（天），配合几个快捷选项和自定义输入
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.initialWord);
    // 若已有到期时间，进入"指定天数"模式，并把天数反推出来（向上取整）
    if (widget.initialExpiresAt == null) {
      _mode = 0;
    } else {
      _mode = 1;
      final left = widget.initialExpiresAt!.difference(DateTime.now()).inHours;
      _days = left > 0 ? (left / 24).ceil() : 1;
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? '修改屏蔽词' : '添加屏蔽词'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 词面输入
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(
                labelText: '屏蔽词',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('屏蔽时长', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 永久 / 指定天数 二选一
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('永久')),
                ButtonSegment(value: 1, label: Text('指定天数')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            // 选了"指定天数"才显示天数选择
            if (_mode == 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in [1, 7, 30, 90])
                    ChoiceChip(
                      label: Text('$d 天'),
                      selected: _days == d,
                      onSelected: (_) => setState(() => _days = d),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('自定义：'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        suffixText: '天',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) {
                          setState(() => _days = n);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final word = _wordController.text.trim();
            if (word.isEmpty) return;
            // 选"指定天数"才计算具体到期时间；选"永久"传 null
            final expiresAt = _mode == 1
                ? DateTime.now().add(Duration(days: _days))
                : null;
            widget.onSave(word, expiresAt);
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
