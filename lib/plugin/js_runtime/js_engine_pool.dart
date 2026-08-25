import 'dart:async';

import 'js_sandbox_runner.dart';

/// JS 引擎池（并发限制器）。
///
/// 为什么需要它：每次调用都会在独立 Isolate 里起一个 JS 引擎实例，
/// 如果同一时刻大量并发（比如聚合模式下十几个数据源同时刷新），
/// 会瞬间拉起十几个 Isolate，吃内存也吃调度。这里用信号量把"同时在跑的
/// JS 调用"限制在一个上限内，其余排队，既保护了设备又不会让请求乱序。
///
/// 它是 [JsSandboxRunner] 的一层薄封装，对外接口保持一致。
class JsEnginePool {
  final JsSandboxRunner _runner;
  final int maxConcurrent;

  final List<_WaitingCall> _queue = [];
  int _active = 0;

  JsEnginePool(this._runner, {this.maxConcurrent = 4});

  /// 与 [JsSandboxRunner.callFunction] 同签名，但会先获取"执行配额"。
  Future<dynamic> callFunction({
    required String script,
    required String functionName,
    required List<Map<String, dynamic>> args,
    Duration? timeout,
  }) {
    final completer = Completer<dynamic>();
    final call = _WaitingCall(
      script: script,
      functionName: functionName,
      args: args,
      timeout: timeout,
      completer: completer,
    );
    _enqueue(call);
    return completer.future;
  }

  void _enqueue(_WaitingCall call) {
    _queue.add(call);
    _pump();
  }

  void _pump() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final call = _queue.removeAt(0);
      _active++;
      _runner
          .callFunction(
            script: call.script,
            functionName: call.functionName,
            args: call.args,
            timeout: call.timeout,
          )
          .then(call.completer.complete)
          .catchError(call.completer.completeError)
          .whenComplete(() {
        _active--;
        _pump();
      });
    }
  }
}

class _WaitingCall {
  final String script;
  final String functionName;
  final List<Map<String, dynamic>> args;
  final Duration? timeout;
  final Completer<dynamic> completer;

  _WaitingCall({
    required this.script,
    required this.functionName,
    required this.args,
    required this.timeout,
    required this.completer,
  });
}
