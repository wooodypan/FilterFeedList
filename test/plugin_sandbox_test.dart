import 'package:flutter_test/flutter_test.dart';

import 'package:filter_flow/plugin/js_runtime/js_sandbox_runner.dart';

/// 插件沙箱的集成测试。
///
/// 在 macOS / iOS 宿主上运行时会实际创建 JavaScriptCore 引擎，
/// 在 Android / Linux / Windows 上会创建 FFI QuickJS 引擎——
/// 两种引擎都应通过本测试，验证"沙箱里能跑插件脚本"这条核心链路。
void main() {
  // 一段最小可运行的插件脚本：含 buildRequest / parseResponse。
  const pluginScript = '''
function buildRequest(ctx) {
  return {
    url: ctx.url + '?page=' + (ctx.page || 1),
    headers: { 'X-Test': '1' }
  };
}

function parseResponse(resp) {
  var data = JSON.parse(resp.body);
  return data.items.map(function(it) {
    return { id: it.id, title: it.title };
  });
}
''';

  group('JsSandboxRunner', () {
    test('buildRequest 能构造请求', () async {
      final runner = JsSandboxRunner();
      final result = await runner.callFunction(
        script: pluginScript,
        functionName: 'buildRequest',
        args: [
          {'url': 'https://example.com/api', 'page': 2},
        ],
      );
      expect(result, isA<Map>());
      final req = result as Map<String, dynamic>;
      expect(req['url'], 'https://example.com/api?page=2');
      expect(req['headers']['X-Test'], '1');
    });

    test('parseResponse 能把响应解析成列表', () async {
      final runner = JsSandboxRunner();
      final result = await runner.callFunction(
        script: pluginScript,
        functionName: 'parseResponse',
        args: [
          {
            'body': '{"items":[{"id":"1","title":"hello"},{"id":"2","title":"world"}]}',
          },
        ],
      );
      expect(result, isA<List>());
      final list = result as List<dynamic>;
      expect(list.length, 2);
      expect(list.first['title'], 'hello');
    });

    test('脚本报错会以 JsSandboxException 抛出', () async {
      final runner = JsSandboxRunner();
      // 调用一个不存在的函数，应当报错而非崩溃。
      await expectLater(
        runner.callFunction(
          script: pluginScript,
          functionName: 'notExist',
          args: [],
        ),
        throwsA(isA<JsSandboxException>()),
      );
    });
  });
}
