import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:filter_flow/core/error/feed_parse_exception.dart';
import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/services/rss_feed_parser.dart';

/// 把时间点格式化成解析器同款的 "yyyy-MM-dd HH:mm"（本地时区），
/// 让断言不依赖测试机器的时区。
String _fmt(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// 单元测试：RSS/Atom 解析器 + DataSourceConfig 新旧格式兼容。
void main() {
  group('RssFeedParser - Atom', () {
    // 结构对齐阮一峰博客的真实 atom.xml（content type=html 转义、link rel=alternate）
    const atom = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>阮一峰的网络日志</title>
  <entry>
    <title>科技爱好者周刊（第 100 期）</title>
    <link rel="alternate" href="https://www.ruanyifeng.com/blog/2026/01/post-100.html" />
    <id>tag:www.ruanyifeng.com,2026:blog.post.100</id>
    <published>2026-01-02T08:30:00+08:00</published>
    <updated>2026-01-03T09:00:00+08:00</updated>
    <author><name>阮一峰</name></author>
    <content type="html">&lt;p&gt;这里有个 &lt;a href="x"&gt;链接&lt;/a&gt;。&lt;/p&gt;</content>
    <summary>这里有个 &lt;a href="x"&gt;链接&lt;/a&gt;。</summary>
  </entry>
  <entry>
    <title></title>
    <link rel="alternate" href="https://www.ruanyifeng.com/blog/2026/01/empty.html" />
  </entry>
</feed>
''';

    test('解析 Atom 条目并按约定映射字段', () {
      final articles = RssFeedParser.parse(
        XmlDocument.parse(atom),
        sourceId: 'src1',
      );

      // 空标题条目被丢弃
      expect(articles.length, 1);

      final a = articles.first;
      expect(a.sourceId, 'src1');
      expect(a.title, '科技爱好者周刊（第 100 期）');
      expect(a.id, 'tag:www.ruanyifeng.com,2026:blog.post.100');
      expect(a.detailUrl, 'https://www.ruanyifeng.com/blog/2026/01/post-100.html');
      expect(a.author, '阮一峰');
      // content(type=html) 保留原始 HTML，供原生渲染
      expect(a.contentHtml, '<p>这里有个 <a href="x">链接</a>。</p>');
      // summary 去标签压平成纯文本
      expect(a.summary, '这里有个 链接 。');
      // published 优先于 updated，转本地时区后格式化
      expect(
        a.publishTime,
        _fmt(DateTime.parse('2026-01-02T08:30:00+08:00').toLocal()),
      );
    });

    test('无 link 的条目 id 用 title 兜底 md5', () {
      const doc = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry><title>只有标题</title></entry>
</feed>
''';
      final articles = RssFeedParser.parse(
        XmlDocument.parse(doc),
        sourceId: 's',
      );
      expect(articles.first.id, hasLength(32)); // md5 hex
      expect(articles.first.detailUrl, isNull);
    });
  });

  group('RssFeedParser - RSS 2.0', () {
    const rss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
     xmlns:content="http://purl.org/rss/1.0/modules/content/"
     xmlns:dc="http://purl.org/dc/elements/1.1/"
     xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>Demo</title>
    <item>
      <title>第一篇</title>
      <link>https://example.com/1</link>
      <guid isPermaLink="false">guid-001</guid>
      <pubDate>Mon, 01 Sep 2025 10:30:00 +0800</pubDate>
      <dc:creator>张三</dc:creator>
      <content:encoded><![CDATA[<p>正文 <b>加粗</b></p>]]></content:encoded>
      <description>&lt;p&gt;这里是&lt;i&gt;摘要&lt;/i&gt;&lt;/p&gt;</description>
      <media:thumbnail url="https://example.com/thumb.jpg" />
      <enclosure url="https://example.com/audio.mp3" type="audio/mpeg" length="1" />
    </item>
    <item>
      <title>第二篇（无 guid 无图，缩略图取 image enclosure）</title>
      <link>https://example.com/2</link>
      <enclosure url="https://example.com/pic.png" type="image/png" length="1" />
    </item>
  </channel>
</rss>
''';

    test('解析 RSS 2.0 条目（命名空间元素按 local name 匹配）', () {
      final articles = RssFeedParser.parse(
        XmlDocument.parse(rss),
        sourceId: 'src2',
      );
      expect(articles.length, 2);

      final a = articles.first;
      expect(a.id, 'guid-001'); // guid 优先
      expect(a.detailUrl, 'https://example.com/1');
      expect(a.author, '张三'); // dc:creator
      expect(a.contentHtml, '<p>正文 <b>加粗</b></p>'); // content:encoded
      expect(a.summary, '这里是 摘要'); // description 去标签
      expect(a.thumbUrl, 'https://example.com/thumb.jpg'); // media:thumbnail
      expect(
        a.publishTime,
        _fmt(DateTime.utc(2025, 9, 1, 2, 30).toLocal()), // +0800 -> UTC 02:30
      );
    });

    test('无 guid 时 id 退回 link，缩略图退回 image enclosure', () {
      final articles = RssFeedParser.parse(
        XmlDocument.parse(rss),
        sourceId: 'src2',
      );
      final b = articles.last;
      expect(b.id, 'https://example.com/2');
      expect(b.thumbUrl, 'https://example.com/pic.png');
      expect(b.contentHtml, isNull);
    });
  });

  group('RssFeedParser - 容错', () {
    test('不认识的根元素抛 FeedParseException', () {
      expect(
        () => RssFeedParser.parse(
          XmlDocument.parse('<rdf:RDF/>'),
          sourceId: 's',
        ),
        throwsA(isA<FeedParseException>()),
      );
    });

    test('Atom content type=xhtml 取 innerXml 保留结构', () {
      const doc = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>xhtml 正文</title>
    <content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p>段落</p></div></content>
  </entry>
</feed>
''';
      final articles = RssFeedParser.parse(
        XmlDocument.parse(doc),
        sourceId: 's',
      );
      expect(articles.first.contentHtml, contains('<p>段落</p>'));
    });
  });

  group('DataSourceConfig 新旧 JSON 兼容', () {
    test('老 JSON 缺 sourceType -> 默认 json', () {
      final config = DataSourceConfig.fromJson({
        'id': 't',
        'name': 't',
        'apiUrl': 'http://x',
        'fieldMapping': {
          'listPath': 'data.list',
          'titlePath': 'title',
          'thumbPath': 'thumb',
        },
      });
      expect(config.sourceType, DataSourceType.json);
      expect(config.fieldMapping, isNotNull);
    });

    test('RSS JSON 缺 fieldMapping -> null，sourceType=rss 往返一致', () {
      final config = DataSourceConfig.fromJson({
        'id': 'rss1',
        'name': '阮一峰',
        'sourceType': 'rss',
        'apiUrl': 'https://www.ruanyifeng.com/blog/atom.xml',
      });
      expect(config.sourceType, DataSourceType.rss);
      expect(config.fieldMapping, isNull);

      // drift TEXT 列走 toJson/fromJson 往返，枚举须稳定序列化为 'rss'
      final json = config.toJson();
      expect(json['sourceType'], 'rss');
      expect(json['fieldMapping'], isNull);
      expect(
        DataSourceConfig.fromJson(Map<String, dynamic>.from(json)).sourceType,
        DataSourceType.rss,
      );
    });

    test('未知 sourceType 值兜底 json（不崩）', () {
      final config = DataSourceConfig.fromJson({
        'id': 't',
        'name': 't',
        'apiUrl': 'http://x',
        'sourceType': 'whatever',
        'fieldMapping': {
          'listPath': 'a',
          'titlePath': 'b',
          'thumbPath': 'c',
        },
      });
      expect(config.sourceType, DataSourceType.json);
    });
  });
}
