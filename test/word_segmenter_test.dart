import 'package:flutter_test/flutter_test.dart';

import 'package:filter_flow/utils/word_segmenter.dart';

/// 分词工具的单元测试。
///
/// 注意：未调用 [WordSegmenter.init] 时，[WordSegmenter.segment] 走纯 Dart 兜底切分，
/// 不依赖任何原生词典，因此在普通单元测试里就能稳定验证。
void main() {
  group('WordSegmenter 兜底切分（不依赖 jieba 词典）', () {
    test('空白文本返回空列表', () {
      expect(WordSegmenter.segment('   \n  '), isEmpty);
    });

    test('中文按单字切分', () {
      // 没加载词典时，CJK 每个字单独成块
      expect(WordSegmenter.segment('你好世界'), ['你', '好', '世', '界']);
    });

    test('英文按单词、数字按整体、中文按字', () {
      final r = WordSegmenter.segment('Hello 2024 世界');
      expect(r, ['Hello', '2024', '世', '界']);
    });

    test('返回的词块都不为空', () {
      final r = WordSegmenter.segment('  测试  ABC  ');
      expect(r.every((t) => t.trim().isNotEmpty), isTrue);
    });
  });
}
