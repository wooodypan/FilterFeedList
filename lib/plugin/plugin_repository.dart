import '../core/db/app_database.dart';
import 'models/installed_plugin.dart';

/// 已安装插件的本地存储仓库（CRUD）。
///
/// 它只是 [AppDatabase] 里插件相关 DAO 的一层薄封装，方便上层
///（Provider / 安装页）调用，也把"数据库行 ↔ InstalledPlugin 对象"的
/// 转换细节收敛到这里。
class PluginRepository {
  final AppDatabase _db;

  PluginRepository(this._db);

  /// 列出所有已安装插件。
  Future<List<InstalledPlugin>> getAll() => _db.getAllInstalledPlugins();

  /// 按 id 查单个。
  Future<InstalledPlugin?> getById(String id) =>
      _db.getInstalledPluginById(id);

  /// 安装或覆盖更新（id 相同即覆盖）。
  Future<void> install(InstalledPlugin plugin) =>
      _db.upsertInstalledPlugin(plugin);

  /// 删除。
  Future<void> delete(String id) => _db.deleteInstalledPlugin(id);

  /// 切换启用 / 停用。
  Future<void> setEnabled(String id, bool enabled) =>
      _db.setPluginEnabled(id, enabled);
}
