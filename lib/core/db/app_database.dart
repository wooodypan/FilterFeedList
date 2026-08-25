import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/data_source_config.dart';
import '../../models/field_mapping.dart';
import 'tables/blocked_keyword_table.dart';
import 'tables/data_source_table.dart';

part 'app_database.g.dart';

/// 全局数据库。
///
/// 一张表存数据源配置（DataSources），一张表存屏蔽词（BlockedKeywords）。
/// 使用 drift 的 LazyDatabase + NativeDatabase：第一次真正访问时才创建文件，
/// 避免在 app 启动早期就碰文件系统。
@DriftDatabase(tables: [DataSources, BlockedKeywords])
class AppDatabase extends _$AppDatabase {
  /// 默认的构造函数：自动在"应用文档目录"下建一个 sqlite 文件。
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
    final row = await (select(dataSources)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.config;
  }

  /// 插入或更新（id 相同就覆盖）
  Future<void> upsertDataSource(DataSourceConfig config) {
    return into(dataSources).insertOnConflictUpdate(
      DataSourcesCompanion.insert(
        // .insert 工厂里 id/name/config 是"原始类型"，不是 Value 包裹
        id: config.id,
        name: config.name,
        enabled: Value(config.enabled),
        config: config,
      ),
    );
  }

  /// 删除某个数据源
  Future<int> deleteDataSource(String id) {
    return (delete(dataSources)..where((t) => t.id.equals(id))).go();
  }

  /// 切换启用状态
  Future<void> setEnabled(String id, bool enabled) {
    return (update(dataSources)..where((t) => t.id.equals(id)))
        .write(DataSourcesCompanion(enabled: Value(enabled)));
  }

  // ===================== 屏蔽词相关 DAO =====================

  /// 查出所有屏蔽词（按添加时间倒序），返回纯字符串列表
  Future<List<String>> getAllBlockedKeywords() async {
    final rows = await (select(blockedKeywords)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map((r) => r.word).toList();
  }

  /// 监听屏蔽词变化（UI 自动刷新）
  Stream<List<String>> watchBlockedKeywords() {
    return (select(blockedKeywords)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map((r) => r.word).toList());
  }

  /// 添加一个屏蔽词（重复添加会忽略）
  Future<void> addBlockedKeyword(String word) {
    return into(blockedKeywords).insertOnConflictUpdate(
      BlockedKeywordsCompanion.insert(word: word),
    );
  }

  /// 删除一个屏蔽词
  Future<int> deleteBlockedKeyword(String word) {
    return (delete(blockedKeywords)..where((t) => t.word.equals(word))).go();
  }

  // ===================== 首次启动种子数据 =====================

  /// 如果一张数据源都没有，写入一个示例（Hacker News），让 app 开箱即有内容。
  Future<void> seedIfEmpty() async {
    final existing = await getAllDataSources();
    if (existing.isNotEmpty) return;

    await upsertDataSource(_defaultHackerNews());
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
}
