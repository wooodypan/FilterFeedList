import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/plugin/models/installed_plugin.dart';
import 'package:filter_flow/plugin/models/plugin_manifest.dart';
import 'package:filter_flow/providers/feed_settings_provider.dart';

/// 备份文件的格式标识。
///
/// 放在 JSON 的最外层，导入时先认这个"暗号"，
/// 防止用户误选了一个别的 App 导出的 JSON 也被当成配置灌进来。
const String kBackupFormat = 'filterflow-backup';

/// 当前 App 能写入的备份格式版本号。
///
/// 以后如果备份结构变了（比如加了新字段、改了字段含义），
/// 就把这个数字 +1，并在 [AppBackup.fromJson] 里针对老版本写兼容分支。
const int kBackupVersion = 1;

/// 备份里的一条数据源：配置本体 + 它在信息流顶部 Tab 里的排序序号。
class BackupDataSourceEntry {
  final DataSourceConfig config;

  /// Tab 排序序号（越小越靠前）。数据源和插件共用一套全局编号。
  final int sortOrder;

  const BackupDataSourceEntry({required this.config, required this.sortOrder});

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'sortOrder': sortOrder,
  };

  /// 反序列化。整条数据不合法时返回 null（调用方跳过它，不让一条坏数据毁掉整份备份）。
  static BackupDataSourceEntry? tryFromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;

    // config 是核心，缺了就没法恢复成一个数据源
    final configRaw = raw['config'];
    if (configRaw is! Map<String, dynamic>) return null;

    DataSourceConfig config;
    try {
      config = DataSourceConfig.fromJson(configRaw);
    } catch (_) {
      // 单个数据源解析失败（比如字段类型不对）：跳过它而不是让整份导入失败
      return null;
    }

    // 序号缺失就当作 0（排在靠前的位置），由导入逻辑重新分配
    final order = raw['sortOrder'];
    return BackupDataSourceEntry(
      config: config,
      sortOrder: order is int ? order : 0,
    );
  }
}

/// 备份里的一条插件：插件完整信息（含 JS 源码）+ Tab 排序序号。
class BackupPluginEntry {
  final InstalledPlugin plugin;
  final int sortOrder;

  const BackupPluginEntry({required this.plugin, required this.sortOrder});

  Map<String, dynamic> toJson() => {
    'id': plugin.id,
    'name': plugin.name,
    // 脚本正文：导入后要能原样跑起来，所以整段 JS 都存进备份
    'scriptContent': plugin.scriptContent,
    'manifest': plugin.manifest.toJson(),
    'sourceUrl': plugin.sourceUrl,
    'enabled': plugin.enabled,
    // 时间统一存 ISO8601 字符串（JSON 没有"日期"类型）
    'installedAt': plugin.installedAt.toIso8601String(),
    'version': plugin.version,
    'sortOrder': sortOrder,
  };

  /// 反序列化。缺 id / 脚本正文就视为无效条目，返回 null。
  static BackupPluginEntry? tryFromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;

    final id = raw['id'];
    final script = raw['scriptContent'];
    final manifestRaw = raw['manifest'];
    if (id is! String || id.isEmpty) return null;
    if (script is! String || script.isEmpty) return null;
    if (manifestRaw is! Map<String, dynamic>) return null;

    // manifest 里必须有 id 和 name，否则 PluginManifest.fromJson 会抛异常
    if (manifestRaw['id'] is! String || manifestRaw['name'] is! String) {
      return null;
    }

    PluginManifest manifest;
    try {
      manifest = PluginManifest.fromJson(manifestRaw);
    } catch (_) {
      return null;
    }

    // 安装时间：解析不出来就用当前时间兜底（只影响"安装时间"的展示）
    DateTime installedAt = DateTime.now();
    final installedRaw = raw['installedAt'];
    if (installedRaw is String) {
      installedAt = DateTime.tryParse(installedRaw) ?? installedAt;
    }

    final order = raw['sortOrder'];
    return BackupPluginEntry(
      plugin: InstalledPlugin(
        id: id,
        // 显示名缺失就用 manifest 里的名字兜底
        name: (raw['name'] is String && (raw['name'] as String).isNotEmpty)
            ? raw['name'] as String
            : manifest.name,
        scriptContent: script,
        manifest: manifest,
        sourceUrl: raw['sourceUrl'] is String ? raw['sourceUrl'] as String : '',
        enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
        installedAt: installedAt,
        version: raw['version'] is String ? raw['version'] as String : '0.0.0',
      ),
      sortOrder: order is int ? order : 0,
    );
  }
}

/// 一份完整的 App 配置备份。
///
/// 覆盖四类用户数据：
/// - [dataSources]：RSS 订阅 + API 数据源（含各自的 Tab 序号）
/// - [plugins]：已安装的 JS 插件（含脚本全文）
/// - [blockedKeywords]：屏蔽词
/// - [settings]：全局开关（聚合模式、是否显示缩略图）
class AppBackup {
  /// 备份格式版本（见 [kBackupVersion]）
  final int version;

  /// 导出时间（展示给用户看，让用户知道这份备份有多旧）
  final DateTime exportedAt;

  final FeedSettings settings;
  final List<BackupDataSourceEntry> dataSources;
  final List<BackupPluginEntry> plugins;
  final List<String> blockedKeywords;

  const AppBackup({
    required this.version,
    required this.exportedAt,
    required this.settings,
    required this.dataSources,
    required this.plugins,
    required this.blockedKeywords,
  });

  /// 备份里一共有多少个"信息源"（数据源 + 插件），用于导入前的预览文案。
  int get sourceCount => dataSources.length + plugins.length;

  /// 备份是否为"空配置"（导出时用户什么都没配）。
  bool get isEmpty =>
      dataSources.isEmpty && plugins.isEmpty && blockedKeywords.isEmpty;

  Map<String, dynamic> toJson() => {
    // 格式暗号：导入时靠它确认"这确实是 FilterFlow 的备份文件"
    'format': kBackupFormat,
    'version': version,
    'exportedAt': exportedAt.toIso8601String(),
    'settings': {
      'aggregateMode': settings.aggregateMode,
      'showThumb': settings.showThumb,
    },
    'dataSources': dataSources.map((e) => e.toJson()).toList(),
    'plugins': plugins.map((e) => e.toJson()).toList(),
    'blockedKeywords': blockedKeywords,
  };

  /// 从 JSON 反序列化。
  ///
  /// 校验失败（不是本 App 的备份 / 版本比当前新 / 结构损坏）时抛
  /// [BackupFormatException]，由上层把错误文案直接展示给用户。
  ///
  /// 单条数据损坏不会让整份失败——只在最后少恢复那一条，
  /// 这样"备份里有一个源配置错了"不至于让用户什么都导不进来。
  factory AppBackup.fromJson(Map<String, dynamic> json) {
    final format = json['format'];
    if (format != kBackupFormat) {
      throw const BackupFormatException('这不是 FilterFlow 的备份文件（缺少格式标识）');
    }

    final version = json['version'];
    if (version is! int) {
      throw const BackupFormatException('备份文件缺少版本号');
    }
    if (version > kBackupVersion) {
      // 备份来自"更新版本"的 App，当前版本读不懂它的新字段，
      // 硬读可能恢复出残缺配置，所以直接拒绝。
      throw BackupFormatException(
        '备份文件版本（$version）比当前 App 支持的最高版本（$kBackupVersion）新，'
        '请升级 App 后再导入',
      );
    }

    // 导出时间：解析不出来就用当前时间，仅影响展示
    DateTime exportedAt = DateTime.now();
    final exportedRaw = json['exportedAt'];
    if (exportedRaw is String) {
      exportedAt = DateTime.tryParse(exportedRaw) ?? exportedAt;
    }

    // 设置：整块缺失就用默认值（老版本备份可能没有这一块）
    final settingsRaw = json['settings'];
    final settings = settingsRaw is Map<String, dynamic>
        ? FeedSettings(
            aggregateMode: settingsRaw['aggregateMode'] is bool
                ? settingsRaw['aggregateMode'] as bool
                : false,
            showThumb: settingsRaw['showThumb'] is bool
                ? settingsRaw['showThumb'] as bool
                : true,
          )
        : const FeedSettings();

    // 数据源 / 插件：逐条解析，坏条目直接跳过
    final dataSources = <BackupDataSourceEntry>[];
    final dsRaw = json['dataSources'];
    if (dsRaw is List) {
      for (final item in dsRaw) {
        final entry = BackupDataSourceEntry.tryFromJson(item);
        if (entry != null) dataSources.add(entry);
      }
    }

    final plugins = <BackupPluginEntry>[];
    final plRaw = json['plugins'];
    if (plRaw is List) {
      for (final item in plRaw) {
        final entry = BackupPluginEntry.tryFromJson(item);
        if (entry != null) plugins.add(entry);
      }
    }

    // 屏蔽词：只收非空字符串，顺便去重（用 Set 天然去重）
    final keywords = <String>{};
    final kwRaw = json['blockedKeywords'];
    if (kwRaw is List) {
      for (final item in kwRaw) {
        if (item is String) {
          final w = item.trim();
          if (w.isNotEmpty) keywords.add(w);
        }
      }
    }

    return AppBackup(
      version: version,
      exportedAt: exportedAt,
      settings: settings,
      dataSources: dataSources,
      plugins: plugins,
      blockedKeywords: keywords.toList(),
    );
  }
}

/// 备份文件格式错误（不是本 App 的备份、版本不兼容、JSON 损坏等）。
class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => 'BackupFormatException: $message';
}
