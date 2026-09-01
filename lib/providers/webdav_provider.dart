import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/webdav_config.dart';

/// WebDAV 连接配置的全局状态。
///
/// 用户填一次存起来，之后上传/下载都直接用，不用每次重填。
/// 持久化到 SharedPreferences（密码明文，见 [WebDavConfig] 的说明）。
final webDavConfigProvider =
    StateNotifierProvider<WebDavConfigNotifier, WebDavConfig>(
      (ref) => WebDavConfigNotifier(),
    );

class WebDavConfigNotifier extends StateNotifier<WebDavConfig> {
  WebDavConfigNotifier() : super(const WebDavConfig()) {
    _load();
  }

  static const _kServer = 'webdav_server_url';
  static const _kUser = 'webdav_username';
  static const _kPass = 'webdav_password';
  static const _kDir = 'webdav_remote_dir';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = WebDavConfig(
      serverUrl: prefs.getString(_kServer) ?? '',
      username: prefs.getString(_kUser) ?? '',
      password: prefs.getString(_kPass) ?? '',
      remoteDir: prefs.getString(_kDir) ?? '',
    );
  }

  /// 保存一份新配置并立刻切到新状态（UI 自动刷新）。
  Future<void> save(WebDavConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServer, cfg.serverUrl);
    await prefs.setString(_kUser, cfg.username);
    await prefs.setString(_kPass, cfg.password);
    await prefs.setString(_kDir, cfg.remoteDir);
    state = cfg;
  }
}
