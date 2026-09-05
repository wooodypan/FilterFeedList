import 'package:drift/drift.dart';

/// 已安装插件表：一行 = 一个装到本地的 JS 插件。
///
/// 关键点：我们**把完整 JS 源码（scriptContent）直接存进数据库**，
/// 而不是只存一个 URL 每次去拉。这样做的好处是：
/// - 离线也能用（不依赖脚本服务器在线）；
/// - 插件一旦安装，行为就固定下来，不会被作者偷偷改脚本坑用户；
/// - "检查更新"是显式动作，用户确认后才覆盖。
///
/// 为什么加 @DataClassName：
/// drift 默认按"表名去掉复数 s"给生成的数据类命名，InstalledPlugins 会生成
/// InstalledPlugin，和手写的插件模型 lib/plugin/models/installed_plugin.dart
/// 重名冲突。这里显式指定为 InstalledPluginsRow，两边的名字就分开了。
@DataClassName('InstalledPluginsRow')
class InstalledPlugins extends Table {
  /// 插件唯一 id（来自 manifest 的 @id，主键）
  TextColumn get id => text()();

  /// 展示名称
  TextColumn get name => text()();

  /// 完整 JS 源码（本地持久化）
  TextColumn get scriptContent => text()();

  /// 解析出的 manifest（JSON 字符串）
  TextColumn get manifestJson => text()();

  /// 安装来源 URL（用于"检查更新"时重新拉取比对版本）
  TextColumn get sourceUrl => text()();

  /// 是否启用（关闭后不参与信息流）
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 安装时间
  DateTimeColumn get installedAt => dateTime()();

  /// 版本号
  TextColumn get version => text()();

  /// 是否启用"App 深链直达"：开启后文章带 appDeepLink 时优先拉起对应 App。
  /// 默认开启（和 json/rss 数据源保持一致），老库升级由 onUpgrade 自动填 true。
  BoolColumn get useAppDeepLink =>
      boolean().withDefault(const Constant(true))();

  /// 信息流顶部 Tab 的排序序号（越小越靠前）。
  ///
  /// 含义同 DataSources.sortOrder：插件和数据源共用一套全局编号，
  /// 所以"插件 Tab 排在数据源 Tab 前面"这种交错顺序也能被正确还原。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
