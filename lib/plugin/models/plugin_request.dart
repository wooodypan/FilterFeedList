/// 插件 `buildRequest(ctx)` 的返回值映射。
///
/// JS 沙箱里插件只负责"算出要发什么请求"，真正的网络请求由 Dart 层的 dio 发起
/// （这是安全边界：JS 沙箱里没有网络能力）。所以这个类就是把 JS 返回的对象
/// 安全地翻译成 Dart 能用的请求描述。
class PluginRequest {
  /// 请求地址
  final String url;

  /// 请求方法，默认 GET
  final String method;

  /// 请求头
  final Map<String, String> headers;

  /// query 参数（拼在 URL 后面）
  final Map<String, dynamic> params;

  /// 请求体（POST 等情况）
  final dynamic body;

  const PluginRequest({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.params = const {},
    this.body,
  });

  /// 从 JS 返回的 Map 构造，全程做空值兜底，避免插件返回畸形数据直接崩。
  factory PluginRequest.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    if (url is! String || url.isEmpty) {
      throw const PluginRequestException('buildRequest 未返回合法的 url');
    }

    final headers = <String, String>{};
    if (json['headers'] is Map) {
      (json['headers'] as Map).forEach((k, v) {
        if (k != null) headers[k.toString()] = v?.toString() ?? '';
      });
    }

    final params = <String, dynamic>{};
    if (json['params'] is Map) {
      (json['params'] as Map).forEach((k, v) {
        if (k != null) params[k.toString()] = v;
      });
    }

    final method = (json['method'] as String?)?.toUpperCase() ?? 'GET';

    return PluginRequest(
      url: url,
      method: method,
      headers: headers,
      params: params,
      body: json['body'],
    );
  }
}

/// 请求描述不合法（JS 没按要求返回）。
class PluginRequestException implements Exception {
  final String message;
  const PluginRequestException(this.message);
  @override
  String toString() => 'PluginRequestException: $message';
}
