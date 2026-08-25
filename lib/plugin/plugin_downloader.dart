import 'package:dio/dio.dart';

import 'models/plugin_manifest.dart';

/// 插件下载器：从用户给的 URL 把 JS 插件脚本拉下来，并做基础校验。
///
/// 只负责"下载 + 解析 manifest + 函数存在性检查"，不负责实例化 / 运行。
/// 校验失败会抛 [PluginDownloadException]，安装页据此给用户明确的报错文案。
class PluginDownloader {
  final Dio _dio;

  PluginDownloader(this._dio);

  /// 下载并解析一个插件脚本。
  ///
  /// 返回 [PluginDownloadResult]，包含脚本全文、解析出的 manifest、以及来源 URL。
  Future<PluginDownloadResult> fetch(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const PluginDownloadException('插件地址必须以 http/https 开头');
    }

    late final Response response;
    try {
      // 插件脚本是文本，强制按纯文本接收，避免 dio 当成 JSON 解析。
      response = await _dio.get(
        url.trim(),
        options: Options(responseType: ResponseType.plain),
      );
    } on DioException catch (e) {
      throw PluginDownloadException('下载失败：${e.message}');
    }

    final script = (response.data as String?)?.trim() ?? '';
    if (script.isEmpty) {
      throw const PluginDownloadException('下载到的脚本内容为空');
    }

    // 1) 解析清单注释头（含 @id / @name 校验）
    final manifest = PluginManifest.parse(script);
    // 2) 两个核心函数必须存在（否则根本跑不起来）
    _requireFunction(script, 'buildRequest');
    _requireFunction(script, 'parseResponse');

    return PluginDownloadResult(
      script: script,
      manifest: manifest,
      sourceUrl: url.trim(),
    );
  }

  /// 校验一份插件脚本"是否还能跑"：非空，且必须包含
  /// [buildRequest] / [parseResponse] 两个核心函数。
  ///
  /// 这个方法抽出来，是为了"编辑插件"保存时也能复用和下载时完全一致的校验，
  /// 避免用户改坏脚本（比如删了函数）后装上去却跑不起来。
  /// 校验失败会抛 [PluginDownloadException]，调用方据此提示用户。
  static void validateScript(String script) {
    final trimmed = script.trim();
    if (trimmed.isEmpty) {
      throw const PluginDownloadException('脚本内容不能为空');
    }
    _requireFunction(trimmed, 'buildRequest');
    _requireFunction(trimmed, 'parseResponse');
  }

  /// 检查是否有新版本：用来源 URL 重新拉一次，比对 @version。
  ///
  /// 返回 null 表示无更新（版本相同 / 拉取失败），否则返回远程 manifest。
  Future<PluginManifest?> checkForUpdate(String sourceUrl, String currentVersion) async {
    try {
      final remote = await fetch(sourceUrl);
      if (remote.manifest.version != currentVersion) return remote.manifest;
    } catch (_) {
      // 拉取 / 解析失败就当没更新，不打扰用户
    }
    return null;
  }

  static void _requireFunction(String script, String name) {
    // 宽松匹配：function buildRequest(...) 或 const buildRequest = ...
    final ok = RegExp('(?:function|const|let|var)\\s+$name\\s*[(=]')
        .hasMatch(script);
    if (!ok) {
      throw PluginDownloadException('脚本缺少必要的 $name 函数');
    }
  }
}

/// 一次下载的结果。
class PluginDownloadResult {
  final String script;
  final PluginManifest manifest;
  final String sourceUrl;

  const PluginDownloadResult({
    required this.script,
    required this.manifest,
    required this.sourceUrl,
  });
}

/// 插件下载 / 校验失败。
class PluginDownloadException implements Exception {
  final String message;
  const PluginDownloadException(this.message);
  @override
  String toString() => 'PluginDownloadException: $message';
}
