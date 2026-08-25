import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'providers/core_providers.dart';

void main() async {
  // 初始化 Flutter 绑定（用到原生能力前必须调用）
  WidgetsFlutterBinding.ensureInitialized();

  // 先建好数据库并写入种子数据（示例数据源），保证 app 开箱即有内容。
  // 然后用"同一个实例"覆盖 appDatabaseProvider，避免多处各自打开数据库文件。
  final db = AppDatabase();
  await db.seedIfEmpty();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MyApp(),
    ),
  );
}
