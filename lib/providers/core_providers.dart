import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../core/network/dio_client.dart';
import '../plugin/js_runtime/js_engine_pool.dart';
import '../plugin/js_runtime/js_sandbox_runner.dart';
import '../plugin/plugin_downloader.dart';
import '../plugin/plugin_feed_repository.dart';
import '../plugin/plugin_repository.dart';
import '../services/feed_repository.dart';
import '../services/rss_feed_repository.dart';

/// 全局数据库实例。
/// 注意：main.dart 里会用 overrideWithValue 把它替换成"已初始化并完成种子数据"的同一个实例，
/// 避免多个地方各自 new AppDatabase() 打开同一个文件。
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// 全局 Dio 实例（统一超时/日志）。
final dioProvider = Provider<Dio>((ref) => DioClient.create());

/// 信息流仓库：组合 dio + 数据库（JSONPath 声明式数据源用）。
final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) =>
      FeedRepository(ref.watch(dioProvider), ref.watch(appDatabaseProvider)),
);

/// RSS 订阅源仓库：组合 dio + 数据库（RSS/Atom 订阅数据源用）。
final rssFeedRepositoryProvider = Provider<RssFeedRepository>(
  (ref) =>
      RssFeedRepository(ref.watch(dioProvider), ref.watch(appDatabaseProvider)),
);

// ===================== 插件系统相关 Provider =====================

/// JS 沙箱执行器（每次调用在独立 Isolate 跑，带超时熔断）。
final jsSandboxRunnerProvider = Provider<JsSandboxRunner>(
  (ref) => JsSandboxRunner(),
);

/// JS 引擎池：限制同时运行的沙箱调用数量（避免一次刷新拉起过多 Isolate）。
final jsEnginePoolProvider = Provider<JsEnginePool>(
  (ref) => JsEnginePool(ref.watch(jsSandboxRunnerProvider)),
);

/// 插件下载器：从 URL 拉取并校验 JS 脚本。
final pluginDownloaderProvider = Provider<PluginDownloader>(
  (ref) => PluginDownloader(ref.watch(dioProvider)),
);

/// 已安装插件的本地存储仓库（CRUD）。
final pluginRepositoryProvider = Provider<PluginRepository>(
  (ref) => PluginRepository(ref.watch(appDatabaseProvider)),
);

/// 插件信息流仓库：沙箱算请求 → Dart 发请求 → 沙箱解析 → 过滤。
final pluginFeedRepositoryProvider = Provider<PluginFeedRepository>(
  (ref) => PluginFeedRepository(
    ref.watch(jsEnginePoolProvider),
    ref.watch(dioProvider),
    ref.watch(appDatabaseProvider),
  ),
);
