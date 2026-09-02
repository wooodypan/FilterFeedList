import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import 'core_providers.dart';

/// 屏蔽词状态：管理屏蔽词的加载、添加、修改、删除。
///
/// 注意状态里存的是"完整行" [BlockedKeyword]（含 word / expiresAt），
/// 而不只是字符串——这样管理页才能显示每个词的到期时间、是否已过期，
/// 并在修改时把新的词面 / 到期时间一起写回数据库。
final blockedKeywordsProvider =
    StateNotifierProvider<
      BlockedKeywordNotifier,
      AsyncValue<List<BlockedKeyword>>
    >((ref) {
      final db = ref.watch(appDatabaseProvider);
      return BlockedKeywordNotifier(db);
    });

class BlockedKeywordNotifier
    extends StateNotifier<AsyncValue<List<BlockedKeyword>>> {
  final AppDatabase _db;

  BlockedKeywordNotifier(this._db) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      // 用带 expiresAt 的查询，页面才能拿到每个词的到期信息
      state = AsyncValue.data(await _db.getAllBlockedKeywordEntries());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 重新从数据库加载（供外部在数据被批量改动后调用，如"导入备份"）。
  Future<void> reload() => _load();

  /// 添加一个屏蔽词（自动去前后空格；空串忽略）。
  ///
  /// [expiresAt] 不传 = 永久屏蔽；传具体时间 = 只在该时间前生效。
  Future<void> add(String word, {DateTime? expiresAt}) async {
    final w = word.trim();
    if (w.isEmpty) return;
    await _db.addBlockedKeyword(w, expiresAt: expiresAt);
    await _load();
  }

  /// 修改一个屏蔽词：可改词面、可改到期时间（或两者都改）。
  ///
  /// [oldWord] 是原来那一行的词面（定位用）；[newWord] 是新词面。
  Future<void> update(
    String oldWord,
    String newWord,
    DateTime? expiresAt,
  ) async {
    final nw = newWord.trim();
    if (nw.isEmpty) return;
    await _db.updateBlockedKeyword(oldWord, nw, expiresAt: expiresAt);
    await _load();
  }

  /// 删除一个屏蔽词
  Future<void> remove(String word) async {
    await _db.deleteBlockedKeyword(word);
    await _load();
  }
}
