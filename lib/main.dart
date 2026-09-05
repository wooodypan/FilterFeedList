import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 加载 .env.production 里的密钥等配置
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'providers/core_providers.dart';
import 'services/image_cache_manager.dart';
import 'utils/word_segmenter.dart';

void main() async {
  // 初始化 Flutter 绑定（用到原生能力前必须调用）
  WidgetsFlutterBinding.ensureInitialized();

  // 加载环境变量文件（项目根目录的 .env.production，已被 .gitignore 排除，不会入库）。
  // 里面存放 TRANSLATOR_API_KEY 等敏感配置；缺失时 app 会用兜底值，不会崩。
  await dotenv.load(fileName: '.env.production');

  // 初始化图片缓存管理器：从设置里读"保留天数"（默认 2 天）。
  // 必须在任何图片加载前完成，否则会先按默认值建实例、用户配置不生效。
  await FeedImageCacheManager.init();

  // 准备文字大爆炸所需的 jieba 词典（首次复制内置 dict.dgz 到可写目录）。
  // 失败也不致命——没有词典时大爆炸会退化为按字切分。
  await WordSegmenter.init();

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
