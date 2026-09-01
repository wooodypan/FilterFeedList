/// WebDAV 连接配置。
///
/// 用户填一次，存进 SharedPreferences，之后"上传到 WebDAV / 从 WebDAV 下载"
/// 都直接复用，不用每次手敲。
///
/// 注意：密码明文存在本地 SharedPreferences 里（个人单机 App，方便为主）。
/// 如果以后要做更安全的存储，可以换成 flutter_secure_storage，这里先简单处理。
class WebDavConfig {
  /// 服务器地址，如 `https://dav.jianguoyun.com/dav/`
  final String serverUrl;

  /// 用户名（部分服务（如坚果云）要用"应用专用密码"而不是登录密码）
  final String username;

  /// 密码
  final String password;

  /// 远程目录，相对于服务器根，如 `filterflow` 或 `/filterflow/`
  /// 留空表示服务器根目录。
  final String remoteDir;

  const WebDavConfig({
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.remoteDir = '',
  });

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remoteDir,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDir: remoteDir ?? this.remoteDir,
    );
  }

  /// 是否已经填了服务器地址（上传/下载前先判断这个）
  bool get isConfigured => serverUrl.trim().isNotEmpty;

  /// 把用户填的远程目录规整成"以 / 开头、不以 / 结尾"的形式。
  /// 例如 `filterflow/` → `/filterflow`，`/a/b/` → `/a/b`，`''` → `''`。
  String get normalizedDir {
    final d = remoteDir.trim();
    if (d.isEmpty) return '';
    var s = d.startsWith('/') ? d : '/$d';
    // 去掉末尾多余的斜杠
    while (s.length > 1 && s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 根据文件名算出完整的远程路径（含目录）。
  /// 例如 normalizedDir = `/filterflow`，fileName = `a.json` → `/filterflow/a.json`
  /// 根目录（normalizedDir 为空）→ `/a.json`
  String remotePathFor(String fileName) {
    final dir = normalizedDir;
    return dir.isEmpty ? '/$fileName' : '$dir/$fileName';
  }

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'remoteDir': remoteDir,
  };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remoteDir: json['remoteDir'] as String? ?? '',
    );
  }
}
