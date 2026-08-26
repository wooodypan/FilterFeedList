import 'dart:io';

import 'package:dart_jieba/dart_jieba.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// 文字大爆炸的分词工具。
///
/// 一句话思路：把一段标题文字切成一个个"可以单独点选"的词块
/// （中文用 jieba 词典分词，英文/数字按单词，标点单独成块）。
/// 上层 UI 把这些词块渲染成可滑动选择的 chips。
///
/// 为什么不直接用 jieba 的 cut？
/// 1. jieba 初始化需要词典文件（dict.dgz），而它只接受「文件系统路径」，
///    不接受 Flutter 的 asset bundle。所以我们启动时把内置词典从 asset
///    复制到应用的「可写目录」，再用该路径初始化。
/// 2. jieba 万一初始化失败（比如设备异常），不能让整个大爆炸功能挂掉，
///    所以留了一个纯 Dart 的兜底切分（CJK 按字、拉丁按词），保证任何
///    文本都能炸开。
class WordSegmenter {
  /// 单例 jieba 分词器；未初始化成功时为 null，此时走兜底切分。
  static JiebaSegmenter? _segmenter;

  /// 是否已经尝试过初始化（避免重复复制/初始化词典）。
  static bool _initTried = false;

  /// 在 App 启动时调用一次：复制词典并初始化 jieba。
  ///
  /// 失败也不抛异常——只是 [_segmenter] 保持 null，[segment] 会走兜底。
  /// 必须在 [WidgetsFlutterBinding.ensureInitialized] 之后调用
  ///（main 里已经确保），因为用到了 path_provider 和 rootBundle。
  static Future<void> init() async {
    if (_initTried) return; // 幂等：只初始化一次
    _initTried = true;
    try {
      // 1) 拿到应用可写目录（各平台都可用，且路径是真实文件系统路径）
      final dir = await getApplicationDocumentsDirectory();
      final dictFile = File('${dir.path}/jieba_dict.dgz');

      // 2) 第一次才需要把词典从 asset bundle 复制到可写目录
      if (!await dictFile.exists()) {
        final bytes = await rootBundle.load('assets/dict.dgz');
        await dictFile.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      }

      // 3) 用真实文件路径初始化 jieba（File() 能读到的那种）
      final seg = JiebaSegmenter();
      seg.initializeSync(dictPath: dictFile.path);
      _segmenter = seg;
    } catch (e) {
      // 初始化失败不可怕：segment() 会退化为兜底切分，功能仍可用。
      _segmenter = null;
    }
  }

  /// 把一段文字切成词块列表。
  ///
  /// - 有 jieba：优先用 [JiebaSegmenter.cut]（中文按词、英文按单词）。
  /// - 无 jieba（未初始化/异常）：用 [_fallback] 兜底切分。
  static List<String> segment(String text) {
    final t = text.trim();
    if (t.isEmpty) return const [];

    if (_segmenter != null) {
      try {
        final r = _segmenter!.cut(t);
        // 去掉 jieba 可能产出的纯空白块
        final cleaned = r.where((w) => w.trim().isNotEmpty).toList();
        if (cleaned.isNotEmpty) return cleaned;
      } catch (_) {
        // 分词中途异常，退化为兜底
      }
    }
    return _fallback(t);
  }

  /// 兜底切分：不依赖任何词典，纯规则。
  /// - 中日韩统一表意文字：每个字单独成块（中文没有空格，按字最直观）。
  /// - 连续的英文字母/数字：按单词成块。
  /// - 其它字符（标点、空格等）：单独成块。
  ///
  /// 这样即使没有 jieba，用户也能逐字/逐词选择，大爆炸功能不瘫痪。
  static List<String> _fallback(String text) {
    final tokens = <String>[];
    // 三类分别匹配：CJK 单字 | 拉丁数字词 | 其余单字符
    final re = RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff]|[a-zA-Z0-9]+|[^\s]');
    for (final m in re.allMatches(text)) {
      tokens.add(m.group(0)!);
    }
    return tokens;
  }
}
