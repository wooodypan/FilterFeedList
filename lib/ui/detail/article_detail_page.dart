import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../models/data_source_config.dart';
import '../../models/feed_article.dart';
import '../../services/feed_source.dart';
import '../../services/share_service.dart';
import '../../ui/common/webview_page.dart';

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
      body: source.detailMode == DetailRenderMode.webview
          ? _buildWebViewBody(article.detailUrl)
          : _NativeBody(html: article.contentHtml),
    );
  }

  /// 构建 WebView 正文：没有详情链接时给出友好提示，否则复用通用网页页。
  Widget _buildWebViewBody(String? url) {
    if (url == null || url.isEmpty) {
      return const Center(child: Text('该文章没有可用的详情链接'));
    }
    // 详情页外层已有带分享按钮的 AppBar，这里让通用网页页不要再显示一层标题栏
    return CommonWebViewPage(title: article.title, url: url, showAppBar: false);
  }
}

/// 文章详情的 WebView 渲染已抽取到 [CommonWebViewPage]
/// （lib/ui/common/webview_page.dart），本页直接复用，避免重复维护
/// 导航拦截 / 唤起第三方 App / User-Agent 等逻辑。

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

/// 详情页不再自己维护 User-Agent 逻辑，统一用 [CommonWebViewPage] 提供的
/// [defaultUserAgent]（按运行平台生成合适的 UA）。
