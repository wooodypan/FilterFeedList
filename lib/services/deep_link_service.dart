import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 本 App 注册的自定义协议名。
///
/// 用户在浏览器里点 `filterread://...` 这样的链接，系统就会唤起本 App，
/// 链接内容由 [DeepLinkService] 接收处理。
/// 协议名必须在各平台的配置文件里同步声明才生效：
/// - Android：`android/app/src/main/AndroidManifest.xml` 的 intent-filter
/// - iOS / macOS：`Runner/Info.plist` 的 CFBundleURLTypes
const String kAppScheme = 'filterread';

/// "添加信息源"这个动作的路径（链接里的 host 部分）。
///
/// 有两个值是因为第一版拼错了（addsouce 少一个 r），
/// 已经有网页在用错拼写的地址了，所以两个都认，避免老链接失效。
/// 新页面建议用拼对的 `addsource`。
const List<String> kAddSourceHosts = <String>['addsouce', 'addsource'];

/// 深链带来的"待安装插件"请求。
///
/// 为什么用一个 Provider 传递，而不是直接把参数塞给页面：
/// 深链可能在 App 冷启动时到达（页面还没创建），也可能在 App 已经打开、
/// 正停在数据源页时到达。用"待处理请求"这个中间状态，两种情况都能统一处理：
/// 页面创建后自己去看有没有待处理的请求，有就弹框。
class DeepLinkRequest {
  /// 插件脚本的下载地址（必填，没有这个就没法装）
  final String url;

  /// 建议的显示名（可为空；为空时让用户自己填，或用插件清单里的名字）
  final String? name;

  const DeepLinkRequest({required this.url, this.name});
}

/// 当前待处理的深链请求。null 表示没有待处理的请求。
///
/// 页面弹完对话框后会把它清回 null，避免重复弹。
final pendingPluginInstallProvider = StateProvider<DeepLinkRequest?>(
  (ref) => null,
);

/// 深链监听服务（整个 App 只创建一份）。
///
/// 在 [MyApp] 里通过 `ref.watch(deepLinkServiceProvider)` 保持存活即可。
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  // start() 是异步的，但这里不需要等它——监听建立后会自己回调。
  // 故意不用 unawaited 包：Provider 的创建函数返回后服务就已经可用。
  service.start();
  // Provider 被销毁时（App 退出）取消监听，避免资源泄漏
  ref.onDispose(service.dispose);
  return service;
});

/// 负责接收系统传进来的深链，解析成具体动作。
///
/// 目前只支持一种：`filterread://addsouce?type=plugin&name=xxx&url=xxx`
/// → 跳到数据源页并弹出"安装插件"对话框，把 url / name 预填好。
class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  StreamSubscription<Uri>? _sub;

  /// 开始监听深链。
  ///
  /// 用 `allUriLinkStream` 而不是 `uriLinkStream`：前者 = "启动 App 的那条链接"
  /// + "之后收到的链接"，一次性覆盖两种场景（冷启动唤起 / App 在后台被唤起），
  /// 省得自己去拼 getInitialAppLink。
  Future<void> start() async {
    final appLinks = AppLinks();
    _sub = appLinks.allUriLinkStream.listen(
      _handleUri,
      // 监听出错不能让 App 崩（比如某些平台不支持某个方法），打日志就行
      onError: (Object e) => debugPrint('[深链] 监听出错：$e'),
      // 不设 cancelOnError：一次出错不该让后续链接再也收不到
      cancelOnError: false,
    );
  }

  /// 解析一条链接，命中已知规则就更新 [pendingPluginInstallProvider]。
  void _handleUri(Uri uri) {
    debugPrint('[深链] 收到：$uri');

    // 1) 协议名不对（不是本 App 的链接）→ 忽略
    if (uri.scheme.toLowerCase() != kAppScheme) return;

    // 2) 路径不是"添加信息源" → 忽略
    if (!kAddSourceHosts.contains(uri.host.toLowerCase())) return;

    // 3) 目前只支持安装插件这一种类型；以后要加 RSS 就在这里多判一个 type
    final type = uri.queryParameters['type']?.toLowerCase();
    if (type != 'plugin') {
      debugPrint('[深链] 暂不支持的 type=$type');
      return;
    }

    // 4) 取参数。url 是必需的，没有就什么都不做
    final url = uri.queryParameters['url']?.trim() ?? '';
    if (url.isEmpty) {
      debugPrint('[深链] 缺少 url 参数，忽略');
      return;
    }

    // name 允许为空（用户可以在对话框里自己填，或装完用清单里的名字）
    final rawName = uri.queryParameters['name']?.trim() ?? '';

    // 5) 把"待安装请求"记下来。数据源页会监听到它并弹对话框。
    _ref.read(pendingPluginInstallProvider.notifier).state = DeepLinkRequest(
      url: url,
      name: rawName.isEmpty ? null : rawName,
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
