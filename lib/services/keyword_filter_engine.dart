import '../models/feed_article.dart';

/// 屏蔽词过滤引擎。
///
/// 规则很简单：文章的"标题 + 摘要"里只要包含任意一个屏蔽词，就被过滤掉。
/// 大小写不敏感（都转小写再比）。
class KeywordFilterEngine {
  final List<String> _blockedWords;

  KeywordFilterEngine(this._blockedWords);

  /// 单条文章是否被屏蔽
  bool isBlocked(FeedArticle article) {
    // 把标题和摘要拼起来一起匹配，避免作者名/标题里藏词漏掉
    final text = '${article.title} ${article.summary ?? ''}'.toLowerCase();
    return _blockedWords.any((word) {
      final w = word.toLowerCase().trim();
      return w.isNotEmpty && text.contains(w);
    });
  }

  /// 过滤整批文章，返回不被屏蔽的部分
  List<FeedArticle> filter(List<FeedArticle> articles) {
    return articles.where((a) => !isBlocked(a)).toList();
  }
}
