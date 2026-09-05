import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 通用 WebView 页面。
///
/// 把文章详情页里「加载网页 + 导航拦截 + 唤起第三方 App + 加载完成后注入脚本」
/// 的逻辑抽取到这里，供「RSS 推荐订阅」等任何需要内嵌网页的场景复用。
///
/// 注意（macOS 26 / iOS 26）：只要导航决策最终是「拦截」（prevent/cancel），
/// 控制台就会打印一段以 `WebKit::WebFramePolicyListenerProxy::ignore` 开头的
/// 调用栈。这是 WebKit 自身的回归日志，不是本项目的崩溃
/// （WebKit bug 303093 / rdar://165421759），App 不会闪退，忽略即可。
///
/// 典型用法（见 app.dart 的 /settings/sources/rss-recommend 路由）：
/// ```dart
/// CommonWebViewPage(
///   title: 'RSS 推荐订阅',
///   url: 'https://github.com/...',
///   injectScript: '...',                 // 页面加载完成后执行的 JS
///   jsChannels: {'MyChannel': (msg) => ...}, // JS 通过 MyChannel.postMessage 回传
/// )
/// ```
class CommonWebViewPage extends StatefulWidget {
  final String title;
  final String url;

  /// 页面加载完成后注入执行的 JavaScript（可用于改造页面 DOM，例如给链接加按钮）。
  /// 在 [NavigationDelegate.onPageFinished] 里执行，此时 DOM 已就绪。
  final String? injectScript;

  /// JS 通信通道：key 是通道名（JS 侧用 `通道名.postMessage(...)` 调用），
  /// value 是收到消息后的 Flutter 侧回调。
  final Map<String, void Function(String)>? jsChannels;

  /// 视作「通用链接」、点击时要询问是否唤起第三方 App 的 https 域名白名单。
  /// 留空时所有 https 链接照常在 WebView 内打开（含推荐页这类纯浏览场景）。
  final Set<String> universalLinkHosts;

  /// 是否显示本页自带的 AppBar。
  ///
  /// 默认 true（独立打开网页时用，比如 RSS 推荐页）。
  /// 当本页被外层页面（如 ArticleDetailPage 已经提供了带分享按钮的 AppBar）
  /// 嵌套使用时，传 false 可避免「两层标题栏叠在一起、标题显示两遍」的问题。
  final bool showAppBar;

  const CommonWebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.injectScript,
    this.jsChannels,
    this.universalLinkHosts = const {},
    this.showAppBar = true,
  });

  @override
  State<CommonWebViewPage> createState() => _CommonWebViewPageState();
}

/// WebView 自己就能加载、不该被当成「第三方 App 链接」的内部协议。
///
/// 踩过的坑：很多网页里的 iframe / 懒加载容器用的就是 `about:blank`、
/// `about:srcdoc`，如果不放行，就会莫名其妙弹出「打开第三方 App？」。
const Set<String> _kInternalSchemes = {
  'about', // about:blank / about:srcdoc，iframe 的初始空白页
  'blob', // 前端生成的临时文件地址
  'data', // 内联的 data: 资源
};

class _CommonWebViewPageState extends State<CommonWebViewPage> {
  // WebView 控制器：负责加载 URL、控制 JS 开关、注册通道等
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 按运行平台生成 User-Agent（手机伪装移动端、电脑用桌面 UA）
      ..setUserAgent(defaultUserAgent())
      // 拦截导航：遇到能唤起第三方 App 的链接时，先弹窗征得用户同意
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          // 页面加载完成后再注入脚本：此时 DOM 已就绪，可安全操作页面元素
          onPageFinished: (_) {
            if (widget.injectScript != null) {
              // 注入脚本无需等待完成，忽略其返回的 Future
              // ignore: unawaited_futures
              _controller.runJavaScript(widget.injectScript!);
            }
          },
        ),
      );

    // 注册调用方提供的 JS 通道（必须在 loadRequest 之前注册）
    for (final entry in (widget.jsChannels ?? {}).entries) {
      _controller.addJavaScriptChannel(
        entry.key,
        onMessageReceived: (msg) => entry.value(msg.message),
      );
    }

    final url = widget.url;
    if (url.isNotEmpty) {
      // 带上 Accept-Language，告诉服务器优先返回中文内容
      _controller.loadRequest(
        Uri.parse(url),
        headers: {'Accept-Language': 'zh-CN,zh-Hans;q=0.9'},
      );
    }
  }

  /// 导航拦截：判断这次跳转是否要去「唤起第三方 App」。
  ///
  /// 返回 [NavigationDecision.navigate] 表示照常让 WebView 加载；
  /// 返回 [NavigationDecision.prevent] 表示我们已自行处理（唤起外部 App 或用户取消）。
  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    try {
      final uri = Uri.tryParse(request.url);
      if (uri == null) return NavigationDecision.navigate;

      // 子框架（iframe）里的跳转一律不拦截：一是用户并没有主动点，弹窗很突兀；
      // 二是 iframe 数量多，逐个弹窗会把页面彻底拖死。
      if (!request.isMainFrame) return NavigationDecision.navigate;

      final scheme = uri.scheme.toLowerCase();

      // WebView 自己能加载的内部协议，直接放行
      if (_kInternalSchemes.contains(scheme)) {
        return NavigationDecision.navigate;
      }

      // http(s) 链接：只有命中 Universal Link 白名单的才考虑去唤起 App，
      // 普通网页链接照常在 WebView 里打开。
      if (scheme == 'http' || scheme == 'https') {
        if (!widget.universalLinkHosts.contains(uri.host.toLowerCase())) {
          return NavigationDecision.navigate;
        }
      }

      // 走到这里说明这是要唤起第三方 App 的 deeplink（自定义协议，
      // 或白名单里的 Universal Link）。
      //
      // 关键点：**这里绝对不能 await**。
      // 1) 这个回调在原生侧是 WKWebView 的「策略决策」，await 期间整个
      //    页面会被挂住，用户看到的就是网页卡死；
      // 2) 如果在等待期间页面被销毁 / 又来了新导航，原生侧的回调可能失效，
      //    插件兜底会执行 cancel 决策，macOS 26 上还会打印一段 WebKit 内部
      //    调用栈（WebKit 的已知回归 bug，见下方说明）。
      // 所以：先把决策「预防性地拦下」立刻还给 WebKit，弹窗放到异步任务里做。
      unawaited(_askUserAndOpenApp(request.url));
      return NavigationDecision.prevent;
    } catch (e) {
      // Dart 回调一旦抛异常，插件会把这次导航判成 cancel，页面会白屏。
      // 兜底放行，保证网页至少能正常打开。
      debugPrint('[WebView] 导航拦截异常，放行：$e');
      return NavigationDecision.navigate;
    }
  }

  /// 询问用户是否打开第三方 App；同意后用 url_launcher 唤起外部应用。
  ///
  /// 由 [unawaited] 调用：不阻塞 WebView 的导航决策。
  Future<void> _askUserAndOpenApp(String url) async {
    // 组件可能已销毁（如导航过程中用户返回），先判断再弹窗
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打开第三方 App？'),
        content: Text('即将通过以下链接唤起应用：\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('打开'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      // 用户取消。如果是 http(s) 链接（白名单里的 Universal Link），
      // 因为我们前面已经 prevent 了，这里要主动让它回到 WebView 里继续加载；
      // 自定义协议本来 WebView 也加载不了，什么都不做即可。
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        _controller.loadRequest(uri);
      }
      return;
    }

    try {
      // externalApplication：交给系统去匹配并打开能处理该链接的 App
      // （自定义协议由对应 App 接收；Universal Link 由 iOS 路由到对应 App）
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // 没有安装能处理该链接的 App 时会抛异常，提示用户即可
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开该应用，可能未安装：$url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 被外层页面嵌套（如详情页）时，外层已提供 AppBar，这里就不重复显示了
      appBar: widget.showAppBar ? AppBar(title: Text(widget.title)) : null,
      body: WebViewWidget(controller: _controller),
    );
  }
}

/// 按运行平台生成合适的 WebView User-Agent。
///
/// 目的：让网页按"所在设备的形态"渲染——
/// - 手机上伪装成手机浏览器（移动端布局，优先展示适合小屏的版本）；
/// - 电脑上就用桌面浏览器 UA（桌面布局），而不是写死 iPhone，
///   否则 macOS / Windows 上打开网页会强制显示手机版，体验很差。
///
/// 说明：用 Flutter 的 [defaultTargetPlatform] 判断平台，而不是 dart:io 的
/// Platform——这样 Web 平台也能安全编译（dart:io 在 Web 上不可用）。
String defaultUserAgent() {
  // 三套常用 UA（版本号取自当前主流浏览器，够用即可，不必追求最新）
  const desktopChrome =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  const iphoneSafari =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1';
  const androidChrome =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  // Web 平台拿不到真实设备信息，统一按桌面处理
  if (kIsWeb) return desktopChrome;

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return iphoneSafari;
    case TargetPlatform.android:
      return androidChrome;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      // 桌面端统一用桌面 Chrome UA（macOS 上的 WebView 也按桌面布局展示）
      return desktopChrome;
  }
}
