import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 已读状态：记录哪些文章被点开过。
///
/// key 用文章的 [FeedArticle.id]（数据源里稳定唯一）。
/// 用 SharedPreferences 持久化（一个简单的字符串 id 列表），
/// 不进 drift 数据库——避免再走一次 schema 迁移，已读这种"辅助标记"也没必要进备份。
final readArticlesProvider =
    StateNotifierProvider<ReadArticlesNotifier, Set<String>>(
      (ref) => ReadArticlesNotifier(),
    );

class ReadArticlesNotifier extends StateNotifier<Set<String>> {
  ReadArticlesNotifier() : super(<String>{}) {
    _load();
  }

  static const _kReadIds = 'read_article_ids';

  /// 启动时从本地把已读 id 读回来。构造函数里直接 await 太重，
  /// 这里用 Future 异步加载，加载完成前 state 是空集合（一切从"未读"开始）。
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kReadIds) ?? const <String>[];
    state = Set<String>.from(ids);
  }

  /// 标记某篇文章为已读。已读过就直接返回，避免无意义的写盘。
  Future<void> markRead(String id) async {
    if (state.contains(id)) return;
    final prefs = await SharedPreferences.getInstance();
    final next = {...state, id};
    await prefs.setStringList(_kReadIds, next.toList());
    state = next;
  }

  /// 判断某篇是否已读（UI 里用来给标题变灰）。
  bool isRead(String id) => state.contains(id);
}
