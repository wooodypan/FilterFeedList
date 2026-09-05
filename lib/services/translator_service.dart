import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart'; // IOHttpClientAdapter：用于给翻译请求单独挂本机 HTTP 代理
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 从 .env.production 读取密钥，避免硬编码泄露

/// 标题批量翻译服务。
///
/// 背景：用户给数据源的 [FieldMapping] 里把 summaryPath 写成 `title.tttttranslate`，
/// 表示"把每条文章的 title 字段批量翻译成中文"。翻译走 Google 翻译的内部接口
/// （Chrome 扩展同款，请求/响应格式见项目里的 tmp/translate.sh）。
///
/// 标记写法（写在某个路径字段里，token 之前是"要翻译的字段名"）：
///   - `title.tttttranslate`           → 翻译 title 字段，自动检测源语言 → 简体中文
///   - `title.tttttranslate.en.zh-CN`  → 显式指定 英 → 简体中文
///   - `summary.tttttranslate`         → 翻译 summary 字段
/// token 之后若还有两段，就是 源语言.目标语言。
class TranslatorService {
  /// 翻译标记的关键字：路径里出现它，就表示"这个字段要翻译"。
  static const String _translateToken = 'tttttranslate';

  /// 翻译接口地址（Google 翻译内部接口，Chrome 扩展同款）。
  static const String _endpoint =
      'https://translate-pa.googleapis.com/v1/translateHtml';

  /// 接口鉴权 key 的兜底值（来自 tmp/translate.sh 的参考脚本）。
  ///
  /// 注意：这是 Google 翻译的公开代理 key，可能被限流或回收。
  /// 真实项目里应把它放到 `.env.production` 的 `TRANSLATOR_API_KEY` 中，
  /// 由 main.dart 启动时 `dotenv.load` 加载，源码不写死、不提交到 GitLab。
  /// 这里只是"完全没配置时的兜底"，保证 app 不会因缺 key 直接崩。
  static const String _fallbackApiKey = '';

  /// 实际使用的 API key：优先用 .env.production 里的 `TRANSLATOR_API_KEY`，
  /// 没配置（或为空）时回退到 [_fallbackApiKey]。
  ///
  /// 放到 getter 里是因为密钥在 app 启动时（main.dart 的 dotenv.load）才注入，
  /// 不能在类加载阶段就用 const 写死。
  static String get apiKey =>
      (dotenv.env['TRANSLATOR_API_KEY']?.isNotEmpty == true)
      ? dotenv.env['TRANSLATOR_API_KEY']!
      : _fallbackApiKey;

  /// 默认的本机 HTTP 代理地址。
  ///
  /// 给翻译请求单独挂一个本机代理（如 Charles / Fiddler / 翻墙工具），
  /// 便于抓包调试或在不直连的环境下访问翻译接口。
  /// 设为 null 时直连，不影响其它（RSS / 插件）请求。
  static const String defaultProxyUrl = 'http://127.0.0.1:9000';

  /// 注入的全局 Dio（由 Provider 传入，可能还承载着 RSS 等其它请求）。
  final Dio _dio;

  /// 本机 HTTP 代理地址（如 http://127.0.0.1:9000）。
  ///
  /// - 为 null / 空 → 直连，直接复用注入的 [_dio]（保持单元测试可注入 fake adapter）。
  /// - 非 null      → 内部新建一个**独立**的 Dio 专供翻译，并挂上该代理，
  ///   绝不会改动注入的 [_dio]，所以 RSS 抓取、插件下载等其它请求仍走原 Dio。
  final String? proxyUrl;

  /// 实际发翻译请求用的 Dio。
  ///
  /// 构造时根据 [proxyUrl] 决定：
  /// - 无代理 → 直接用注入的 [_dio]；
  /// - 有代理 → 以 [_dio] 的基础配置（超时等）为蓝本，新建一个带代理的 Dio。
  late final Dio _client;

  TranslatorService(this._dio, {this.proxyUrl}) {
    final proxy = proxyUrl?.trim();
    _client = (proxy == null || proxy.isEmpty)
        ? _dio // 直连：复用注入的 Dio（测试时可注入假适配器）
        : _createProxyClient(_dio, proxy); // 走代理：新建独立 Dio，不污染全局
  }

  /// 以 [base] 的配置为蓝本，创建一个挂了 [proxyUrl] 代理的 Dio。
  ///
  /// 关键点：只复制超时等基础配置 + 拦截器，但把网络层换成
  /// [IOHttpClientAdapter] 并在底层 [HttpClient] 上设置 [HttpClient.findProxy]，
  /// 这样所有发往翻译接口的 https 请求都会先 CONNECT 到本机代理。
  static Dio _createProxyClient(Dio base, String proxyUrl) {
    // 代理地址可能带 http:// 前缀，findProxy 只需要 "host:port"
    final hostPort = proxyUrl.replaceFirst(RegExp(r'^https?://'), '');

    final dio = Dio(base.options); // 复制基础配置（连接超时、接收超时等）
    dio.interceptors.addAll(base.interceptors); // 复制拦截器（日志等）
    dio.httpClientAdapter = IOHttpClientAdapter(
      // 如果你要用 Charles/Fiddler 之类做 MITM 抓包解密，需要在 _createProxyClient 的 createHttpClient 里加
      // client.badCertificateCallback = (_, __, ___) => true;
      createHttpClient: () {
        final client = HttpClient();
        // 全部请求都走本机代理；格式是 "PROXY host:port"
        client.findProxy = (_) => 'PROXY $hostPort';
        return client;
      },
    );
    return dio;
  }

  /// 解析翻译标记。
  ///
  /// 返回 null 表示这个路径不是翻译标记（普通 JSONPath，无需翻译）；
  /// 否则返回要翻译的字段名 + 源语言 + 目标语言。
  static ({String field, String from, String to})? parseMarker(String? path) {
    if (path == null || path.isEmpty) return null;
    final parts = path.split('.');
    final idx = parts.indexOf(_translateToken);
    if (idx == -1) return null;

    // token 之后如果还有 源语言.目标语言 两段，就显式指定；否则用默认 auto→zh-CN
    String from = 'auto';
    String to = 'zh-CN';
    if (parts.length - idx - 1 >= 2) {
      from = parts[idx + 1];
      to = parts[idx + 2];
    }

    // token 之前拼回字段路径（字段本身可能含点，例如 data.title）
    final field = parts.sublist(0, idx).join('.');
    if (field.isEmpty) return null;
    return (field: field, from: from, to: to);
  }

  /// 批量翻译一组文本。
  ///
  /// [texts] 为待翻译文本；返回一一对应的译文列表（长度与输入一致）。
  /// 空文本保持为空，不会进入翻译请求。
  ///
  /// 网络/接口异常时**不抛出**，直接回退为原文——保证信息流在翻译失败时
  /// 仍能用（只是没翻译），不会整页崩溃。
  Future<List<String>> translate(
    List<String> texts, {
    String from = 'auto',
    String to = 'zh-CN',
  }) async {
    // 找出非空文本的索引，只对它们发起翻译，空位保持原样
    final nonEmpty = <int>[];
    for (var i = 0; i < texts.length; i++) {
      if (texts[i].trim().isNotEmpty) nonEmpty.add(i);
    }
    if (nonEmpty.isEmpty) return List<String>.from(texts);

    final payload = nonEmpty.map((i) => texts[i]).toList();

    try {
      final resp = await _client.post(
        _endpoint,
        options: Options(
          contentType: 'application/json+protobuf',
          headers: _buildHeaders(),
        ),
        // 请求体结构（见 tmp/translate.sh）：[["待翻译文本数组", 源语言, 目标语言], "te_lib"]
        data: jsonEncode([
          [payload, from, to],
          'te_lib',
        ]),
      );

      final dynamic raw = resp.data;
      final decoded = (raw is String ? jsonDecode(raw) : raw) as List<dynamic>;
      // 响应结构：[[ "译文1", "译文2", ... ]]
      final translated = (decoded[0] as List<dynamic>?) ?? [];

      // 把译文按原索引填回，未翻译的空位保持原文
      final result = List<String>.from(texts);
      for (var k = 0; k < nonEmpty.length; k++) {
        final t = translated.length > k ? translated[k] : null;
        if (t != null) result[nonEmpty[k]] = t.toString();
      }
      return result;
    } on DioException catch (e) {
      // 翻译失败不阻断信息流：回退原文并打日志
      debugPrint('[TranslatorService] 翻译失败，回退原文：$e');
      return List<String>.from(texts);
    } catch (e) {
      debugPrint('[TranslatorService] 翻译失败，回退原文：$e');
      return List<String>.from(texts);
    }
  }

  /// 拼翻译接口需要的请求头（尽量贴近参考脚本，避免被接口拒）。
  static Map<String, String> _buildHeaders() => {
    'content-type': 'application/json+protobuf',
    'x-goog-api-key': apiKey,
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
    'accept': '*/*',
    'accept-language': 'zh-CN,zh;q=0.9',
    'origin': 'chrome-extension://bpoadfkcbjbfhfodiogcnhhhpibjhbnh',
  };
}
