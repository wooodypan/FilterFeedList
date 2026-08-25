import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/data_source_config.dart';
import 'models/feed_article.dart';
import 'ui/detail/article_detail_page.dart';
import 'ui/feed/feed_list_page.dart';
import 'ui/settings/blocked_keyword_page.dart';
import 'ui/settings/data_source_edit_page.dart';
import 'ui/settings/data_source_list_page.dart';
import 'ui/settings/settings_page.dart';

/// 全局路由表（声明式，go_router）。
/// 详情页通过 extra 把 article + config 对象传过去（内存传参，简单直接）。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FeedListPage(),
      ),
      GoRoute(
        path: '/detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ArticleDetailPage(
            article: extra['article'] as FeedArticle,
            config: extra['config'] as DataSourceConfig,
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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      routerConfig: router,
    );
  }
}
