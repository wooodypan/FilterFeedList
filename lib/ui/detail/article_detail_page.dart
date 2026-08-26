import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/data_source_config.dart';
import '../../models/feed_article.dart';
import '../../services/feed_source.dart';

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
      ),
      body: source.detailMode == DetailRenderMode.webview
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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 伪装成 iPhone Safari 的 User-Agent，让网页按 iOS 移动端布局渲染
      ..setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1');
    final url = widget.url;
    if (url != null && url.isNotEmpty) {
      // 带上 Accept-Language，告诉服务器优先返回中文内容
      _controller.loadRequest(
        Uri.parse(url),
        headers: {'Accept-Language': 'zh-CN,zh-Hans;q=0.9'},
      );
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
