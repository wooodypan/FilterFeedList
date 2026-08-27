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
/// 3) 点「添加选中到屏蔽词」把选中的词按原文顺序「拼成一整段短语」加进屏蔽列表；
///    例如选中「谷 / 饲 / 牛腱」会合并成「谷饲牛腱」一个屏蔽词，而不是拆成三块；
/// 4) 在底部输入框里直接敲一个词，点「添加」立即屏蔽；
/// 5) 点「编辑」可对拼出来的短语做二次编辑——分词往往不含空格，
///    比如选出的词拼出来是「iPhone17Pro」，但你想屏蔽的标准写法带空格
///    「iPhone 17 Pro」，就可以在就地输入框里手动补空格，再添加。
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
      builder:
          (sheetContext) => _TextExplosionContent(
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

  /// 输入框控制器（自定义屏蔽词）
  final TextEditingController _inputController = TextEditingController();

  /// 自定义添加后的瞬时提示文案（清空输入框用）
  String? _justAdded;

  /// 用户「二次编辑」后的短语。
  ///
  /// 例如分词选出的词拼出来是「iPhone17Pro」，但用户想屏蔽的标准写法带空格
  /// 「iPhone 17 Pro」，就可以在「编辑」里手动补空格。编辑后这个值非空，
  /// 添加时优先用它；为 null 表示没编辑过，用按词块拼出的 [_selectedPhrase]。
  /// 注意：一旦用户重新选/取消词块（选中集合变化），这里会重置为 null，
  /// 因为编辑内容是基于旧选择的，已不再适用。
  String? _editedPhrase;

  /// 是否进入「内联编辑」模式。
  ///
  /// 最初用 showDialog 弹窗编辑，但在 Android 上弹窗路由卸载与父组件
  /// setState 重建抢同一帧，会触发 InheritedElement.debugDeactivated 的
  /// _dependents.isEmpty 断言崩溃。因此改为「同一条 bottom sheet 内的输入框」
  /// 直接就地改，彻底避开弹窗路由的生命周期竞态。
  bool _editing = false;

  /// 内联编辑框的控制器（进入编辑模式时把当前短语预填进去）。
  final TextEditingController _editController = TextEditingController();

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
    _editController.dispose();
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
    // 选区一旦开始变化，之前手动编辑过的短语就作废了，重置为空
    setState(() {
      _selected.add(i);
      _editedPhrase = null;
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
      // 滑动连选时选区在变，编辑内容作废
      _editedPhrase = null;
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
      // 单击改变勾选，编辑内容作废
      _editedPhrase = null;
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

  /// 最终用于屏蔽的短语：优先用用户「二次编辑」后的内容 [_editedPhrase]，
  /// 否则用按词块拼出来的原短语 [_selectedPhrase]。
  String get _finalPhrase => _editedPhrase ?? _selectedPhrase;

  /// 把选中的词块「拼成一个短语」加进屏蔽列表。
  ///
  /// 关键改动：不再把每个词块拆成独立屏蔽词，而是把选中的连续词块
  /// 拼成一个完整短语（谷/饲/牛腱 -> 谷饲牛腱），作为「一个」屏蔽词加入，
  /// 避免「谷」单独屏蔽时误伤「谷物」「五谷」等无关词。
  /// 短语优先取用户二次编辑过的版本（可能含手动补的空格）。
  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    final phrase = _finalPhrase;
    if (phrase.isEmpty) return;
    await ref.read(blockedKeywordsProvider.notifier).add(phrase);
    widget.onAdded(1, phrase);
  }

  /// 清空选择，同时把「二次编辑」的内容一并清掉。
  void _clearSelection() {
    setState(() {
      _selected.clear();
      _editedPhrase = null;
    });
  }

  /// 进入「内联编辑」模式：把当前拼好的短语预填进编辑框并切换 UI。
  ///
  /// 不用 showDialog 弹窗（Android 上弹窗路由卸载会与父组件 setState 抢帧，
  /// 触发 _dependents.isEmpty 断言崩溃），而是就地显示输入框。
  void _enterEdit() {
    if (_selected.isEmpty) return;
    // 预填：已经有编辑内容就用编辑过的，否则用原始拼接短语
    _editController.text = _finalPhrase;
    setState(() => _editing = true);
  }

  /// 退出「内联编辑」模式。
  ///
  /// [save] 为 true 时把输入框内容写回 [_editedPhrase]（空字符串等同没编辑，
  /// 记回 null）；为 false 表示取消，丢弃本次输入。
  void _exitEdit({required bool save}) {
    if (save) {
      final trimmed = _editController.text.trim();
      _editedPhrase = trimmed.isEmpty ? null : trimmed;
    }
    setState(() => _editing = false);
  }

  /// 把输入框里的自定义词立即加进屏蔽列表。
  void _addCustom() {
    final w = _inputController.text.trim();
    if (w.isEmpty) return;
    ref.read(blockedKeywordsProvider.notifier).add(w);
    setState(() {
      _justAdded = w;
    });
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selected.length;

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
              '单击词块逐个勾选，或按住滑动连选一段；'
              '选中的词会拼成一个短语加入屏蔽，需要加空格时点「编辑」',
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

            // 中间区域：编辑模式显示就地输入框，否则显示词块 + 操作行
            if (_editing) ...[
              // 内联编辑框：直接就地改短语（避免弹窗路由卸载竞态）
              TextField(
                controller: _editController,
                autofocus: true,
                // 输入时重建本行，让下面的「将屏蔽」预览实时跟随
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '编辑要屏蔽的词',
                  hintText: '可手动加空格，例如 iPhone 17 Pro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editController.text.trim().isEmpty
                          ? '（空，将不添加）'
                          : '将屏蔽：${_editController.text.trim()}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _exitEdit(save: false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _exitEdit(save: true),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ] else ...[
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
              const SizedBox(height: 12),

              // 选中操作行
              Row(
                children: [
                  // 实时预览将要屏蔽的短语（所见即所得）已选 $selectedCount 个
                  // 若用户手动二次编辑过，附上「（已编辑）」标记提示
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? ''
                          : '将屏蔽：$_finalPhrase${_editedPhrase != null ? '（已编辑）' : ''}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 二次编辑：手动补空格等，针对分词不含空格的场景
                  TextButton(
                    onPressed: _selected.isEmpty ? null : _enterEdit,
                    child: const Text('编辑'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _selected.isEmpty ? null : _clearSelection,
                    child: const Text('清空'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('添加'),
                    // 没选东西时禁用
                    onPressed: selectedCount == 0 ? null : _addSelected,
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // 自定义屏蔽词输入框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: '想屏蔽别的词？直接输入',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      // 添加成功后的瞬时提示
                      suffixText: _justAdded == null ? null : '已添加：$_justAdded',
                    ),
                    onSubmitted: (_) => _addCustom(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addCustom, child: const Text('添加')),
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
