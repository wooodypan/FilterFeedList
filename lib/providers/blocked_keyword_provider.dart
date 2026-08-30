import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import 'core_providers.dart';

/// 屏蔽词状态：管理屏蔽词的加载、添加、删除。
final blockedKeywordsProvider = StateNotifierProvider<BlockedKeywordNotifier,
    AsyncValue<List<String>>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BlockedKeywordNotifier(db);
});

class BlockedKeywordNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final AppDatabase _db;

  BlockedKeywordNotifier(this._db) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = AsyncValue.data(await _db.getAllBlockedKeywords());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 重新从数据库加载（供外部在数据被批量改动后调用，如"导入备份"）。
  Future<void> reload() => _load();

  /// 添加一个屏蔽词（自动去前后空格；空串忽略）
  Future<void> add(String word) async {
    final w = word.trim();
    if (w.isEmpty) return;
    await _db.addBlockedKeyword(w);
    await _load();
  }

  /// 删除一个屏蔽词
  Future<void> remove(String word) async {
    await _db.deleteBlockedKeyword(word);
    await _load();
  }
}
