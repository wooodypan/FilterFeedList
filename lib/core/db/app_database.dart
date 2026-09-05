import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/data_source_config.dart';
import '../../models/field_mapping.dart';
import '../../plugin/models/installed_plugin.dart';
import '../../plugin/models/plugin_manifest.dart';
import 'tables/blocked_keyword_table.dart';
import 'tables/data_source_table.dart';
import 'tables/installed_plugin_table.dart';

part 'app_database.g.dart';

/// 全局数据库。
///
/// 三张表：数据源配置（DataSources）、屏蔽词（BlockedKeywords）、已安装插件（InstalledPlugins）。
/// 使用 drift 的 LazyDatabase + NativeDatabase：第一次真正访问时才创建文件，
/// 避免在 app 启动早期就碰文件系统。
@DriftDatabase(tables: [DataSources, BlockedKeywords, InstalledPlugins])
class AppDatabase extends _$AppDatabase {
  /// 默认的构造函数：自动在"应用文档目录"下建一个 sqlite 文件。
  /// [executor] 可选，供测试注入内存数据库（NativeDatabase.memory()），
  /// 生产代码一律不传、走默认文件连接。
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  /// 迁移策略：只在"加列"这种向后兼容的结构变更时升级。
  ///
  /// 全新安装时由 drift 自动 createAll() 建好全部表（含新列），不走这里；
  /// 老用户升级时才触发 onUpgrade。
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      // v2 -> v3：给两张表各加一个 Tab 排序序号列。
      // addColumn 要求列有默认值或可为空，sortOrder 默认 0，满足条件；
      // 老数据全部落在 0，首次拖动排序后就会被重新编号。
      if (from < 3) {
        await migrator.addColumn(dataSources, dataSources.sortOrder);
        await migrator.addColumn(installedPlugins, installedPlugins.sortOrder);
      }
      // v3 -> v4：给屏蔽词表加 expiresAt（屏蔽到期时间）列。
      // 该列可空，老数据默认就是 NULL —— 即「永久屏蔽」，符合要求，
      // 所以这里不需要再写 UPDATE 把老数据回填成"永久"。
      if (from < 4) {
        await migrator.addColumn(blockedKeywords, blockedKeywords.expiresAt);
      }
      // v4 -> v5：给插件表加 useAppDeepLink（App 深链直达开关）列。
      // 该列有默认值 true，老插件升级后默认开启，符合"默认开启"的预期。
      if (from < 5) {
        await migrator.addColumn(
          installedPlugins,
          installedPlugins.useAppDeepLink,
        );
      }
    },
  );

  /// 懒加载连接：拿到应用文档目录后，把数据库文件放在那里。
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/filter_flow.sqlite');
      return NativeDatabase(file);
    });
  }

  // ===================== 数据源相关 DAO =====================

  /// 查出所有数据源（按名称排序）
  Future<List<DataSourceConfig>> getAllDataSources() async {
    final rows = await select(dataSources).get();
    return rows.map((r) => r.config).toList();
  }

  /// 根据 id 查单个数据源
  Future<DataSourceConfig?> getDataSourceById(String id) async {
    final row = await (select(
      dataSources,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.config;
  }

  /// 查出数据源的原始行（含 sortOrder 等表字段，导出备份时需要）。
  Future<List<DataSourcesRow>> getAllDataSourceRows() {
    return select(dataSources).get();
  }

  /// 插入或更新（id 相同就覆盖）。
  ///
  /// [sortOrder] 显式指定 Tab 序号时直接用它（导入备份要靠它还原用户排好的顺序）；
  /// 不传时走默认策略：已存在的源沿用原序号（否则改个名字就被挤到末尾），
  /// 新增的源排到所有 Tab 的最后一位。
  Future<void> upsertDataSource(
    DataSourceConfig config, {
    int? sortOrder,
  }) async {
    // 只在没有显式指定序号时才需要查旧值，省一次数据库查询
    final existingRow = sortOrder == null
        ? await (select(
            dataSources,
          )..where((t) => t.id.equals(config.id))).getSingleOrNull()
        : null;

    await into(dataSources).insertOnConflictUpdate(
      DataSourcesCompanion.insert(
        // .insert 工厂里 id/name/config 是"原始类型"，不是 Value 包裹
        id: config.id,
        name: config.name,
        enabled: Value(config.enabled),
        config: config,
        sortOrder: Value(
          sortOrder ?? existingRow?.sortOrder ?? await _nextSortOrder(),
        ),
      ),
    );
  }

  /// 删除所有数据源（导入备份的"覆盖"模式用，配合事务保证可回滚）。
  Future<int> clearAllDataSources() {
    return delete(dataSources).go();
  }

  /// 批量插入多个数据源（OPML 导入用）。
  ///
  /// 新源统一排到所有现有 Tab 的最后一位（用现有最大序号递增），
  /// 避免和已有源抢位置。id 相同则覆盖（insertOnConflictUpdate）。
  /// 一次 batch 写完，比循环调用 [upsertDataSource] 少 N 次刷新、更快。
  Future<void> insertDataSources(List<DataSourceConfig> configs) async {
    if (configs.isEmpty) return;
    // 取出现有最大序号，新源在它后面依次排开
    final existing = await select(dataSources).get();
    final maxOrder = existing.fold(
      0,
      (int m, r) => r.sortOrder > m ? r.sortOrder : m,
    );
    await batch((b) {
      for (var i = 0; i < configs.length; i++) {
        final c = configs[i];
        b.insert(
          dataSources,
          DataSourcesCompanion.insert(
            id: c.id,
            name: c.name,
            enabled: Value(c.enabled),
            config: c,
            sortOrder: Value(maxOrder + 1 + i),
          ),
        );
      }
    });
  }

  // ===================== Tab 排序序号相关 DAO =====================

  /// 读出所有源（数据源 + 插件）的 Tab 排序序号，合并成 id -> 序号 的映射。
  ///
  /// 两表共用一套全局编号，所以合在一起即可还原出用户排好的交错顺序。
  Future<Map<String, int>> getAllSortOrders() async {
    final sourceRows = await select(dataSources).get();
    final pluginRows = await select(installedPlugins).get();
    return {
      for (final r in sourceRows) r.id: r.sortOrder,
      for (final r in pluginRows) r.id: r.sortOrder,
    };
  }

  /// 批量写回数据源的 Tab 序号。
  ///
  /// 用 batch 把多条 UPDATE 打包成一次数据库往返，比逐条 await 更快。
  Future<void> updateDataSourceSortOrders(Map<String, int> idToOrder) async {
    if (idToOrder.isEmpty) return;
    await batch((b) {
      for (final entry in idToOrder.entries) {
        b.update(
          dataSources,
          DataSourcesCompanion(sortOrder: Value(entry.value)),
          where: (t) => t.id.equals(entry.key),
        );
      }
    });
  }

  /// 批量写回插件的 Tab 序号（同 [updateDataSourceSortOrders]）。
  Future<void> updatePluginSortOrders(Map<String, int> idToOrder) async {
    if (idToOrder.isEmpty) return;
    await batch((b) {
      for (final entry in idToOrder.entries) {
        b.update(
          installedPlugins,
          InstalledPluginsCompanion(sortOrder: Value(entry.value)),
          where: (t) => t.id.equals(entry.key),
        );
      }
    });
  }

  /// 下一个可用的 Tab 序号（当前最大序号 + 1），让新增的源排在最后。
  ///
  /// 两张表都没有记录时返回 0，避免第一个源从 1 开始。
  Future<int> _nextSortOrder() async {
    final orders = await getAllSortOrders();
    if (orders.isEmpty) return 0;
    // 只在"有记录"时取最大值；删除源留下的序号空洞不影响排序（只比大小）
    return orders.values.reduce(max) + 1;
  }

  /// 删除某个数据源
  Future<int> deleteDataSource(String id) {
    return (delete(dataSources)..where((t) => t.id.equals(id))).go();
  }

  /// 切换启用状态
  Future<void> setEnabled(String id, bool enabled) {
    return (update(dataSources)..where((t) => t.id.equals(id))).write(
      DataSourcesCompanion(enabled: Value(enabled)),
    );
  }

  // ===================== 屏蔽词相关 DAO =====================

  /// 查出所有屏蔽词（按添加时间倒序），返回纯字符串列表。
  ///
  /// 注意：这里**不做过期过滤**——导出备份、单测断言等场景需要"全部词"，
  /// 包括已经过期的（备份时当作永久词看待）。真正给过滤引擎用的
  /// 「只取未过期的词」请见 [getActiveBlockedKeywords]。
  Future<List<String>> getAllBlockedKeywords() async {
    final rows = await (select(
      blockedKeywords,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
    return rows.map((r) => r.word).toList();
  }

  /// 只返回"当前仍然生效"的屏蔽词字符串列表，供三个信息流仓库做过滤用。
  ///
  /// 生效判定：expiresAt 为 NULL（永久）或 仍晚于当前时间（未过期）。
  /// 已过期但还躺在库里的词不会进入结果，从而自动失效。
  Future<List<String>> getActiveBlockedKeywords() async {
    final now = DateTime.now();
    final rows = await (select(
      blockedKeywords,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
    return rows
        .where((r) => r.expiresAt == null || r.expiresAt!.isAfter(now))
        .map((r) => r.word)
        .toList();
  }

  /// 查出所有屏蔽词完整行（含 expiresAt），按添加时间倒序，给管理页展示用。
  ///
  /// 返回的是 drift 自动生成的数据类 [BlockedKeyword]，自带
  /// id / word / createdAt / expiresAt 四个字段；页面据此判断"是否已过期"。
  Future<List<BlockedKeyword>> getAllBlockedKeywordEntries() async {
    return (select(
      blockedKeywords,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// 监听屏蔽词变化（UI 自动刷新）
  Stream<List<String>> watchBlockedKeywords() {
    return (select(blockedKeywords)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map((r) => r.word).toList());
  }

  /// 添加一个屏蔽词（重复添加会忽略）。
  ///
  /// [expiresAt] 为 NULL 表示永久屏蔽（默认）；传具体时间则表示只在该时间前生效。
  Future<void> addBlockedKeyword(String word, {DateTime? expiresAt}) {
    return into(blockedKeywords).insertOnConflictUpdate(
      BlockedKeywordsCompanion.insert(word: word, expiresAt: Value(expiresAt)),
    );
  }

  /// 修改一个屏蔽词：可以改词面，也可以改到期时间（或两者都改）。
  ///
  /// [oldWord] 是要改的那一行的原词面（因为 word 是定位键）；
  /// [newWord] 是新词面；[expiresAt] 为新到期时间（NULL=永久）。
  /// 内部用 UPDATE ... WHERE word = oldWord 实现，不删不插、不丢 createdAt。
  Future<int> updateBlockedKeyword(
    String oldWord,
    String newWord, {
    DateTime? expiresAt,
  }) {
    return (update(
      blockedKeywords,
    )..where((t) => t.word.equals(oldWord))).write(
      BlockedKeywordsCompanion(
        word: Value(newWord),
        expiresAt: Value(expiresAt),
      ),
    );
  }

  /// 批量添加屏蔽词（导入备份用；已存在的会被忽略，不会重复）。
  ///
  /// 导入的词一律当作"永久屏蔽"（expiresAt 不传 = NULL），保持备份格式不变。
  Future<void> addBlockedKeywords(List<String> words) async {
    if (words.isEmpty) return;
    await batch((b) {
      for (final w in words) {
        b.insert(
          blockedKeywords,
          BlockedKeywordsCompanion.insert(word: w),
          // 已存在就跳过（word 列有唯一约束，硬插会抛异常）
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// 删除所有屏蔽词（导入备份的"覆盖"模式用）。
  Future<int> clearAllBlockedKeywords() {
    return delete(blockedKeywords).go();
  }

  /// 删除一个屏蔽词
  Future<int> deleteBlockedKeyword(String word) {
    return (delete(blockedKeywords)..where((t) => t.word.equals(word))).go();
  }

  // ===================== 已安装插件相关 DAO =====================

  /// 查出所有已安装插件（按安装时间倒序）。
  Future<List<InstalledPlugin>> getAllInstalledPlugins() async {
    final rows = await (select(
      installedPlugins,
    )..orderBy([(t) => OrderingTerm.desc(t.installedAt)])).get();
    return rows.map(rowToInstalledPlugin).toList();
  }

  /// 根据 id 查单个插件。
  Future<InstalledPlugin?> getInstalledPluginById(String id) async {
    final row = await (select(
      installedPlugins,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : rowToInstalledPlugin(row);
  }

  /// 插入或更新（id 相同就覆盖脚本 / 清单）。
  ///
  /// [sortOrder] 语义同 [upsertDataSource]：显式传就按它写，
  /// 不传则已安装的沿用原序号、新装的排到最后。
  Future<void> upsertInstalledPlugin(
    InstalledPlugin plugin, {
    int? sortOrder,
  }) async {
    // 同 upsertDataSource：只在没有显式指定序号时才查旧值
    final existingRow = sortOrder == null
        ? await (select(
            installedPlugins,
          )..where((t) => t.id.equals(plugin.id))).getSingleOrNull()
        : null;

    await into(installedPlugins).insertOnConflictUpdate(
      InstalledPluginsCompanion.insert(
        id: plugin.id,
        name: plugin.name,
        scriptContent: plugin.scriptContent,
        manifestJson: jsonEncode(plugin.manifest.toJson()),
        sourceUrl: plugin.sourceUrl,
        enabled: Value(plugin.enabled),
        useAppDeepLink: Value(plugin.useAppDeepLink),
        // 注意：installedAt 没有默认值，.insert 工厂要求传原始 DateTime，
        // 不需要 Value() 包裹（enabled 有默认值才需要 Value）
        installedAt: plugin.installedAt,
        version: plugin.version,
        sortOrder: Value(
          sortOrder ?? existingRow?.sortOrder ?? await _nextSortOrder(),
        ),
      ),
    );
  }

  /// 查出已安装插件的原始行（含 sortOrder 等表字段，导出备份时需要）。
  Future<List<InstalledPluginsRow>> getAllPluginRows() {
    return select(installedPlugins).get();
  }

  /// 删除所有已安装插件（导入备份的"覆盖"模式用）。
  Future<int> clearAllPlugins() {
    return delete(installedPlugins).go();
  }

  /// 删除插件。
  Future<int> deleteInstalledPlugin(String id) {
    return (delete(installedPlugins)..where((t) => t.id.equals(id))).go();
  }

  /// 切换启用状态。
  Future<void> setPluginEnabled(String id, bool enabled) {
    return (update(installedPlugins)..where((t) => t.id.equals(id))).write(
      InstalledPluginsCompanion(enabled: Value(enabled)),
    );
  }

  /// 把数据库行（含 manifestJson 列）组装成 [InstalledPlugin]。
  /// 注意：row 的类型是 InstalledPluginsRow（drift 生成），
  /// 不是手写的 InstalledPlugin 模型——两者是不同类，见 installed_plugin_table.dart 的说明。
  InstalledPlugin rowToInstalledPlugin(InstalledPluginsRow row) {
    final manifest = PluginManifest.fromJson(
      jsonDecode(row.manifestJson) as Map<String, dynamic>,
    );
    return InstalledPlugin(
      id: row.id,
      name: row.name,
      scriptContent: row.scriptContent,
      manifest: manifest,
      sourceUrl: row.sourceUrl,
      enabled: row.enabled,
      installedAt: row.installedAt,
      version: row.version,
      useAppDeepLink: row.useAppDeepLink,
    );
  }

  // ===================== 首次启动种子数据 =====================

  /// 如果一张数据源都没有，写入示例（Hacker News + 阮一峰博客 RSS），
  /// 让 app 开箱即有内容，也能直观看到两种数据源形态。
  Future<void> seedIfEmpty() async {
    final existing = await getAllDataSources();
    if (existing.isNotEmpty) return;

    await upsertDataSource(_defaultHackerNews());
    await upsertDataSource(_defaultRuanYifengRss());
  }

  /// 内置示例数据源：Hacker News 公开 API（无需鉴权，结构稳定）。
  DataSourceConfig _defaultHackerNews() {
    return const DataSourceConfig(
      id: 'hn_demo',
      name: 'Hacker News (示例)',
      apiUrl:
          'https://hn.algolia.com/api/v1/search?tags=story&page={page}&hitsPerPage={pageSize}',
      method: 'GET',
      fieldMapping: FieldMapping(
        listPath: 'hits',
        titlePath: 'title',
        // HN 默认没有缩略图字段，写个不存在的 key -> 取到空 -> UI 显示占位图
        thumbPath: 'thumbnail',
        authorPath: 'author',
        publishTimePath: 'created_at',
        detailUrlPath: 'url',
      ),
      detailMode: DetailRenderMode.webview,
    );
  }

  /// 内置示例 RSS 订阅源：阮一峰的网络日志（Atom 格式，无需鉴权）。
  /// RSS 源没有字段映射（fieldMapping 为 null），feed 地址存 apiUrl。
  DataSourceConfig _defaultRuanYifengRss() {
    return const DataSourceConfig(
      id: 'ruanyifeng_rss_demo',
      name: '阮一峰的网络日志 (示例)',
      apiUrl: 'https://www.ruanyifeng.com/blog/atom.xml',
      sourceType: DataSourceType.rss,
      detailMode: DetailRenderMode.webview,
    );
  }
}
