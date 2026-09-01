import 'dart:convert';
import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart' as wd;

import '../models/webdav_config.dart';

/// WebDAV 上的一个备份文件（列表用）。
class RemoteBackupFile {
  /// 文件名，如 `filterflow-backup-20260829-2335.json`
  final String name;

  /// 远程完整路径（下载时要用它），如 `/filterflow/xxx.json`
  final String path;

  /// 字节大小
  final int size;

  /// 最后修改时间（服务器可能不给，给不了就是 null）
  final DateTime? modified;

  const RemoteBackupFile({
    required this.name,
    required this.path,
    this.size = 0,
    this.modified,
  });
}

/// WebDAV 备份同步服务。
///
/// 只负责"和 WebDAV 服务器打交道"（连接 / 列目录 / 上传 / 下载），
/// 不碰数据库和 UI，方便单元测试或直接复用。底层用开源库 `webdav_client`
/// （基于 dio，支持 Basic/Digest 认证）。
///
/// 为什么每次都新建 client：webdav_client 的 Client 是轻量对象，
/// 不持有长连接，按操作 new 一个最省心，也避免复用导致的状态串台。
class WebDavService {
  /// 根据配置建立一个连接（debug 关掉，免得大文件把日志刷爆）
  wd.Client _connect(WebDavConfig cfg) {
    return wd.newClient(
      cfg.serverUrl.trim(),
      user: cfg.username,
      password: cfg.password,
      debug: false,
    );
  }

  /// 测试连通性。连不上会抛异常（调用方转成错误提示即可）。
  Future<void> testConnection(WebDavConfig cfg) => _connect(cfg).ping();

  /// 列出远程目录下的 .json 备份文件，按修改时间倒序（最新的在最前）。
  ///
  /// - 目录不存在时自动 mkdirAll 建出来，方便"第一次上传"就能落盘；
  ///   建目录失败（比如某些服务器禁止建目录）就忽略，交给后面的 readDir 报错。
  /// - 只筛 `.json` 文件，避免把别的文件混进来。
  Future<List<RemoteBackupFile>> listBackups(WebDavConfig cfg) async {
    final client = _connect(cfg);
    final dir = cfg.normalizedDir;

    // 目录非空才尝试创建（根目录 '/' 建不了也没必要）
    if (dir.isNotEmpty) {
      try {
        await client.mkdirAll(dir);
      } on Object {
        // 目录可能已存在，或服务器不允许建目录——都不致命，继续
      }
    }

    final files = await client.readDir(dir.isEmpty ? '/' : dir);
    final backups = <RemoteBackupFile>[];
    for (final f in files) {
      if (f.isDir == true) continue; // 跳过子目录
      final name = f.name ?? '';
      if (!name.endsWith('.json')) continue; // 只关心备份文件
      backups.add(
        RemoteBackupFile(
          name: name,
          // f.path 有的是相对路径，必要时用 dir 兜底拼成完整路径
          path: f.path ?? '${dir.isEmpty ? '' : dir}/$name',
          size: f.size ?? 0,
          modified: f.mTime,
        ),
      );
    }

    backups.sort(
      (a, b) =>
          (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0)),
    );
    return backups;
  }

  /// 把备份内容（JSON 文本）上传到远程目录。
  ///
  /// 返回远程文件完整路径，方便 UI 回显"传到哪了"。
  Future<String> upload(
    WebDavConfig cfg,
    String fileName,
    String content,
  ) async {
    final client = _connect(cfg);
    final dir = cfg.normalizedDir;
    if (dir.isNotEmpty) await client.mkdirAll(dir);

    final remotePath = cfg.remotePathFor(fileName);
    // webdav_client 的 write 直接吃 Uint8List，不用先落本地临时文件
    await client.write(remotePath, Uint8List.fromList(utf8.encode(content)));
    return remotePath;
  }

  /// 下载远程文件，返回文本（UTF-8 解码）。
  Future<String> download(WebDavConfig cfg, String remotePath) async {
    final bytes = await _connect(cfg).read(remotePath);
    return utf8.decode(bytes);
  }
}
