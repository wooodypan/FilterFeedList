/// 信息流解析失败时抛出的异常。
///
/// 和普通的 Exception 区分开，是为了让 UI 层能针对"数据源配置有误"
/// 给出专门提示（而不是笼统地显示"出错了"）。
class FeedParseException implements Exception {
  /// 人类可读的错误描述，例如："listPath 'data.list' 未定位到数组"
  final String message;

  const FeedParseException(this.message);

  @override
  String toString() => 'FeedParseException: $message';
}
