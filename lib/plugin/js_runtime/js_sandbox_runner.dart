import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_js/flutter_js.dart';

import 'js_builtin_libs.dart';

/// JS 沙箱执行器。
///
/// 职责：在**独立的 Isolate**里跑插件脚本，保证哪怕脚本写了死循环，
/// 也只会卡住那个工作 Isolate，不会冻结主 UI 线程。
///
/// 两层超时保护（双保险）：
/// 1. FFI QuickJS 自身的 `timeout`：底层在 JS 跑太久了会直接中断执行并返回异常；
/// 2. Isolate 级超时：万一某脚本卡在引擎之外（理论上极少），主线程等待超时后
///    直接 `Isolate.kill` 强杀工作 Isolate，并抛出 [JsTimeoutException]。
///
/// 安全边界：脚本运行在完全没有网络能力的沙箱里——所有网络 IO 都由 Dart 层
/// 代理执行，JS 只能做纯数据变换（这正是 [createSandboxEngine] 故意不走
/// [getJavascriptRuntime] 的原因：后者会自动启用 fetch）。
class JsSandboxRunner {
  /// 默认单次执行的超时（buildRequest / parseResponse 都很轻量，5s 足够）。
  final Duration defaultTimeout;

  JsSandboxRunner({this.defaultTimeout = const Duration(seconds: 5)});

  /// 在沙箱里调用插件的一个函数，返回它返回值的 Dart 映射（Map / List / 基础类型）。
  ///
  /// [script] 是插件完整 JS 源码；[functionName] 是其中要调用的函数名
  /// （如 `buildRequest` / `parseResponse`）；[args] 是传给该函数的参数列表
  /// （每个参数是一个可被 JSON 序列化的对象，会原样传给 JS）。
  Future<dynamic> callFunction({
    required String script,
    required String functionName,
    required List<Map<String, dynamic>> args,
    Duration? timeout,
  }) async {
    final t = timeout ?? defaultTimeout;
    final port = ReceivePort();
    late final Isolate isolate;

    final completer = Completer<dynamic>();
    late StreamSubscription sub;

    sub = port.listen((message) {
      // message 结构：{'ok': true, 'result': ...} 或 {'ok': false, 'error': '...'}
      sub.cancel();
      port.close();
      isolate.kill();
      if (message is Map && message['ok'] == true) {
        completer.complete(message['result']);
      } else {
        final err = message is Map ? message['error']?.toString() ?? '未知错误' : message.toString();
        completer.completeError(JsSandboxException(err));
      }
    });

    isolate = await Isolate.spawn(
      _sandboxWorker,
      {
        'script': script,
        'functionName': functionName,
        'args': args,
        'timeoutMs': t.inMilliseconds,
        'replyPort': port.sendPort,
      },
    );

    try {
      return await completer.future.timeout(t + const Duration(seconds: 2));
    } on TimeoutException {
      // 第二层保护：强杀工作 Isolate，避免它一直占着资源。
      isolate.kill(priority: Isolate.immediate);
      port.close();
      throw JsTimeoutException(
        '插件脚本执行超时（>${t.inMilliseconds}ms），可能含有死循环，已强制终止。',
      );
    }
  }
}

/// 在独立 Isolate 里跑一次 JS 调用。
///
/// 必须是顶层函数（Isolate.spawn 的要求）。它自己创建引擎、注册内置桥接、
/// eval 用户脚本、调用目标函数，最后把结果（或错误）发回主线程。
void _sandboxWorker(Map<String, dynamic> message) {
  final script = message['script'] as String;
  final functionName = message['functionName'] as String;
  final args = (message['args'] as List).cast<Map<String, dynamic>>();
  final timeoutMs = message['timeoutMs'] as int;
  final SendPort replyPort = message['replyPort'] as SendPort;

  JavascriptRuntime? runtime;
  try {
    runtime = createSandboxEngine(Duration(milliseconds: timeoutMs));

    // 1) 注入内置工具函数（md5/sha1/sha256/hmac/base64，纯 JS 实现，
    //    不依赖 flutter_js 的 bridge——它的回调是 void 签名，拿不到返回值）
    runtime.evaluate(jsBuiltins);
    // 2) 加载用户插件脚本（定义 buildRequest / parseResponse）
    runtime.evaluate(script);

    // 3) 组装调用表达式：把参数 JSON 化后展开传给目标函数，再 JSON.stringify 回来
    final argsLiteral = args.map((a) => jsonEncode(a)).join(', ');
    final expr = 'var __args = [$argsLiteral]; JSON.stringify($functionName(...__args));';
    final result = runtime.evaluate(expr);

    if (result.isError) {
      replyPort.send({'ok': false, 'error': result.stringResult});
      return;
    }

    // JSON.stringify(undefined) 会得到 JS 的 undefined，这里兜底成 null
    final raw = result.stringResult;
    if (raw == 'undefined' || raw.isEmpty) {
      replyPort.send({'ok': true, 'result': null});
      return;
    }
    replyPort.send({'ok': true, 'result': jsonDecode(raw)});
  } catch (e) {
    replyPort.send({'ok': false, 'error': e.toString()});
  } finally {
    runtime?.dispose();
  }
}

/// JS 沙箱执行期的通用异常（如脚本报错、函数未定义、返回格式不对）。
class JsSandboxException implements Exception {
  final String message;
  const JsSandboxException(this.message);
  @override
  String toString() => 'JsSandboxException: $message';
}

/// JS 执行超时（两层保护都没拦住，已强杀 Isolate）。
class JsTimeoutException implements Exception {
  final String message;
  const JsTimeoutException(this.message);
  @override
  String toString() => 'JsTimeoutException: $message';
}
