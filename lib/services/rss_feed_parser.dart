import 'package:xml/xml.dart';

import '../core/error/feed_parse_exception.dart';
import '../models/feed_article.dart';

/// RSS/Atom 订阅源的解析器（自研简化版，贴合本项目"解析逻辑自研"的风格）。
///
/// 支持两大主流格式（自动按根元素识别，不依赖文件名/前缀）：
/// - **Atom**：根元素 `feed`，条目为 `entry`（阮一峰博客、GitHub 等都是这种）
/// - **RSS 2.0**：根元素 `rss`，条目为 `channel > item`（大多数中文博客）
///
/// 设计约定（对齐 [GenericFeedParser] 的容错风格）：
/// - 单条 title 为空的脏数据直接丢弃，避免空白卡片
/// - 缩略图是 best-effort（很多 feed 根本没有图），取不到就用空串，UI 有占位图兜底
/// - 命名空间元素（content:encoded / dc:creator / media:thumbnail）一律按
///   local name 匹配，不写死前缀——不同 feed 对同一语义可能用不同前缀
class RssFeedParser {
  RssFeedParser._();

  /// 把解析好的 XML 文档转换成文章列表。
  ///
  /// [sourceId] 会写进每条 [FeedArticle.sourceId]，聚合模式下靠它反查数据源。
  static List<FeedArticle> parse(XmlDocument doc, {required String sourceId}) {
    // Atom 的根元素名是 feed；RSS 2.0 是 rss。都按 local name 识别，
    // 防止个别 feed 带命名空间前缀（如 <atom:feed>）导致误判。
    final rootName = doc.rootElement.name.local;
    switch (rootName) {
      case 'feed':
        return _parseAtom(doc, sourceId);
      case 'rss':
        return _parseRss2(doc, sourceId);
      default:
        // RSS 1.0 (RDF) 等不认识的格式明确报错，不静默返回空列表
        throw FeedParseException(
          '不是受支持的 RSS/Atom 格式（根元素 "$rootName"，仅支持 feed / rss）',
        );
    }
  }

  // ===================== Atom（feed > entry）=====================

  static List<FeedArticle> _parseAtom(XmlDocument doc, String sourceId) {
    final articles = <FeedArticle>[];
    // namespace: '*' 表示按 local name 匹配（xml 6.x 语义：不给 namespace
    // 参数时是"带前缀的全限定名"全等，反而不命中无前缀元素）
    for (final entry in doc.findAllElements('entry', namespace: '*')) {
      final title = _textOf(entry, 'title');
      // title 为空 -> 丢弃脏数据
      if (title.isEmpty) continue;

      // 链接：优先 rel="alternate"（正文页），没有就取第一个 link
      final link = _atomLink(entry);

      // 正文：content 优先，退回 summary；summary 只当摘要
      final contentEl = _firstElement(entry, 'content');
      final summaryEl = _firstElement(entry, 'summary');
      final contentHtml = contentEl == null ? null : _xmlValue(contentEl);
      final summary =
          summaryEl == null ? null : _stripHtml(_xmlValue(summaryEl));

      // 时间：published 优先（发布时间），退回 updated
      final rawTime = _textOf(entry, 'published').isNotEmpty
          ? _textOf(entry, 'published')
          : _textOf(entry, 'updated');

      // 作者：只认 author 的直接子元素 name，避免 xhtml 正文里同名标签误匹配
      final authorName = entry
          .findElements('author', namespace: '*')
          .firstOrNull
          ?.findElements('name', namespace: '*')
          .firstOrNull;
      final author = authorName == null ? null : _inner(authorName);

      articles.add(FeedArticle(
        id: _textOf(entry, 'id').isNotEmpty
            ? _textOf(entry, 'id')
            : FeedArticle.fallbackId(title, link ?? ''),
        title: title,
        thumbUrl: _atomThumb(entry),
        summary: (summary == null || summary.isEmpty) ? null : summary,
        author: (author == null || author.isEmpty) ? null : author,
        publishTime: _formatTime(rawTime),
        contentHtml: (contentHtml == null || contentHtml.isEmpty)
            ? null
            : contentHtml,
        detailUrl: link,
        sourceId: sourceId,
      ));
    }
    return articles;
  }

  /// Atom 的 <link>：优先 rel="alternate"，否则第一个 <link> 的 href。
  static String? _atomLink(XmlElement entry) {
    final links = entry.findElements('link', namespace: '*').toList();
    for (final link in links) {
      if (link.getAttribute('rel') == 'alternate') {
        return link.getAttribute('href');
      }
    }
    return links.firstOrNull?.getAttribute('href');
  }

  /// Atom 缩略图 best-effort：media:thumbnail / media:content 的 url 属性。
  static String _atomThumb(XmlElement entry) {
    for (final name in const ['thumbnail', 'content']) {
      for (final el in entry.findAllElements(name, namespace: '*')) {
        final url = el.getAttribute('url');
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return '';
  }

  // ===================== RSS 2.0（rss > channel > item）=====================

  static List<FeedArticle> _parseRss2(XmlDocument doc, String sourceId) {
    final articles = <FeedArticle>[];
    for (final item in doc.findAllElements('item', namespace: '*')) {
      final title = _textOf(item, 'title');
      if (title.isEmpty) continue;

      final link = _textOf(item, 'link');

      // 正文：content:encoded 优先（全文输出，保留原始 HTML 供原生渲染）
      final contentEncoded = _firstElement(item, 'encoded');
      final contentHtml =
          contentEncoded == null ? null : _xmlValue(contentEncoded);
      final description = _stripHtml(_textOf(item, 'description'));

      // 作者：author 或 dc:creator（按 local name 'creator' 匹配）
      final author = _textOf(item, 'author').isNotEmpty
          ? _textOf(item, 'author')
          : _textOf(item, 'creator');

      // 唯一 id：guid 优先，退回 link，最后 title 兜底 md5
      final guid = _textOf(item, 'guid');

      articles.add(FeedArticle(
        id: guid.isNotEmpty
            ? guid
            : link.isNotEmpty
                ? link
                : FeedArticle.fallbackId(title, link),
        title: title,
        thumbUrl: _rssThumb(item),
        summary: description.isEmpty ? null : description,
        author: author.isEmpty ? null : author,
        publishTime: _formatTime(_textOf(item, 'pubDate')),
        contentHtml:
            (contentHtml == null || contentHtml.isEmpty) ? null : contentHtml,
        detailUrl: link.isEmpty ? null : link,
        sourceId: sourceId,
      ));
    }
    return articles;
  }

  /// RSS 缩略图 best-effort：
  /// 1. media:thumbnail / media:content 的 url 属性
  /// 2. enclosure 且 type 以 image 开头
  static String _rssThumb(XmlElement item) {
    for (final name in const ['thumbnail', 'content']) {
      for (final el in item.findAllElements(name, namespace: '*')) {
        final url = el.getAttribute('url');
        if (url != null && url.isNotEmpty) return url;
      }
    }
    for (final enclosure in item.findElements('enclosure', namespace: '*')) {
      final type = enclosure.getAttribute('type') ?? '';
      final url = enclosure.getAttribute('url') ?? '';
      if (type.startsWith('image') && url.isNotEmpty) return url;
    }
    return '';
  }

  // ===================== 工具方法 =====================

  /// 取直接子元素中第一个 local name 匹配的元素（命名空间无关）。
  static XmlElement? _firstElement(XmlElement parent, String localName) =>
      parent.findElements(localName, namespace: '*').firstOrNull;

  /// 取直接子元素的文本内容（去首尾空白）。
  static String _textOf(XmlElement parent, String localName) {
    final el = _firstElement(parent, localName);
    return el == null ? '' : _inner(el).trim();
  }

  /// 元素的"值"：普通文本/CDATA 取 innerText，xhtml 内嵌标记取 innerXml
  /// （保留 HTML 结构，交给原生渲染/WebView 处理）。
  static String _xmlValue(XmlElement el) {
    // 有子元素说明是 <content type="xhtml"><div>...</div></content> 这类
    if (el.childElements.isNotEmpty) return el.innerXml;
    return _inner(el);
  }

  /// innerText 的便捷封装（CDATA 也会被包含在内）。
  static String _inner(XmlElement el) => el.innerText;

  /// 去掉 HTML 标签、压平空白，用于摘要展示（原始 HTML 留给详情页）。
  static String _stripHtml(String html) {
    final noTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 时间解析：兼容两种主流格式，统一格式化成 "yyyy-MM-dd HH:mm"。
  /// - Atom：ISO8601，如 2026-01-01T08:00:00+08:00（DateTime.tryParse 原生支持，
  ///   注意显式偏移量时返回的是 UTC 表示，需 toLocal 归一到本地时区再取字段）
  /// - RSS 2.0：RFC822，如 Mon, 01 Jan 2026 08:00:00 +0800（手写解析，
  ///   不用 dart:io 的 HttpDate，避免 web 平台编译问题）
  /// 解析失败原样返回字符串，保证信息不丢。
  static String? _formatTime(String raw) {
    if (raw.isEmpty) return null;

    final dt = (DateTime.tryParse(raw) ?? _tryParseRfc822(raw))?.toLocal();
    if (dt == null) return raw;

    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  /// RFC822 日期解析，如 "Mon, 01 Jan 2026 08:00:00 +0800" / "... GMT"。
  /// 星期和秒都是可选的，时区缺省按 UTC。
  static DateTime? _tryParseRfc822(String raw) {
    final match = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{2,4})\s+'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]{1,5})?',
    ).firstMatch(raw);
    if (match == null) return null;

    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final month = months[match.group(2)!.toLowerCase()];
    if (month == null) return null;

    final day = int.parse(match.group(1)!);
    var year = int.parse(match.group(3)!);
    // 两位年份按 RFC822 惯例补全（<50 归 21 世纪）
    if (year < 100) year += year < 50 ? 2000 : 1900;
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;
    final tz = match.group(7);

    // 显式时区（+0800 之类）要换算回 UTC 时刻；缺省（GMT/未知缩写）按 UTC。
    // DateTime 构造器会自动归一化越界的分/秒（如 minute - 480）。
    var result = DateTime.utc(year, month, day, hour, minute, second);
    if (tz != null && tz.startsWith(RegExp(r'[+-]'))) {
      final sign = tz[0] == '+' ? 1 : -1;
      final offsetMinutes = sign *
          (int.parse(tz.substring(1, 3)) * 60 + int.parse(tz.substring(3, 5)));
      result = result.subtract(Duration(minutes: offsetMinutes));
    }
    return result.toLocal();
  }
}
