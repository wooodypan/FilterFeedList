import 'package:flutter_test/flutter_test.dart';

import 'package:filter_flow/core/network/json_path_resolver.dart';
import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/models/field_mapping.dart';
import 'package:filter_flow/services/generic_feed_parser.dart';

/// 单元测试：重点覆盖通用解析引擎（spec 九-5 建议）。
void main() {
  group('JsonPathResolver', () {
    final json = {
      'data': {
        'list': [
          {'title': 'A', 'thumb': 'http://a.png'},
          {'title': 'B'},
        ],
      },
    };

    test('a.b 层级定位数组', () {
      final list = JsonPathResolver.resolve(json, 'data.list');
      expect(list, isA<List>());
      expect((list as List).length, 2);
    });

    test('相对字段取值', () {
      final list = JsonPathResolver.resolve(json, 'data.list') as List;
      expect(JsonPathResolver.resolveAsString(list.first, 'title'), 'A');
    });

    test('缺字段返回兜底空串', () {
      final list = JsonPathResolver.resolve(json, 'data.list') as List;
      expect(JsonPathResolver.resolveAsString(list[1], 'thumb'), '');
    });

    test('数组下标取值', () {
      final json2 = {
        'images': [
          {'url': 'x.png'},
        ],
      };
      expect(JsonPathResolver.resolveAsString(json2, 'images[0].url'), 'x.png');
    });
  });

  group('GenericFeedParser', () {
    test('解析列表并过滤空标题脏数据', () {
      final config = DataSourceConfig(
        id: 't',
        name: 't',
        apiUrl: 'http://x',
        fieldMapping: FieldMapping(
          listPath: 'data.list',
          titlePath: 'title',
          thumbPath: 'thumb',
        ),
      );
      final json = {
        'data': {
          'list': [
            {'title': 'A', 'thumb': 'http://a.png'},
            {'title': ''}, // 空标题，应被过滤
          ],
        },
      };
      final articles = GenericFeedParser.parse(json, config);
      expect(articles.length, 1);
      expect(articles.first.title, 'A');
    });

    test('listPath 取不到数组抛异常', () {
      final config = DataSourceConfig(
        id: 't',
        name: 't',
        apiUrl: 'http://x',
        fieldMapping: FieldMapping(
          listPath: 'data.wrong',
          titlePath: 'title',
          thumbPath: 'thumb',
        ),
      );
      final json = {'data': {'wrong': 'not a list'}};
      expect(() => GenericFeedParser.parse(json, config), throwsA(isA<Exception>()));
    });
  });
}
