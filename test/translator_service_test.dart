import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filter_flow/services/translator_service.dart';

/// 假的 Dio 适配器：不真正联网，直接按请求体里的待翻译文本，
/// 返回 "译_<原文>" 形式的译文，方便验证接入逻辑而不依赖外网。
class _FakeTranslateAdapter implements HttpClientAdapter {
  List<dynamic>? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    // 请求体是 JSON 数组：[[文本数组, 源语言, 目标语言], "te_lib"]
    final decoded = jsonDecode(options.data as String) as List<dynamic>;
    lastRequest = decoded;
    final payload = (decoded[0] as List)[0] as List;
    final translated = payload.map((t) => '译_$t').toList();
    // 响应结构：[[ "译文1", "译文2", ... ]]
    return ResponseBody.fromString(jsonEncode([translated]), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('TranslatorService.translate', () {
    test('批量翻译并按原顺序回填，空文本保持空', () async {
      final dio = Dio()..httpClientAdapter = _FakeTranslateAdapter();
      final svc = TranslatorService(dio);

      final out = await svc.translate(['Hello', '', 'World']);

      expect(out, hasLength(3));
      expect(out[0], '译_Hello');
      expect(out[1], ''); // 空文本不翻译
      expect(out[2], '译_World');
    });

    test('请求体携带正确的源/目标语言', () async {
      final adapter = _FakeTranslateAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final svc = TranslatorService(dio);

      await svc.translate(['A', 'B'], from: 'en', to: 'zh-CN');

      // 请求体第一段为 [文本数组, 源语言, 目标语言]
      final inner = (adapter.lastRequest![0] as List<dynamic>);
      expect(inner[1], 'en');
      expect(inner[2], 'zh-CN');
    });

    test('全部为空时直接原样返回，不发请求', () async {
      final dio = Dio()..httpClientAdapter = _FakeTranslateAdapter();
      final svc = TranslatorService(dio);

      final out = await svc.translate(['', '  ']);
      expect(out, ['', '  ']);
    });
  });
}
