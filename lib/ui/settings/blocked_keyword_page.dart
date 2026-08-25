import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/blocked_keyword_provider.dart';

/// 屏蔽词管理页：添加 / 删除屏蔽词。
class BlockedKeywordPage extends ConsumerWidget {
  const BlockedKeywordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedKeywordsProvider);

    // 输入框控制器（添加完清空）
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('屏蔽词管理')),
      body: Column(
        children: [
          // 顶部输入区
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
                    onSubmitted: (v) => _add(ref, controller),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _add(ref, controller),
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (words) {
                if (words.isEmpty) {
                  return const Center(child: Text('还没有屏蔽词'));
                }
                return ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, i) {
                    final w = words[i];
                    return ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: Text(w),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除',
                        onPressed: () => ref
                            .read(blockedKeywordsProvider.notifier)
                            .remove(w),
                      ),
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

  void _add(WidgetRef ref, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    ref.read(blockedKeywordsProvider.notifier).add(text);
    controller.clear();
  }
}
