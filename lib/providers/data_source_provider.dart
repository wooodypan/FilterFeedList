import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../models/data_source_config.dart';
import 'core_providers.dart';

/// 数据源列表状态：管理所有数据源配置的加载与增删改。
///
/// 用 AsyncValue 包裹，方便 UI 区分"加载中 / 成功 / 失败"三种状态。
final dataSourcesProvider =
    StateNotifierProvider<
      DataSourceNotifier,
      AsyncValue<List<DataSourceConfig>>
    >((ref) {
      final db = ref.watch(appDatabaseProvider);
      return DataSourceNotifier(db);
    });

class DataSourceNotifier
    extends StateNotifier<AsyncValue<List<DataSourceConfig>>> {
  final AppDatabase _db;

  DataSourceNotifier(this._db) : super(const AsyncValue.loading()) {
    _load();
  }

  /// 从数据库读全部数据源
  Future<void> _load() async {
    try {
      final list = await _db.getAllDataSources();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 重新从数据库加载（供外部在数据被批量改动后调用，如"导入备份"）。
  Future<void> reload() => _load();

  /// 新增或更新一个数据源（id 相同即覆盖）
  Future<void> upsert(DataSourceConfig config) async {
    await _db.upsertDataSource(config);
    await _load();
  }

  /// 删除数据源
  Future<void> delete(String id) async {
    await _db.deleteDataSource(id);
    await _load();
  }

  /// 批量新增数据源（OPML 导入用）：一次写入、一次刷新，避免 N 次重载。
  Future<void> addMultiple(List<DataSourceConfig> configs) async {
    await _db.insertDataSources(configs);
    await _load();
  }

  /// 切换启用/停用
  Future<void> setEnabled(String id, bool enabled) async {
    await _db.setEnabled(id, enabled);
    await _load();
  }
}
