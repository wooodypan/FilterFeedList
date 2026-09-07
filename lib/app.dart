import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/data_source_config.dart';
import 'models/feed_article.dart';
import 'providers/feed_settings_provider.dart';
import 'services/deep_link_service.dart';
import 'services/feed_source.dart';
import 'ui/common/webview_page.dart';
import 'ui/detail/article_detail_page.dart';
import 'ui/feed/feed_list_page.dart';
import 'ui/settings/backup_page.dart';
import 'ui/settings/blocked_keyword_page.dart';
import 'ui/settings/data_source_edit_page.dart';
import 'ui/settings/data_source_list_page.dart';
import 'ui/settings/font_settings_page.dart';
import 'ui/settings/opml_import_page.dart';
import 'ui/settings/rss_recommend_config.dart';
import 'ui/settings/rss_source_edit_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/settings/theme_color_page.dart';

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
        path: '/settings/sources/opml-import',
        builder: (context, state) => const OpmlImportPage(),
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
      GoRoute(
        path: '/settings/font',
        builder: (context, state) => const FontSettingsPage(),
      ),
      GoRoute(
        path: '/settings/theme',
        builder: (context, state) => const ThemeColorPage(),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (context, state) => const BackupPage(),
      ),
    ],
  );
});

/// 按「种子色 + 明暗」生成一套完整主题。
///
/// colorSchemeSeed：给 Material3 一个"种子色"，Flutter 自动推导出
/// 完整的一套配色（primary / secondary / 容器色 / 各层背景……）。
/// 所以用户在主题色页只选一个颜色，全 App 的观感就整体跟着变。
///
/// [brightness] 决定这套配色是给浅色还是深色用的——同一个种子色，
/// 传 Brightness.dark 时 Flutter 会自动把主色调亮，保证在黑底上够醒目
/// （深色模式里主色太暗会看不见，这是 Material3 帮我们处理好的）。
ThemeData _buildTheme(Color seed, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: seed,
    brightness: brightness,
  );
}

/// App 根组件。
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // 一次读出全部设置：字体缩放倍数 + 用户选的主题色
    final settings = ref.watch(feedSettingsProvider);

    // 启动深链监听（filterread:// 开头的链接）。
    // watch 是为了让这个 Provider 一直活着（不被自动回收），
    // 服务内部会自己订阅系统的链接流。
    ref.watch(deepLinkServiceProvider);

    // 收到深链请求后，先把用户带到数据源页——
    // 具体的"预填并弹安装对话框"由那个页面自己完成（因为它才有对话框）。
    // 用 listen 而不是在 build 里直接 go：避免在构建过程中触发导航。
    ref.listen<DeepLinkRequest?>(pendingPluginInstallProvider, (_, next) {
      if (next == null) return;
      // 已经停在数据源页了就别再 go：重复导航会重建页面，
      // 可能把用户正在看的内容（比如排序模式）冲掉。
      // 不导航也没关系——页面自己 watch 了这个 Provider，照样会弹框。
      final current = router.routerDelegate.currentConfiguration;
      final here = current.uri.toString();
      if (here != '/settings/sources') router.go('/settings/sources');
    });

    return MaterialApp.router(
      title: '漏斗阅读',
      debugShowCheckedModeBanner: false,
      // 外观模式：跟随系统 / 强制浅色 / 强制深色（用户在设置页的「外观」里选）。
      // ThemeMode.system 时 Flutter 会自己监听系统主题变化并切换，不用我们管。
      themeMode: settings.themeMode,
      // 浅色主题。
      theme: _buildTheme(settings.themeColor, Brightness.light),
      // 深色主题：和浅色用同一个种子色，只是亮度反过来。
      // 两套都给了，Flutter 才能按 themeMode 在它们之间切换；
      // 少了 darkTheme 的话，即使设成 ThemeMode.dark 也只会显示浅色。
      darkTheme: _buildTheme(settings.themeColor, Brightness.dark),
      routerConfig: router,
      // builder 里包一层 MediaQuery，把"字体缩放"作用到全 App 所有文字上。
      // 这样改一处、列表标题/正文/设置页一起变，和微信的字体设置一个效果。
      // 字体页里拖动滑块时 feedSettingsProvider 会更新，这里自动重建、实时预览。
      builder: (context, child) => MediaQuery(
        // 用 TextScaler.linear 线性缩放：1.0 不变，>1 放大，<1 缩小
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(settings.fontScale)),
        child: child!,
      ),
    );
  }
}
