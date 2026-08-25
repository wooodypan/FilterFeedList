/// 插件清单（manifest）。
///
/// 一个插件 = 一段 JS 脚本 + 一段写在注释头里的"清单"。
/// 清单用类似 Tampermonkey 脚本头的格式，例如：
///
/// ```js
/// // ==DataSourcePlugin==
/// // @id           hn_demo
/// // @name         Hacker News
/// // @version      1.0.0
/// // @author       yourname
/// // @description  Hacker News 热门文章聚合
/// // @icon         https://hn.algolia.com/favicon.ico
/// // @homepage     https://github.com/xxx/hn-plugin
/// // ==/DataSourcePlugin==
/// ```
///
/// 这样用户只要贴一个脚本 URL，App 下载后就能从中解析出"这是谁、叫什么、哪个版本"，
/// 在"确认安装"弹窗里展示给用户看，而不是盲装。
class PluginManifest {
  /// 插件唯一 id（也是数据库主键）
  final String id;

  /// 展示名称
  final String name;

  /// 版本号（用于"检查更新"时比对）
  final String? version;

  /// 作者
  final String? author;

  /// 描述
  final String? description;

  /// 图标 URL（展示用，可空）
  final String? icon;

  /// 主页 / 源码地址（可空）
  final String? homepage;

  const PluginManifest({
    required this.id,
    required this.name,
    this.version,
    this.author,
    this.description,
    this.icon,
    this.homepage,
  });

  /// 从脚本源码里解析清单注释头。
  ///
  /// 找不到合法的 `// ==DataSourcePlugin==` 块、或缺少 @id / @name 时抛
  /// [PluginManifestException]，让上层（下载器 / 安装页）给出明确报错。
  factory PluginManifest.parse(String script) {
    final block = _extractBlock(script);
    if (block == null) {
      throw const PluginManifestException(
        '脚本里没有找到 // ==DataSourcePlugin== 清单注释头',
      );
    }

    final fields = <String, String>{};
    for (final line in block) {
      // 形如：// @id           hn_demo
      final m = RegExp(r'//\s*@(\w+)\s*(.*)').firstMatch(line);
      if (m != null) {
        final key = m.group(1)!;
        final value = m.group(2)!.trim();
        if (value.isNotEmpty) fields[key] = value;
      }
    }

    final id = fields['id'];
    final name = fields['name'];
    if (id == null || id.isEmpty) {
      throw const PluginManifestException('清单缺少 @id');
    }
    if (name == null || name.isEmpty) {
      throw const PluginManifestException('清单缺少 @name');
    }

    return PluginManifest(
      id: id,
      name: name,
      version: fields['version'],
      author: fields['author'],
      description: fields['description'],
      icon: fields['icon'],
      homepage: fields['homepage'],
    );
  }

  /// 提取两个标记行之间的所有行（不含标记行本身）。
  static List<String>? _extractBlock(String script) {
    final lines = script.split('\n');
    final start = lines.indexWhere((l) => l.contains('==DataSourcePlugin=='));
    if (start < 0) return null;
    final end =
        lines.indexWhere((l) => l.contains('==/DataSourcePlugin=='), start + 1);
    if (end < 0) return null; // 只有开头没有结尾，视为非法
    return lines.sublist(start + 1, end);
  }

  /// 序列化（存进数据库 manifestJson 列）
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (version != null) 'version': version,
        if (author != null) 'author': author,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (homepage != null) 'homepage': homepage,
      };

  factory PluginManifest.fromJson(Map<String, dynamic> json) => PluginManifest(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as String?,
        author: json['author'] as String?,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        homepage: json['homepage'] as String?,
      );

  @override
  String toString() => 'PluginManifest(id: $id, name: $name, version: $version)';
}

/// 清单解析失败（脚本格式不对）。
class PluginManifestException implements Exception {
  final String message;
  const PluginManifestException(this.message);
  @override
  String toString() => 'PluginManifestException: $message';
}
