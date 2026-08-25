import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../core/network/dio_client.dart';
import '../services/feed_repository.dart';

/// 全局数据库实例。
/// 注意：main.dart 里会用 overrideWithValue 把它替换成"已初始化并完成种子数据"的同一个实例，
/// 避免多个地方各自 new AppDatabase() 打开同一个文件。
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// 全局 Dio 实例（统一超时/日志）。
final dioProvider = Provider<Dio>((ref) => DioClient.create());

/// 信息流仓库：组合 dio + 数据库。
final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(dioProvider), ref.watch(appDatabaseProvider)),
);
