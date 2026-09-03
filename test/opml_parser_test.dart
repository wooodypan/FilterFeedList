import 'package:flutter_test/flutter_test.dart';
import 'package:filter_flow/services/opml_parser.dart';

// 注意：本测试只测纯解析逻辑，不初始化 Widget 绑定，避免触发无头测试环境限制。

/// OPML 解析器的纯逻辑测试（不依赖 UI / 数据库）。
/// 重点覆盖：标准格式、嵌套文件夹、text/title 兼容、url 兜底、非法地址、非 OPML 文件。
void main() {
  test('解析标准 OPML（xmlUrl + text）', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head><title>我的订阅</title></head>
  <body>
    <outline text="阮一峰的网络日志" type="rss" xmlUrl="https://www.ruanyifeng.com/blog/atom.xml" htmlUrl="https://www.ruanyifeng.com/blog/"/>
    <outline title="少数派" xmlUrl="https://sspai.com/feed"/>
  </body>
</opml>''';
    final r = OpmlParser.parse(xml);
    expect(r.valid.length, 2);
    expect(r.valid[0].name, '阮一峰的网络日志');
    expect(r.valid[0].xmlUrl, 'https://www.ruanyifeng.com/blog/atom.xml');
    expect(r.valid[0].htmlUrl, 'https://www.ruanyifeng.com/blog/');
    expect(r.valid[1].name, '少数派');
  });

  test('嵌套文件夹里的订阅也能解析出来', () {
    const xml = '''
<opml version="1.0"><head/><body>
  <outline text="科技" title="科技">
    <outline text="Hacker News" xmlUrl="https://news.ycombinator.com/rss"/>
    <outline text="36氪" xmlUrl="https://36kr.com/feed"/>
  </outline>
</body></opml>''';
    final r = OpmlParser.parse(xml);
    expect(r.folderCount, 1); // 外层"科技"是文件夹（无 xmlUrl）
    expect(r.valid.length, 2);
  });

  test('地址兼容性：大小写 xmlUrl + url 兜底', () {
    const xml = '''
<opml><body>
  <outline text="A" XMLURL="https://a.com/feed"/>
  <outline text="B" url="https://b.com/feed"/>
</body></opml>''';
    final r = OpmlParser.parse(xml);
    expect(r.valid.length, 2);
    expect(r.valid[0].xmlUrl, 'https://a.com/feed');
    expect(r.valid[1].xmlUrl, 'https://b.com/feed');
  });

  test('没有名字时用域名兜底', () {
    const xml = '<opml><body><outline xmlUrl="https://example.com/rss"/></body></opml>';
    final r = OpmlParser.parse(xml);
    expect(r.valid.single.name, 'example.com');
  });

  test('非法地址计入 invalid，不进 valid', () {
    const xml = '''
<opml><body>
  <outline text="坏地址" xmlUrl="ftp://bad"/>
  <outline text="好地址" xmlUrl="https://good.com/feed"/>
</body></opml>''';
    final r = OpmlParser.parse(xml);
    expect(r.valid.length, 1);
    expect(r.invalid, ['ftp://bad']);
  });

  test('非 OPML 文件（根节点不是 opml）抛异常', () {
    const xml = '<rss><channel><title>x</title></channel></rss>';
    expect(() => OpmlParser.parse(xml), throwsA(isA<OpmlParseException>()));
  });

  test('合法 XML 但找不到任何订阅抛异常', () {
    const xml = '<opml><body><outline text="空文件夹"/></body></opml>';
    expect(() => OpmlParser.parse(xml), throwsA(isA<OpmlParseException>()));
  });

  test('非法 XML 抛异常', () {
    const xml = '这不是 xml <<<';
    expect(() => OpmlParser.parse(xml), throwsA(isA<OpmlParseException>()));
  });
}
