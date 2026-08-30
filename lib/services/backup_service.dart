import 'dart:convert';
import 'dart:math';

import 'package:filter_flow/core/db/app_database.dart';
import 'package:filter_flow/models/app_backup.dart';
import 'package:filter_flow/providers/feed_settings_provider.dart';

/// 导入方式。
enum ImportMode {
  /// 合并：保留现有配置，备份里"新的"追加进来、"同 id 的"覆盖掉。
  merge,

  /// 覆盖：先清空现有全部配置，再按备份内容原样重建（Tab 顺序也一起还原）。
  replace,
}

/// 导入结果统计（给用户看"这次导进来了多少东西"）。
class ImportResult {
  /// 新增的数据源条数
  final int addedSources;

  /// 被覆盖更新的数据源条数（备份里的 id 本地已经有了）
  final int updatedSources;

  /// 新增的插件条数
  final int addedPlugins;

  /// 被覆盖更新的插件条数
  final int updatedPlugins;

  /// 新增的屏蔽词条数（本地已有的不会重复添加）
  final int addedKeywords;

  const ImportResult({
    this.addedSources = 0,
    this.updatedSources = 0,
    this.addedPlugins = 0,
    this.updatedPlugins = 0,
    this.addedKeywords = 0,
  });

  /// 一句话摘要，直接展示在结果提示里。
  String get summary {
    final parts = <String>[];
    if (addedSources > 0) parts.add('新增数据源 $addedSources 个');
    if (updatedSources > 0) parts.add('更新数据源 $updatedSources 个');
    if (addedPlugins > 0) parts.add('新增插件 $addedPlugins 个');
    if (updatedPlugins > 0) parts.add('更新插件 $updatedPlugins 个');
    if (addedKeywords > 0) parts.add('新增屏蔽词 $addedKeywords 个');
    if (parts.isEmpty) return '导入完成，内容与现有配置一致';
    return parts.join('，');
  }
}

/// 配置备份的导入 / 导出服务。
///
/// 只负责"数据怎么打包 / 怎么写回数据库"，不涉及文件和 UI，
/// 这样它可以被单元测试直接调用（传内存数据库即可）。
class BackupService {
  final AppDatabase _db;

  const BackupService(this._db);

  /// 把当前 App 的全部配置打包成一份备份。
  ///
  /// [settings] 由调用方从 [feedSettingsProvider] 读出来传进来，
  /// 因为全局设置存在 SharedPreferences 里，不在数据库中。
  Future<AppBackup> exportBackup(FeedSettings settings) async {
    // 三张表各读一次；读原始行（Row）而不是模型，因为 Tab 序号只在行上有
    final sourceRows = await _db.getAllDataSourceRows();
    final pluginRows = await _db.getAllPluginRows();
    final keywords = await _db.getAllBlockedKeywords();

    return AppBackup(
      version: kBackupVersion,
      exportedAt: DateTime.now(),
      settings: settings,
      dataSources: [
        for (final r in sourceRows)
          BackupDataSourceEntry(config: r.config, sortOrder: r.sortOrder),
      ],
      plugins: [
        for (final r in pluginRows)
          BackupPluginEntry(
            plugin: _db.rowToInstalledPlugin(r),
            sortOrder: r.sortOrder,
          ),
      ],
      blockedKeywords: keywords,
    );
  }

  /// 把备份序列化成格式化好的 JSON 文本（写入文件 / 复制到剪贴板都用它）。
  ///
  /// 用 JsonEncoder.withIndent('  ') 让 JSON 带缩进换行，
  /// 方便用户直接用文本编辑器打开查看、甚至手动改。
  static String encode(AppBackup backup) {
    return const JsonEncoder.withIndent('  ').convert(backup.toJson());
  }

  /// 解析备份文本（JSON 字符串 → [AppBackup]）。
  ///
  /// 三种失败情况都会抛 [BackupFormatException]，错误信息可直接展示给用户：
  /// - 文本不是合法 JSON
  /// - 顶层不是 JSON 对象（比如传了个数组或纯字符串）
  /// - 缺少格式标识 / 版本不兼容（见 [AppBackup.fromJson]）
  static AppBackup parse(String text) {
    if (text.trim().isEmpty) {
      throw const BackupFormatException('内容为空');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (e) {
      throw BackupFormatException('不是合法的 JSON 文件：$e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('备份文件内容应该是一个 JSON 对象（以 { 开头）');
    }

    return AppBackup.fromJson(decoded);
  }

  /// 把备份写回数据库。
  ///
  /// 整个过程包在一个数据库事务里：中途任何一步出错都会整体回滚，
  /// 不会出现"源导进来一半、插件没导进来"的半吊子状态。
  Future<ImportResult> importBackup(
    AppBackup backup, {
    required ImportMode mode,
  }) {
    return _db.transaction(() async {
      switch (mode) {
        case ImportMode.merge:
          return await _importMerge(backup);
        case ImportMode.replace:
          return await _importReplace(backup);
      }
    });
  }

  /// 合并导入：现有的都留着，备份里 id 相同的覆盖、不同的追加。
  Future<ImportResult> _importMerge(AppBackup backup) async {
    final existingSourceIds = (await _db.getAllDataSourceRows())
        .map((r) => r.id)
        .toSet();
    final existingPluginIds = (await _db.getAllPluginRows())
        .map((r) => r.id)
        .toSet();
    final existingKeywords = (await _db.getAllBlockedKeywords()).toSet();

    // 新增的源排到现有 Tab 的最后面，避免和已有编号撞车
    var nextOrder = await _nextAvailableOrder();

    var addedSources = 0;
    var updatedSources = 0;
    for (final entry in backup.dataSources) {
      if (existingSourceIds.contains(entry.config.id)) {
        // 已存在：覆盖配置，但保留它现在的 Tab 位置（不打扰用户已经排好的顺序）
        await _db.upsertDataSource(entry.config);
        updatedSources++;
      } else {
        await _db.upsertDataSource(entry.config, sortOrder: nextOrder++);
        addedSources++;
      }
    }

    var addedPlugins = 0;
    var updatedPlugins = 0;
    for (final entry in backup.plugins) {
      if (existingPluginIds.contains(entry.plugin.id)) {
        await _db.upsertInstalledPlugin(entry.plugin);
        updatedPlugins++;
      } else {
        await _db.upsertInstalledPlugin(entry.plugin, sortOrder: nextOrder++);
        addedPlugins++;
      }
    }

    // 屏蔽词：只补本地没有的（word 列有唯一约束，重复插入会被忽略）
    final newKeywords = backup.blockedKeywords
        .where((w) => !existingKeywords.contains(w))
        .toList();
    await _db.addBlockedKeywords(newKeywords);

    return ImportResult(
      addedSources: addedSources,
      updatedSources: updatedSources,
      addedPlugins: addedPlugins,
      updatedPlugins: updatedPlugins,
      addedKeywords: newKeywords.length,
    );
  }

  /// 覆盖导入：清空现有全部配置，再按备份原样重建。
  ///
  /// 关键点：数据源和插件共用一套 Tab 编号，所以这里直接用备份里存的原序号，
  /// 才能还原出"插件排在数据源前面"这类交错顺序。
  Future<ImportResult> _importReplace(AppBackup backup) async {
    await _db.clearAllDataSources();
    await _db.clearAllPlugins();
    await _db.clearAllBlockedKeywords();

    for (final entry in backup.dataSources) {
      await _db.upsertDataSource(entry.config, sortOrder: entry.sortOrder);
    }
    for (final entry in backup.plugins) {
      await _db.upsertInstalledPlugin(entry.plugin, sortOrder: entry.sortOrder);
    }
    await _db.addBlockedKeywords(backup.blockedKeywords);

    return ImportResult(
      addedSources: backup.dataSources.length,
      addedPlugins: backup.plugins.length,
      addedKeywords: backup.blockedKeywords.length,
    );
  }

  /// 当前所有 Tab 序号里最大的那个 +1（给导入的新源用）。
  Future<int> _nextAvailableOrder() async {
    final orders = await _db.getAllSortOrders();
    if (orders.isEmpty) return 0;
    return orders.values.reduce(max) + 1;
  }
}
