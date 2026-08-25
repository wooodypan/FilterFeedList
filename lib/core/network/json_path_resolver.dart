/// 通用 JSONPath 取值工具（自研简化版）。
///
/// 为什么不用完整的 JSONPath 库？
/// 本项目只需要支持有限语法：
///   - 层级取字段：        "data.list"
///   - 数组取下标：        "data.list[0]"
///   - 混合：              "images[0].url"
///
/// 自己写只需几十行，性能更好、依赖更可控，而且报错信息我们能完全自定义，
/// 方便用户在配置数据源时知道到底是哪一段路径写错了。
class JsonPathResolver {
  /// 按路径字符串从 json 里取值。
  ///
  /// [path] 示例："data.list" / "data.list[0]" / "images[0].url"
  /// 返回取到的任意对象；路径任何一段走不通都返回 null（不抛异常）。
  static dynamic resolve(dynamic json, String path) {
    // 空路径表示"取整个 json 本身"
    if (path.isEmpty) return json;

    dynamic current = json;
    final segments = _tokenize(path);

    for (final seg in segments) {
      if (current == null) return null;

      if (seg.isIndex) {
        // 当前应该是数组，取第 index 项
        if (current is List && seg.index! < current.length) {
          current = current[seg.index!];
        } else {
          // 不是数组或下标越界 -> 取不到
          return null;
        }
      } else {
        // 当前应该是 Map，按键取
        if (current is Map) {
          current = current[seg.key];
        } else {
          return null;
        }
      }
    }
    return current;
  }

  /// 把取值结果安全地转成字符串。
  ///
  /// 取值失败时返回 [fallback]，避免上层拿到 null 还要判空。
  static String resolveAsString(
    dynamic json,
    String? path, {
    String fallback = '',
  }) {
    if (path == null || path.isEmpty) return fallback;
    final v = resolve(json, path);
    if (v == null) return fallback;
    return v.toString();
  }

  /// 把路径字符串切分成一段一段的 token（键 or 数组下标）。
  ///
  /// 例如 "images[0].url" -> [key("images"), index(0), key("url")]
  static List<_PathSegment> _tokenize(String path) {
    final segments = <_PathSegment>[];
    // 先按 "." 分段，每段里可能还嵌着 [下标]
    final parts = path.split('.');
    for (final part in parts) {
      // 正则匹配两种东西：
      //   [^\[\]]+  -> 普通键名（不含方括号）
      //   \[(\d+)\] -> [数字]，表示数组下标
      final regex = RegExp(r'([^\[\]]+)|\[(\d+)\]');
      for (final m in regex.allMatches(part)) {
        if (m.group(1) != null) {
          segments.add(_PathSegment.key(m.group(1)!));
        } else if (m.group(2) != null) {
          segments.add(_PathSegment.index(int.parse(m.group(2)!)));
        }
      }
    }
    return segments;
  }
}

/// 路径里的一段：要么是 Map 的 key，要么是 List 的 index。
class _PathSegment {
  final String? key;
  final int? index;

  bool get isIndex => index != null;

  _PathSegment.key(this.key) : index = null;
  _PathSegment.index(this.index) : key = null;
}
