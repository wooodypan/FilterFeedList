import 'plugin_manifest.dart';

/// 一个"已安装"的插件（运行时对象，不入库原始字段，由 DAO 组装）。
///
/// 它和 [PluginManifest] 的区别：manifest 只是脚本头里那点元信息，
/// 而 InstalledPlugin 是"装到本地的完整插件"——包含脚本全文、来源 URL、启用状态等。
///
/// 注意 ==/hashCode：我们特意把脚本内容、版本、启用状态等都算进去，
/// 这样数据源列表 / 信息流 Tab 能据此判断"这个插件是不是被改过了"，
/// 从而决定是否要重建对应的数据拉取逻辑。
class InstalledPlugin {
  final String id;
  final String name;
  final String scriptContent; // 完整 JS 源码，本地持久化
  final PluginManifest manifest;
  final String sourceUrl; // 安装来源 URL（用于"检查更新"）
  final bool enabled;
  final DateTime installedAt;
  final String version;

  const InstalledPlugin({
    required this.id,
    required this.name,
    required this.scriptContent,
    required this.manifest,
    required this.sourceUrl,
    required this.enabled,
    required this.installedAt,
    required this.version,
  });

  /// 生成一个"测试用"的临时实例（不落库），供安装页"先跑一次验证"使用。
  InstalledPlugin copyWith({
    String? name,
    String? scriptContent,
    PluginManifest? manifest,
    String? sourceUrl,
    bool? enabled,
    DateTime? installedAt,
    String? version,
  }) {
    return InstalledPlugin(
      id: id,
      name: name ?? this.name,
      scriptContent: scriptContent ?? this.scriptContent,
      manifest: manifest ?? this.manifest,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt ?? this.installedAt,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledPlugin &&
          other.id == id &&
          other.name == name &&
          other.scriptContent == scriptContent &&
          other.version == version &&
          other.enabled == enabled &&
          other.sourceUrl == sourceUrl &&
          other.manifest == manifest;

  @override
  int get hashCode =>
      Object.hash(id, name, scriptContent, version, enabled, sourceUrl, manifest);

  @override
  String toString() =>
      'InstalledPlugin(id: $id, name: $name, version: $version, enabled: $enabled)';
}
