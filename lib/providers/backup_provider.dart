import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_backup.dart';
import '../models/webdav_config.dart';
import '../services/backup_service.dart';
import '../services/webdav_service.dart';
import 'blocked_keyword_provider.dart';
import 'core_providers.dart';
import 'data_source_provider.dart';
import 'feed_list_provider.dart';
import 'feed_settings_provider.dart';
import 'plugin_provider.dart';

/// 备份服务的 Provider（内部持有全局数据库实例）。
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);

/// WebDAV 同步服务（上传 / 下载备份到 WebDAV 服务器）。
final webDavServiceProvider = Provider<WebDavService>((ref) => WebDavService());

/// 配置导入 / 导出的"总指挥"。
///
/// 它把数据库写入（[BackupService]）、文件读写（file_picker / share_plus）
/// 和 WebDAV 同步（[WebDavService]）和各列表 Provider 的刷新串起来，
/// UI 只需要调它的方法、拿结果展示即可。
final backupControllerProvider = Provider<BackupController>(
  (ref) => BackupController(ref),
);

class BackupController {
  final Ref _ref;

  const BackupController(this._ref);

  BackupService get _service => _ref.read(backupServiceProvider);

  WebDavService get _webdav => _ref.read(webDavServiceProvider);

  /// 读取当前全部配置，打包成一份备份对象（还没写文件）。
  Future<AppBackup> buildBackup() {
    return _service.exportBackup(_ref.read(feedSettingsProvider));
  }

  /// 导出到文件并唤起系统分享面板。
  ///
  /// 流程：组装备份 → 格式化成 JSON → 写到临时目录 → 调起系统分享。
  /// 用户在分享面板里可以选择"存储到磁盘"（macOS）、"存储到文件"（iOS）、
  /// 或者直接发到微信 / 邮件等任意 App。
  ///
  /// 返回生成的临时文件路径（UI 会把它展示给用户，方便找到文件）。
  Future<String> exportToFile() async {
    final backup = await buildBackup();
    final text = BackupService.encode(backup);

    // 临时目录：系统会在合适时机清理，不需要我们手动删除
    final dir = await getTemporaryDirectory();
    // 文件名只生成一次：写文件和下面的 fileNameOverrides 必须用同一个名字，
    // 否则跨分钟时会出现"存进去叫 A、发出去叫 B"的错位
    final fileName = _backupFileName(DateTime.now());
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(text, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        // 文件本体
        files: [XFile(file.path)],
        // 同时带一句文本：某些接收方（如微信）只认文本，给用户一个可读的说明
        text:
            'FilterFlow 配置备份（${backup.sourceCount} 个信息源、'
            '${backup.blockedKeywords.length} 个屏蔽词）',
        subject: 'FilterFlow 配置备份',
        // 文件名覆盖：部分平台（如 Android 缓存目录）会忽略 XFile 的 name，
        // 显式声明能保证收到的文件叫这个名字而不是一串随机字符
        fileNameOverrides: [fileName],
      ),
    );

    return file.path;
  }

  /// 导出成 JSON 文本（不落文件），供"复制到剪贴板"这类场景用。
  Future<String> exportToText() async {
    return BackupService.encode(await buildBackup());
  }

  /// 弹出系统文件选择面板，让用户挑一个 .json 备份文件。
  ///
  /// 用户取消选择时返回 null（不是异常，UI 直接不处理即可）。
  /// 返回的 [PickedBackup] 里带着解析好的备份对象和来源文件名。
  Future<PickedBackup?> pickBackupFile() async {
    // file_picker 12 的 API：静态方法直接返回选中的文件列表，空列表 = 用户取消
    final files = await FilePicker.pickFiles(
      dialogTitle: '选择 FilterFlow 备份文件',
      // 只允许选 json，避免误选图片等二进制文件导致解析报一堆乱码错
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return null;

    final file = files.first;
    // 读字节再按 UTF-8 解码：比直接读路径更可靠（macOS 沙盒下路径可能受限）
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes);

    // 解析失败会抛 BackupFormatException，交给 UI 展示错误文案
    return PickedBackup(backup: BackupService.parse(text), fileName: file.name);
  }

  /// 把备份写回数据库，并让界面上所有相关列表刷新。
  ///
  /// [mode] 决定是"合并"还是"覆盖"（见 [ImportMode]）。
  Future<ImportResult> importBackup(
    AppBackup backup, {
    required ImportMode mode,
  }) async {
    final result = await _service.importBackup(backup, mode: mode);

    // 数据库已经改完了，但界面上的 Provider 还持有旧数据，逐个刷新：
    // - 三个列表：数据源 / 插件 / 屏蔽词
    // - Tab 排序序号：新导入的源有自己的序号
    await _ref.read(dataSourcesProvider.notifier).reload();
    await _ref.read(installedPluginsProvider.notifier).reload();
    await _ref.read(blockedKeywordsProvider.notifier).reload();
    await _ref.read(sourceSortOrdersProvider.notifier).refresh();

    // 全局设置（聚合模式 / 缩略图开关）存在 SharedPreferences 里，单独写回
    await _ref.read(feedSettingsProvider.notifier).apply(backup.settings);

    return result;
  }

  // ===================== WebDAV 同步 =====================

  /// 测试 WebDAV 连接是否可用（UI 的"测试连接"按钮用）。
  ///
  /// 连不上会抛异常，调用方把异常转成错误提示即可。
  Future<void> testWebDavConnection(WebDavConfig cfg) =>
      _webdav.testConnection(cfg);

  /// 列出 WebDAV 远程目录里的备份文件（供"从 WebDAV 下载"选择）。
  Future<List<RemoteBackupFile>> listWebDavBackups(WebDavConfig cfg) =>
      _webdav.listBackups(cfg);

  /// 把当前配置打包后上传到 WebDAV。
  ///
  /// 返回远程文件路径（UI 回显"传到哪了"）。
  Future<String> exportToWebDav(WebDavConfig cfg) async {
    final backup = await buildBackup();
    final text = BackupService.encode(backup);
    final fileName = _backupFileName(DateTime.now());
    return _webdav.upload(cfg, fileName, text);
  }

  /// 从 WebDAV 下载一个备份文件，返回原始 JSON 文本（还没解析）。
  ///
  /// 下载后由调用方用 [BackupService.parse] 解析、再走 [importBackup] 落库，
  /// 这样解析失败的错误提示和本地导入是同一套文案。
  Future<String> downloadFromWebDav(WebDavConfig cfg, String remotePath) =>
      _webdav.download(cfg, remotePath);

  /// 备份文件名：filterflow-backup-20260829-2335.json
  ///
  /// 带上时间戳是为了让用户导出多份时不至于互相覆盖。
  String _backupFileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'filterflow-backup-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.json';
  }
}

/// 用户从文件选择面板挑中的一份备份（含原始文件名，方便回显给用户看）。
class PickedBackup {
  final AppBackup backup;
  final String fileName;

  const PickedBackup({required this.backup, required this.fileName});
}
