import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plugin/models/installed_plugin.dart';
import '../plugin/plugin_repository.dart';
import 'core_providers.dart';

/// 已安装插件列表状态：管理本地所有插件的加载与增删改 / 启用开关。
///
/// 用 AsyncValue 包裹，方便 UI 区分"加载中 / 成功 / 失败"。
final installedPluginsProvider = StateNotifierProvider<
    InstalledPluginNotifier, AsyncValue<List<InstalledPlugin>>>((ref) {
  final repo = ref.watch(pluginRepositoryProvider);
  return InstalledPluginNotifier(repo);
});

class InstalledPluginNotifier
    extends StateNotifier<AsyncValue<List<InstalledPlugin>>> {
  final PluginRepository _repo;

  InstalledPluginNotifier(this._repo)
      : super(const AsyncValue.loading()) {
    _load();
  }

  /// 从数据库读全部已安装插件。
  Future<void> _load() async {
    try {
      final list = await _repo.getAll();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 重新从数据库加载（供外部在数据被批量改动后调用，如"导入备份"）。
  Future<void> reload() => _load();

  /// 安装或覆盖更新一个插件（id 相同即覆盖脚本）。
  Future<void> install(InstalledPlugin plugin) async {
    await _repo.install(plugin);
    await _load();
  }

  /// 删除插件。
  Future<void> delete(String id) async {
    await _repo.delete(id);
    await _load();
  }

  /// 编辑后保存：按 id 覆盖写入（install 本身就是 upsert）。
  ///
  /// 调用方（编辑对话框）负责保证 [plugin.id] 不变，只改 name / scriptContent 等字段。
  Future<void> update(InstalledPlugin plugin) async {
    await _repo.install(plugin);
    await _load();
  }

  /// 切换启用 / 停用。
  Future<void> setEnabled(String id, bool enabled) async {
    await _repo.setEnabled(id, enabled);
    await _load();
  }
}
