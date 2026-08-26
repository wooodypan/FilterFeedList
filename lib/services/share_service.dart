import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 分享服务：把「标题 + 链接」以纯文本形式通过系统分享面板发出。
///
/// 使用开源库 [share_plus]（Flutter 官方社区维护的 plus_plugins 之一），
/// 它内部已经封装好各平台的原生分享能力，比手写 MethodChannel 更稳更全：
/// - Android：ACTION_SEND 分享面板
/// - iOS：UIActivityViewController 分享面板
/// - macOS：NSSharingServicePicker 分享面板
/// - Web：Web Share API（不支持时降级为复制）
/// - Windows：系统分享
/// - Linux：share_plus 内部降级为打开邮件客户端（无原生分享面板）
///
/// 仅当原生分享真的抛错（如某平台不可用）时，我们再把文本降级为
/// 「复制到剪贴板」，保证任何平台都能把内容发出去。
class ShareService {
  /// 分享结果：成功唤起系统分享面板
  static const String resultSystem = 'system';

  /// 分享结果：降级复制到了剪贴板
  static const String resultClipboard = 'clipboard';

  /// 分享纯文本（标题 + 链接）。
  ///
  /// [title] 文章标题，[url] 文章链接。两者拼成纯文本：
  ///   标题
  ///   链接
  ///
  /// 返回 [resultSystem] 表示成功唤起系统分享面板；
  /// 返回 [resultClipboard] 表示该平台没有原生分享面板、已把文本复制到剪贴板。
  static Future<String> share({
    required String title,
    required String url,
  }) async {
    // 组装纯文本：有链接就「标题 + 换行 + 链接」，没链接就只有标题
    final text = url.trim().isEmpty ? title : '$title\n$url';

    try {
      // 调起 share_plus 封装好的系统分享面板（跨平台统一 API）
      await SharePlus.instance.share(ShareParams(text: text));
      return resultSystem;
    } on PlatformException {
      // 该平台确实没有可用分享面板（极少数情况）：降级到剪贴板
      await Clipboard.setData(ClipboardData(text: text));
      return resultClipboard;
    }
  }
}
