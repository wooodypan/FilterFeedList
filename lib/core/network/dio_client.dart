import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// 统一的 Dio 实例工厂。
///
/// 把"超时、日志、默认请求头"这些公共逻辑集中到这里，
/// 后续如果某个数据源需要加签名/鉴权拦截器，也只改这一个地方。
class DioClient {
  /// 创建一个配置好基础能力的 Dio。
  ///
  /// [connectTimeout] / [receiveTimeout] 控制网络等待上限，
  /// 避免某个第三方 API 卡死时整个信息流一直转圈。
  static Dio create({
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        // 默认告诉服务端我们要 JSON；具体数据源仍可在 config 里覆盖 headers
        headers: {
          'Accept': 'application/json',
        },
        // 自动把响应体按 JSON 解析，省得每个地方自己 jsonDecode
        responseType: ResponseType.json,
      ),
    );

    // 日志拦截器：开发期能直接看到请求/响应，方便排查第三方 API 字段结构
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false, // 请求体一般较大，默认不打印
        responseBody: false, // 响应体同理，需要时打开
        logPrint: (o) => Logger().t(o.toString()),
      ),
    );

    return dio;
  }
}
