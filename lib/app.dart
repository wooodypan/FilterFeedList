import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/data_source_config.dart';
import 'models/feed_article.dart';
import 'services/feed_source.dart';
import 'ui/common/webview_page.dart';
import 'ui/detail/article_detail_page.dart';
import 'ui/feed/feed_list_page.dart';
import 'ui/settings/blocked_keyword_page.dart';
import 'ui/settings/data_source_edit_page.dart';
import 'ui/settings/data_source_list_page.dart';
import 'ui/settings/rss_recommend_config.dart';
import 'ui/settings/rss_source_edit_page.dart';
import 'ui/settings/settings_page.dart';

/// 全局路由表（声明式，go_router）。
/// 详情页通过 extra 把 article + config 对象传过去（内存传参，简单直接）。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const FeedListPage()),
      GoRoute(
        path: '/detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ArticleDetailPage(
            article: extra['article'] as FeedArticle,
            source: extra['source'] as FeedSource,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/sources',
        builder: (context, state) => const DataSourceListPage(),
      ),
      GoRoute(
        path: '/settings/sources/edit',
        builder: (context, state) => DataSourceEditPage(
          // 编辑时把整份配置通过 extra 传进来
          initial: state.extra as DataSourceConfig?,
        ),
      ),
      GoRoute(
        path: '/settings/sources/rss-edit',
        builder: (context, state) {
          final extra = state.extra;
          // 兼容两种传参：
          // - DataSourceConfig：来自列表的「编辑」（整份配置）
          // - String：来自「推荐订阅」页的「导入」（仅预填 feed 地址，名字让用户自己填）
          if (extra is DataSourceConfig) {
            return RssSourceEditPage(initial: extra);
          }
          if (extra is String) {
            return RssSourceEditPage(presetUrl: extra);
          }
          return const RssSourceEditPage();
        },
      ),
      GoRoute(
        path: '/settings/sources/rss-recommend',
        builder: (context, state) => CommonWebViewPage(
          title: 'RSS 推荐订阅',
          url: kRssRecommendUrl,
          // 加载完成后注入脚本：给所有「文本以 http 开头」的链接右侧加「导入」按钮
          injectScript: kRssRecommendInjectScript,
          // JS 点「导入」时通过此通道把链接回传 Flutter，再跳到编辑页预填
          jsChannels: {
            'ImportRssChannel': (url) {
              context.push('/settings/sources/rss-edit', extra: url);
            },
          },
        ),
      ),
      GoRoute(
        path: '/settings/blocked',
        builder: (context, state) => const BlockedKeywordPage(),
      ),
    ],
  );
});

/// App 根组件。
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '漏斗阅读',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      routerConfig: router,
    );
  }
}
