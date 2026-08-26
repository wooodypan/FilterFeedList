import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/data_source_config.dart';
import '../../models/feed_article.dart';
import '../../services/feed_source.dart';
import '../../services/share_service.dart';

/// 文章详情页。
///
/// 根据数据源的 detailMode 决定渲染方式：
/// - webview：用 WebView 加载详情链接（适合"标题+跳转原文"型 API）
/// - native：用原生 Widget 渲染正文 HTML（适合返回完整正文的 API）
///
/// 参数用统一的 [FeedSource] 抽象：JSONPath 配置源和 JS 插件源都能打开详情。
class ArticleDetailPage extends StatelessWidget {
  final FeedArticle article;
  final FeedSource source;

  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // 右上角分享按钮：把标题 + 链接以纯文本分享出去
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: () async {
              // 调用分享服务；detailUrl 可能为 null，给个空字符串兜底
              final result = await ShareService.share(
                title: article.title,
                url: article.detailUrl ?? '',
              );
              // 组件可能已被销毁（比如分享过程中返回），先判断再弹提示
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result == ShareService.resultClipboard
                        ? '已复制标题和链接到剪贴板' // 没有系统分享面板时
                        : '已唤起系统分享', // 成功唤起系统分享面板
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body:
          source.detailMode == DetailRenderMode.webview
              ? _WebViewBody(url: article.detailUrl)
              : _NativeBody(html: article.contentHtml),
    );
  }
}

/// WebView 模式：加载详情链接
class _WebViewBody extends StatefulWidget {
  final String? url;
  const _WebViewBody({required this.url});

  @override
  State<_WebViewBody> createState() => _WebViewBodyState();
}

class _WebViewBodyState extends State<_WebViewBody> {
  // WebView 控制器：负责加载 URL、控制 JS 开关等
  late final WebViewController _controller;

  // iOS Universal Link 域名白名单：命中这些 https 域名的导航会被当作
  // 「通用链接」处理——询问用户后唤起对应的第三方 App。
  // 不知道要填哪些时留空即可：空集合时 https 链接照常在 WebView 内打开。
  // 例：'open.tmall.com'、'item.jd.com'
  static const Set<String> _universalLinkHosts = {
    // 在这里按需添加需要当作 Universal Link 处理的域名
  };

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          // 按运行平台生成 User-Agent：手机上伪装成手机浏览器（移动端布局），
          // 电脑上就用桌面浏览器 UA（桌面布局），不再写死 iPhone。
          ..setUserAgent(_defaultUserAgent())
          // 拦截导航：遇到能唤起第三方 App 的链接时，先弹窗征得用户同意
          ..setNavigationDelegate(
            NavigationDelegate(onNavigationRequest: _onNavigationRequest),
          );
    final url = widget.url;
    if (url != null && url.isNotEmpty) {
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
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    final scheme = uri.scheme.toLowerCase();
    final isWebScheme = scheme == 'http' || scheme == 'https';

    if (isWebScheme) {
      // 只有命中 Universal Link 白名单的 https 链接，才走「唤起 App」流程；
      // 普通网页链接照常加载。
      if (!_universalLinkHosts.contains(uri.host.toLowerCase())) {
        return NavigationDecision.navigate;
      }
      // 命中白名单：问用户，同意后唤起（prevent），拒绝则继续在 WebView 打开
      final opened = await _askUserAndOpenApp(request.url);
      return opened ? NavigationDecision.prevent : NavigationDecision.navigate;
    }

    // 自定义协议（weixin://、taobao://、myapp:// 等）一律视为
    // 唤起第三方 App 的 deeplink：WebView 本身无法加载这类协议，
    // 所以无论用户是否同意都拦截掉（同意则唤起外部 App，拒绝则什么都不做）。
    await _askUserAndOpenApp(request.url);
    return NavigationDecision.prevent;
  }

  /// 弹窗询问用户是否打开第三方 App；同意后用 url_launcher 唤起外部应用。
  /// 返回 true 表示已成功唤起（或已尝试唤起），false 表示用户取消或唤起失败。
  Future<bool> _askUserAndOpenApp(String url) async {
    // 组件可能已销毁（如导航过程中用户返回），先判断再弹窗
    if (!mounted) return false;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
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
    if (confirm != true) return false;

    try {
      // externalApplication：交给系统去匹配并打开能处理该链接的 App
      // （自定义协议由对应 App 接收；Universal Link 由 iOS 路由到对应 App）
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      // 没有安装能处理该链接的 App 时会抛异常，提示用户即可
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开该应用，可能未安装：$url')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return const Center(child: Text('该文章没有可用的详情链接'));
    }
    return WebViewWidget(controller: _controller);
  }
}

/// 原生渲染模式：把正文 HTML 用原生 Widget 渲染（无广告、可定制样式）
class _NativeBody extends StatelessWidget {
  final String? html;
  const _NativeBody({required this.html});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HtmlWidget(html ?? '<p>无内容</p>'),
    );
  }
}

/// 按运行平台生成合适的 WebView User-Agent。
///
/// 目的：让网页按"所在设备的形态"渲染——
/// - 手机上伪装成手机浏览器（移动端布局，优先展示适合小屏的版本）；
/// - 电脑上就用桌面浏览器 UA（桌面布局），而不是像以前那样写死 iPhone，
///   否则 macOS / Windows 上打开网页会强制显示手机版，体验很差。
///
/// 说明：用 Flutter 的 [defaultTargetPlatform] 判断平台，而不是 dart:io 的
/// Platform——这样 Web 平台也能安全编译（dart:io 在 Web 上不可用）。
String _defaultUserAgent() {
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
