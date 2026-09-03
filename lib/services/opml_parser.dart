import 'package:xml/xml.dart';

/// OPML 解析异常：文件不是合法 OPML / 解析失败时使用，文案直接面向用户。
class OpmlParseException implements Exception {
  final String message;
  const OpmlParseException(this.message);
  @override
  String toString() => message;
}

/// 解析出的单个订阅（已归一化为本地模型，还未落库）。
class OpmlFeed {
  /// 展示名（优先 text/title，都没有则用域名兜底）
  final String name;

  /// 订阅地址（一定是合法 http(s)）
  final String xmlUrl;

  /// 网站首页（仅展示用，可为空）
  final String? htmlUrl;

  const OpmlFeed({required this.name, required this.xmlUrl, this.htmlUrl});
}

/// OPML 解析结果：把"能导入的"和"有问题的"分开，方便给用户反馈。
class OpmlParseResult {
  /// 带合法 http(s) 订阅地址的条目（可导入）
  final List<OpmlFeed> valid;

  /// 纯文件夹节点（没有 xmlUrl）数量，统计出来让反馈更准确
  final int folderCount;

  /// 有 xmlUrl 但地址非法的条目（无法导入，反馈用）
  final List<String> invalid;

  const OpmlParseResult({
    required this.valid,
    this.folderCount = 0,
    this.invalid = const [],
  });
}

/// OPML 解析器：只做"读文件文本 → 抽出订阅列表"这一件事（纯函数，易测）。
///
/// 兼容常见阅读器导出（Feedly / Inoreader / 群晖 Note Station / 各类导出）：
/// - 标准 OPML 1.0 / 2.0，根节点 `<opml>`，订阅在 `<body>` 里
/// - 订阅地址在 `xmlUrl` 属性；个别阅读器用 `url`，这里做兜底
/// - 显示名在 `text` 或 `title` 属性；两种都兼容，且大小写不敏感
/// - 文件夹是"没有 xmlUrl 的 outline"，可能无限嵌套；用 findAllElements
///   一次性捞出所有 outline 逐个判断，避免手写递归
/// - 命名空间前缀统一按 local name 匹配，避免 `<opml:opml>` 这类前缀导致误判
class OpmlParser {
  OpmlParser._();

  /// 解析 OPML 文本内容。
  ///
  /// [content] 是整个文件文本；返回 [OpmlParseResult]。
  /// 文件不是 XML、没有 `<opml>` / `<body>`、或一条有效订阅都没有时抛
  /// [OpmlParseException]（文案可直接弹给用户）。
  static OpmlParseResult parse(String content) {
    final doc = _parseXml(content); // 非法 XML 在这里就抛异常
    final root = doc.rootElement;
    // 兼容命名空间前缀：用 local name 判断根节点
    if (root.name.local.toLowerCase() != 'opml') {
      throw const OpmlParseException('这不是 OPML 文件（根节点不是 <opml>）');
    }
    // 找 body：有的导出没有 head，直接 <opml><body>...
    final body = doc.findAllElements('body', namespace: '*').firstOrNull;
    if (body == null) {
      throw const OpmlParseException('OPML 缺少 <body> 节点，无法解析订阅');
    }

    final valid = <OpmlFeed>[];
    final invalid = <String>[];
    var folderCount = 0;

    // 一次性捞出所有 <outline>（含嵌套在文件夹里的），逐个判断是"订阅"还是"文件夹"
    for (final outline in body.findAllElements('outline', namespace: '*')) {
      final attrs = _lowerKeys(outline.attributes);
      final xmlUrl = _firstNonEmpty([attrs['xmlurl'], attrs['url']]);
      if (xmlUrl == null || xmlUrl.trim().isEmpty) {
        // 没有 xmlUrl = 文件夹节点，跳过（顺便统计一下）
        folderCount++;
        continue;
      }
      // 地址必须合法 http(s)，否则计入"无效"反馈，不静默吞掉
      if (!_isHttpUrl(xmlUrl)) {
        invalid.add(xmlUrl.trim());
        continue;
      }
      // 显示名：text > title > 域名兜底
      final rawName = _firstNonEmpty([attrs['text'], attrs['title']]);
      final name = rawName != null && rawName.trim().isNotEmpty
          ? rawName.trim()
          : _hostOf(xmlUrl);
      valid.add(
        OpmlFeed(
          name: name,
          xmlUrl: _normalizeUrl(xmlUrl),
          htmlUrl: attrs['htmlurl']?.trim(),
        ),
      );
    }

    if (valid.isEmpty && invalid.isEmpty && folderCount == 0) {
      throw const OpmlParseException('没有在文件中找到任何订阅源');
    }
    if (valid.isEmpty) {
      throw const OpmlParseException('没有找到可导入的订阅（文件里的地址都不是合法的 http/https 链接）');
    }
    return OpmlParseResult(
      valid: valid,
      folderCount: folderCount,
      invalid: invalid,
    );
  }

  /// 解析 XML，非法时抛 [OpmlParseException]。
  static XmlDocument _parseXml(String content) {
    try {
      return XmlDocument.parse(content);
    } on XmlException catch (e) {
      throw OpmlParseException('文件不是合法的 XML：$e');
    } catch (e) {
      throw OpmlParseException('无法解析文件：$e');
    }
  }

  /// 把属性名统一转小写，兼容 XMLUrl / XmlUrl / xmlUrl 等大小写写法。
  static Map<String, String> _lowerKeys(List<XmlAttribute> attrs) {
    final map = <String, String>{};
    for (final a in attrs) {
      map[a.name.local.toLowerCase()] = a.value;
    }
    return map;
  }

  /// 从一组值里取第一个非空（trim 后）的，用来"text 优先、title 兜底"。
  static String? _firstNonEmpty(List<String?> list) {
    for (final v in list) {
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  /// 判断是否为合法 http/https 链接。
  static bool _isHttpUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// 归一化地址：只去掉首尾空白，不改路径，避免误伤。
  static String _normalizeUrl(String url) => url.trim();

  /// 从地址里取域名，作为"没有名字时"的兜底展示名。
  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.host.isNotEmpty ? uri.host : url;
  }
}
