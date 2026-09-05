import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/blocked_keyword_provider.dart';
import '../../utils/word_segmenter.dart';

/// 文字大爆炸弹层。
///
/// 长按卡片标题后弹出：把标题文字炸成一块块「词」，用户可以：
/// 1) 「单击」词块逐个勾选/取消（可跳着选不相邻的词，比如只选「谷」和「牛腱」）；
/// 2) 「按住并滑动」一次连选一段相邻词（在已有勾选基础上追加，不会清掉之前选的）；
/// 3) 选中的词块会「按原文顺序拼成一整段短语」自动填进底部输入框；
///    例如选中「谷 / 饲 / 牛腱」输入框里就是「谷饲牛腱」，而不是拆成三块；
/// 4) 底部输入框可以直接修改（比如把「iPhone17Pro」手动补空格成
///    「iPhone 17 Pro」），也可以不管词块直接敲一个新词；
/// 5) 点唯一的「添加」按钮，把输入框里的内容加进屏蔽列表。
///
/// 用法：
/// ```dart
/// TextExplosionSheet.show(context, article.title);
/// ```
class TextExplosionSheet {
  /// 弹出文字大爆炸。
  ///
  /// [title] 是要被分词原始文本（一般是文章标题）。
  /// [onAdded] 在「批量添加选中词」成功后回调（用于关闭弹层 + 提示）；
  ///   第一个参数是添加的词数（拼成短语后固定为 1），第二个参数是拼好的短语。
  static Future<void> show(
    BuildContext context,
    String title, {
    void Function(int count, String phrase)? onAdded,
  }) {
    // 记下弹出前的页面 context，弹出后还能用它弹 SnackBar 提示
    final parentContext = context;
    return showModalBottomSheet<void>(
      context: context,
      // 允许弹层更高（且配合键盘弹出时不被遮挡）
      isScrollControlled: true,
      // 圆角 + 顶部小横条，视觉上更像系统「大爆炸」
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _TextExplosionContent(
        title: title,
        onAdded: (count, phrase) {
          Navigator.of(sheetContext).pop();
          onAdded?.call(count, phrase);
          if (count > 0) {
            ScaffoldMessenger.of(
              parentContext,
            ).showSnackBar(SnackBar(content: Text('已添加屏蔽词：$phrase')));
          }
        },
      ),
    );
  }
}

/// 弹层内部的可变状态组件。
class _TextExplosionContent extends ConsumerStatefulWidget {
  final String title;
  final void Function(int count, String phrase) onAdded;

  const _TextExplosionContent({required this.title, required this.onAdded});

  @override
  ConsumerState<_TextExplosionContent> createState() =>
      _TextExplosionContentState();
}

class _TextExplosionContentState extends ConsumerState<_TextExplosionContent> {
  /// 分词结果（一个个可独立选择的词块）
  late final List<String> _tokens;

  /// 当前被选中的词块下标集合（单击勾选、滑动连选都往这里累加）
  final Set<int> _selected = {};

  /// 是否正在「滑动选择」中（手指按在词块上）
  bool _dragging = false;

  /// 按住后是否发生过「跨词块移动」（用来区分单击和滑动）
  bool _dragMoved = false;

  /// 滑动选择的起点下标（按下的那个词）
  int _anchor = -1;

  /// 按下前的选中集合快照：
  /// - 滑动时：在它基础上追加区间（不清空已有勾选）；
  /// - 抬起发现是单击时：恢复快照再取反该词块，实现「单击勾选/取消」。
  Set<int> _selectionBeforePress = {};

  /// 每个词块的全局矩形（滑动时用来查「手指当前压在哪个词上」）。
  ///
  /// 必须自己查而不是靠各词块的 onPointerMove：Flutter 的命中测试只在
  /// 按下瞬间做一次，之后的 move 事件只会派发给按下时命中的那个词块，
  /// 滑到其他词块上时它们收不到任何事件。
  final Map<int, Rect> _chipRects = {};

  /// 每个词块一个 GlobalKey，用来测量词块的全局位置/尺寸。
  late final List<GlobalKey> _chipKeys;

  /// 输入框控制器（唯一的添加入口）。
  ///
  /// 选中的词块拼出的短语会自动填进来，用户可以在里面就地修改
  /// （比如给「iPhone17Pro」补空格），也可以直接敲一个自定义词。
  /// 不再有单独的「编辑」状态和「将屏蔽」预览行。
  final TextEditingController _inputController = TextEditingController();

  /// 添加屏蔽词时选的时长（天）；0 = 永久（默认）。
  /// 不碰下拉框就是永久屏蔽，和屏蔽词管理页的语义保持一致。
  int _selectedDays = 0;

  /// 时长下拉框的可选项：0 表示永久，其余是快捷天数
  static const List<int> _durationChoices = [0, 1, 7, 30, 90];

  /// 把天数选项翻译成下拉框里显示的文案
  String _durationLabel(int days) => days == 0 ? '永久' : '$days 天';

  @override
  void initState() {
    super.initState();
    // 进入时就先把标题分词，词块是静态的，后面只变选中状态
    _tokens = WordSegmenter.segment(widget.title);
    // 词块数量固定，为每个词块准备一个 GlobalKey 用来测量全局位置。
    // GlobalKey 在构造时就建好（不放 build 里），避免重建时 key 变化。
    _chipKeys = List.generate(_tokens.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// 词块「按下」：记录起点和按下前快照，先把该词块点亮做即时反馈。
  ///
  /// 此时还不确定用户是单击还是滑动，真正的勾选/区间选择推迟到
  /// [_handlePointerMove]（滑动）或 [_handlePointerUp]（单击）再落定。
  void _handlePointerDown(int i) {
    _dragging = true;
    _dragMoved = false;
    _anchor = i;
    _selectionBeforePress = Set<int>.of(_selected);
    // 选区一旦开始变化，就重算短语并同步到底部输入框
    setState(() {
      _selected.add(i);
      _inputController.text = _selectedPhrase;
    });
  }

  /// 手指「滑到」下标为 [i] 的词块上：把起点到该词的连续区间「追加」进选中集合。
  ///
  /// 追加而不是替换：用户可以先滑选一段，再滑选另一段，最后一起拼短语。
  void _handlePointerMove(int i) {
    if (!_dragging) return;
    if (i != _anchor) {
      _dragMoved = true;
    }
    final lo = _anchor < i ? _anchor : i;
    final hi = _anchor < i ? i : _anchor;
    setState(() {
      _selected
        ..clear()
        ..addAll(_selectionBeforePress);
      for (int x = lo; x <= hi; x++) {
        _selected.add(x);
      }
      // 滑动连选选区变了，把新短语同步到底部输入框
      _inputController.text = _selectedPhrase;
    });
  }

  /// 手指抬起：如果整个过程没滑出起点词块，就当「单击」处理——
  /// 恢复按下前快照后取反该词块的勾选状态（再点一次即取消）。
  void _handlePointerUp(int i) {
    if (!_dragging) return;
    _dragging = false;
    if (_dragMoved) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selected
        ..clear()
        ..addAll(_selectionBeforePress);
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else {
        _selected.add(i);
      }
      // 单击改变勾选，短语跟着同步到底部输入框（全不选则输入框清空）
      _inputController.text = _selectedPhrase;
    });
  }

  /// 查询全局坐标 [position] 当前压在哪个词块上，没压中任何词块返回 null。
  ///
  /// 词块数量少（标题分词结果），直接线性遍历矩形即可。
  int? _hitTestChip(Offset position) {
    for (final entry in _chipRects.entries) {
      if (entry.value.contains(position)) return entry.key;
    }
    return null;
  }

  /// 重算所有词块的全局矩形（布局完成后调用），供 [_hitTestChip] 查询。
  void _measureChipRects() {
    _chipRects.clear();
    for (int i = 0; i < _chipKeys.length; i++) {
      final box = _chipKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      _chipRects[i] = box.localToGlobal(Offset.zero) & box.size;
    }
  }

  /// 全局指针按下：命中某个词块就开始拖动。
  void _onAreaPointerDown(PointerDownEvent e) {
    _measureChipRects();
    final i = _hitTestChip(e.position);
    if (i != null) _handlePointerDown(i);
  }

  /// 全局指针移动：实时查手指压在哪个词块上，驱动连选。
  void _onAreaPointerMove(PointerMoveEvent e) {
    if (!_dragging) return;
    final i = _hitTestChip(e.position);
    if (i != null) _handlePointerMove(i);
  }

  /// 全局指针抬起：结束拖动（在词块上抬起才算单击）。
  void _onAreaPointerUp(PointerUpEvent e) {
    if (!_dragging) return;
    final i = _hitTestChip(e.position);
    if (i != null) {
      _handlePointerUp(i);
    } else {
      _dragging = false;
    }
  }

  /// 把当前选中的词块「按原文顺序拼成一个完整短语」。
  ///
  /// 无论词块是滑出来的连续区间，还是一个个点出来的不相邻词，
  /// 都按下标（即原文出现顺序）排序后拼接，得到用户真正想屏蔽的短语，
  /// 例如选中 谷 / 饲 / 牛腱 -> "谷饲牛腱"。
  String get _selectedPhrase {
    final idxs = _selected.toList()..sort();
    return idxs.map((i) => _tokens[i]).join('');
  }

  /// 清空选择，同时把底部输入框里同步过来的短语一并清掉。
  void _clearSelection() {
    setState(() {
      _selected.clear();
      _inputController.clear();
    });
  }

  /// 把输入框里的内容加进屏蔽列表（唯一的添加入口）。
  ///
  /// 内容既可能是词块拼出来、用户又手动改过的短语，
  /// 也可能是用户直接敲的自定义词——处理方式完全一样。
  /// 添加成功后通过 widget.onAdded 通知外部：关闭弹层 + SnackBar 提示。
  Future<void> _addFromInput() async {
    final w = _inputController.text.trim();
    if (w.isEmpty) return;
    // 按当前选中的时长计算到期时间：0 = 永久（expiresAt 存 null），
    // 指定天数则从现在起往后推 N 天，到期后该词自动失效。
    final expiresAt = _selectedDays == 0
        ? null
        : DateTime.now().add(Duration(days: _selectedDays));
    await ref
        .read(blockedKeywordsProvider.notifier)
        .add(w, expiresAt: expiresAt);
    widget.onAdded(1, w);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      // 顶部小横条（像系统大爆炸的 grabber）
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          // 给键盘留空间：输入框聚焦时底部不被遮挡
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部小横条
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 标题 + 使用提示
            Text('添加到屏蔽词语清单', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '单击或滑动连选后会自动填入下方输入框，可在输入框再次修改（如补空格）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            // 原始标题（小字、可折叠提示上下文）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.title,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),

            // 词块区域：可滚动（词多时不撑爆弹层）
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              // 整个区域共用一个 Listener 收指针事件：
              // Flutter 的命中测试只在按下瞬间做一次，之后 move 事件不会
              // 派发给「新滑入」的词块，所以必须由这个全局 Listener 统一
              // 接收，再用各词块的全局矩形（_chipRects）查手指压在哪。
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onAreaPointerDown,
                onPointerMove: _onAreaPointerMove,
                onPointerUp: _onAreaPointerUp,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < _tokens.length; i++)
                        _TokenChip(
                          key: _chipKeys[i],
                          label: _tokens[i],
                          selected: _selected.contains(i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 选择状态行：左边提示选了几个词；中间是「屏蔽时长」下拉框
            // （默认永久，可改成指定天数，到期自动失效）；右边「清空」一键重来。
            // 不再显示「将屏蔽：XXX」预览——短语直接在下面的输入框里看。
            Row(
              children: [
                Text(
                  _selected.isEmpty ? '未选择词块' : '已选 ${_selected.length} 个词块',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  '屏蔽时长',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                DropdownButton<int>(
                  value: _selectedDays,
                  // 去掉下拉框默认的下划线，让它更像一个「选项」而不是输入控件
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                  items: [
                    for (final d in _durationChoices)
                      DropdownMenuItem(
                        value: d,
                        child: Text(_durationLabel(d)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDays = v);
                  },
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _selected.isEmpty ? null : _clearSelection,
                  child: const Text('清空'),
                ),
              ],
            ),

            const Divider(height: 24),

            // 底部输入框（唯一的添加入口）：
            // 选中的词块拼出的短语会自动填进来，也可直接输入自定义词；
            // 只有一个「添加」按钮，把输入框内容加进屏蔽列表
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    // 输入内容变化时重建，让「添加」按钮的可用状态实时刷新
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '点选上方词块，或直接输入要屏蔽的词',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addFromInput(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  // 输入框为空时禁用（包括还没选任何词块的情况）
                  onPressed: _inputController.text.trim().isEmpty
                      ? null
                      : _addFromInput,
                  child: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 单个词块：纯展示的小卡片（选中态样式）。
///
/// 不自己监听指针事件：Flutter 的命中测试只在按下瞬间做一次，后续 move 事件
/// 只派发给按下时命中的 widget，滑过的词块收不到事件。所以指针事件由外层
/// 统一接收，再通过 GlobalKey 测出的全局矩形判断手指压在哪个词块上。
class _TokenChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _TokenChip({super.key, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? theme.colorScheme.primary : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: selected ? theme.colorScheme.onPrimary : null,
        ),
      ),
    );
  }
}
