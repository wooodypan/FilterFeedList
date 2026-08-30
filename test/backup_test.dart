import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filter_flow/core/db/app_database.dart';
import 'package:filter_flow/models/app_backup.dart';
import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/plugin/models/installed_plugin.dart';
import 'package:filter_flow/plugin/models/plugin_manifest.dart';
import 'package:filter_flow/providers/feed_settings_provider.dart';
import 'package:filter_flow/services/backup_service.dart';

/// 造一个 RSS 数据源配置。
DataSourceConfig _rssConfig(String id, {String name = ''}) => DataSourceConfig(
  id: id,
  name: name.isEmpty ? id : name,
  apiUrl: 'https://example.com/$id.xml',
  sourceType: DataSourceType.rss,
);

/// 造一个已安装插件。
InstalledPlugin _plugin(String id) => InstalledPlugin(
  id: id,
  name: id,
  scriptContent: '// plugin $id',
  manifest: PluginManifest(id: id, name: id, version: '1.0.0'),
  sourceUrl: 'https://example.com/$id.js',
  enabled: true,
  installedAt: DateTime(2026),
  version: '1.0.0',
);

void main() {
  late AppDatabase db;
  late BackupService service;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    service = BackupService(db);
  });

  group('导出', () {
    test('导出内容完整：数据源 / 插件 / 屏蔽词 / 设置都进备份', () async {
      await db.upsertDataSource(_rssConfig('a', name: '源A'));
      await db.upsertInstalledPlugin(_plugin('p1'));
      await db.addBlockedKeywords(['垃圾', '广告']);
      final settings = const FeedSettings(
        aggregateMode: true,
        showThumb: false,
      );

      final backup = await service.exportBackup(settings);

      expect(backup.dataSources.length, 1);
      expect(backup.dataSources.first.config.id, 'a');
      expect(backup.dataSources.first.config.name, '源A');
      expect(backup.plugins.length, 1);
      expect(backup.plugins.first.plugin.id, 'p1');
      expect(backup.blockedKeywords, containsAll(['垃圾', '广告']));
      expect(backup.settings.aggregateMode, isTrue);
      expect(backup.settings.showThumb, isFalse);
    });

    test('导出 -> 编码 -> 解析 -> 导入新库，能原样还原', () async {
      await db.upsertDataSource(_rssConfig('a'));
      await db.upsertInstalledPlugin(_plugin('p1'));
      await db.addBlockedKeywords(['广告']);
      final settings = const FeedSettings(aggregateMode: true);
      final original = await service.exportBackup(settings);

      // 编码成带缩进的 JSON，再解析成一份新备份对象
      final text = BackupService.encode(original);
      final parsed = BackupService.parse(text);

      // 把解析出来的备份导入一个全新的空库
      final db2 = AppDatabase(executor: NativeDatabase.memory());
      final result = await BackupService(
        db2,
      ).importBackup(parsed, mode: ImportMode.replace);

      expect(result.addedSources, 1);
      expect(result.addedPlugins, 1);
      expect(result.addedKeywords, 1);

      final sources = await db2.getAllDataSources();
      final plugins = await db2.getAllInstalledPlugins();
      final keywords = await db2.getAllBlockedKeywords();
      expect(sources.map((c) => c.id), contains('a'));
      expect(plugins.map((p) => p.id), contains('p1'));
      expect(keywords, contains('广告'));

      // 设置也要带过去
      expect(parsed.settings.aggregateMode, isTrue);
    });
  });

  group('解析校验', () {
    test('空内容抛 BackupFormatException', () {
      expect(
        () => BackupService.parse(''),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('非法 JSON 抛 BackupFormatException', () {
      expect(
        () => BackupService.parse('{这不是合法的json'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('顶层不是对象（比如纯数组）抛 BackupFormatException', () {
      expect(
        () => BackupService.parse('[1,2,3]'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('缺少 format 标识（别的 App 的 JSON）抛 BackupFormatException', () {
      expect(
        () => BackupService.parse('{"version":1,"dataSources":[]}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('版本号比当前新（来自更新版 App）抛 BackupFormatException', () {
      const newer =
          '{"format":"filterflow-backup","version":999,"dataSources":[],'
          '"plugins":[],"blockedKeywords":[]}';
      expect(
        () => BackupService.parse(newer),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('导入模式', () {
    test('合并导入：同 id 覆盖、新 id 追加、屏蔽词去重', () async {
      // 本地已有：源 A（老配置）+ 屏蔽词"广告"
      final a = _rssConfig('a', name: '老名字');
      await db.upsertDataSource(a);
      await db.addBlockedKeywords(['广告']);

      // 备份里：源 A（新名字，应覆盖）+ 源 B（新，应追加）+ 屏蔽词"广告"（重复，忽略）
      final backup = AppBackup(
        version: kBackupVersion,
        exportedAt: DateTime.now(),
        settings: const FeedSettings(),
        dataSources: [
          BackupDataSourceEntry(
            config: _rssConfig('a', name: '新名字'),
            sortOrder: 0,
          ),
          BackupDataSourceEntry(config: _rssConfig('b'), sortOrder: 1),
        ],
        plugins: const [],
        blockedKeywords: ['广告', '垃圾'],
      );

      final result = await service.importBackup(backup, mode: ImportMode.merge);

      expect(result.updatedSources, 1, reason: '源A 同名应被覆盖');
      expect(result.addedSources, 1, reason: '源B 应作为新源追加');
      expect(result.addedKeywords, 1, reason: '只有"垃圾"是新增的');

      final sources = await db.getAllDataSources();
      final names = {for (final c in sources) c.id: c.name};
      expect(names['a'], '新名字', reason: '源A 名字应被覆盖成新名字');
      expect(names.containsKey('b'), isTrue);

      final keywords = await db.getAllBlockedKeywords();
      expect(keywords, containsAll(['广告', '垃圾']));
    });

    test('合并导入时新源 Tab 序号不冲突：接续在现有最大序号之后', () async {
      // 本地已有源 A 序号 5
      await db.upsertDataSource(_rssConfig('a'), sortOrder: 5);

      // 备份里带来源 B、C（无本地记录）
      final backup = AppBackup(
        version: kBackupVersion,
        exportedAt: DateTime.now(),
        settings: const FeedSettings(),
        dataSources: [
          BackupDataSourceEntry(config: _rssConfig('b'), sortOrder: 0),
          BackupDataSourceEntry(config: _rssConfig('c'), sortOrder: 1),
        ],
        plugins: const [],
        blockedKeywords: const [],
      );

      await service.importBackup(backup, mode: ImportMode.merge);

      final orders = await db.getAllSortOrders();
      // 新导入的两个源应拿到 6、7（5 之后递增），不重复、不越界
      final newOrders = [orders['b'], orders['c']];
      expect(newOrders, containsAll([6, 7]));
      expect(orders['a'], 5, reason: '已有的源 A 序号不应被改动');
    });

    test('覆盖导入：清空现有全部配置后按备份原样重建', () async {
      // 本地已有脏数据
      await db.upsertDataSource(_rssConfig('old'));
      await db.upsertInstalledPlugin(_plugin('oldP'));
      await db.addBlockedKeywords(['旧词']);

      // 备份只有一份干净的源 A
      final backup = AppBackup(
        version: kBackupVersion,
        exportedAt: DateTime.now(),
        settings: const FeedSettings(aggregateMode: true),
        dataSources: [
          BackupDataSourceEntry(
            config: _rssConfig('a', name: '源A'),
            sortOrder: 2,
          ),
        ],
        plugins: [BackupPluginEntry(plugin: _plugin('p1'), sortOrder: 3)],
        blockedKeywords: ['新词'],
      );

      final result = await service.importBackup(
        backup,
        mode: ImportMode.replace,
      );

      expect(result.addedSources, 1);
      expect(result.addedPlugins, 1);
      expect(result.addedKeywords, 1);

      final sources = await db.getAllDataSources();
      final plugins = await db.getAllInstalledPlugins();
      final keywords = await db.getAllBlockedKeywords();
      // 旧的必须被清掉
      expect(sources.map((c) => c.id), equals(['a']));
      expect(plugins.map((p) => p.id), equals(['p1']));
      expect(keywords, equals(['新词']));

      // 覆盖模式下要还原备份里存的交错 Tab 序号
      final orders = await db.getAllSortOrders();
      expect(orders['a'], 2);
      expect(orders['p1'], 3);
    });
  });
}
