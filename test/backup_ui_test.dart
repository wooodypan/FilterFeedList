// 备份恢复页面的 UI 集成测试。
//
// 这批用例守住单元测试覆盖不到的"真机交互路径"：
// - 导出为文件：要调 share_plus（这里 mock 掉平台通道）
// - 复制为文本：要把 JSON 写进系统剪贴板
// - 从文本导入：走"粘贴 → 确认 → 落库"的整条 UI → controller → service → DB 链路
//
// 文件选择（file_picker）那条路径仍依赖真实平台，不在本文件覆盖范围内。
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:filter_flow/core/db/app_database.dart';
import 'package:filter_flow/models/app_backup.dart';
import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/providers/core_providers.dart';
import 'package:filter_flow/providers/feed_settings_provider.dart';
import 'package:filter_flow/services/backup_service.dart';
import 'package:filter_flow/ui/settings/backup_page.dart';

/// 造一份含 1 个 RSS 源 + 1 个屏蔽词的备份对象（再编码成 JSON 供"粘贴导入"用）。
AppBackup _sampleBackup() {
  return AppBackup(
    version: 1,
    exportedAt: DateTime(2026, 1, 1, 12, 0),
    settings: const FeedSettings(aggregateMode: false, showThumb: true),
    dataSources: [
      BackupDataSourceEntry(
        config: DataSourceConfig(
          id: 'rss-ui',
          name: 'UI 测试订阅',
          sourceType: DataSourceType.rss,
          apiUrl: 'https://example.com/feed.xml',
        ),
        sortOrder: 0,
      ),
    ],
    plugins: const [],
    blockedKeywords: const ['广告'],
  );
}

void main() {
  late AppDatabase db;
  // 模拟系统剪贴板内容：测试环境没有真实剪贴板，用一个内存变量替代，
  // 让"复制为文本"/"粘贴导入"这类走 Clipboard 的路径能跑通
  String? clipboardText;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 让 SharedPreferences 在测试里有实现（导入会写回全局设置）
    SharedPreferences.setMockInitialValues({});

    // 剪贴板通道（flutter/platform）：不 mock 的话 Clipboard.getData /
    // Clipboard.setData 会一直等待平台回包，导致 widget test 卡死。
    // 这里用内存变量模拟剪贴板读写，并返回约定格式（{'text': ...}）。
    const platformChannel = SystemChannels.platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return clipboardText == null
              ? null
              : <String, dynamic>{'text': clipboardText};
        case 'Clipboard.setData':
          clipboardText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          return null;
        default:
          return null;
      }
    });

    // 分享通道（share_plus）mock 掉，避免"导出为文件"时真实调系统分享面板。
    // 注意 share_plus 13.x 的 share() 内部是 channel.invokeMethod<String>('share', ...)，
    // 期望平台回一个【字符串】（任意非空串都解析成 ShareResultStatus.success），
    // 回 Map 反而会在插件里触发类型转换异常，导致导出流程中断。
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (_) async => 'shared');

    // path_provider：测试环境没有真实目录服务，mock 一个临时目录，
    // 否则 exportToFile 里的 getTemporaryDirectory() 会卡在等平台回包。
    // 注意：不要返回 Directory.systemTemp.path——在某些 CI / 沙盒里那个路径
    // 不可写会让 file.writeAsString 直接卡死；用 /tmp 最稳妥（本机与 CI 都有）。
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getLibraryDirectory':
          return '/tmp';
        default:
          return null;
      }
    });

    clipboardText = null;
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// 多次定帧推进，等价于"等动画/异步落定"，但不会被 provider 的异步刷新骗到超时。
  Future<void> _settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 把 BackupPage 挂到带内存数据库的 ProviderScope 里。
  ///
  /// 不用 pumpAndSettle：本页依赖的 sourceSortOrdersProvider 在构造时异步
  /// refresh，配合 ref.listen 会让 pumpAndSettle 的"是否静止"判定失真而超时
  /// （实际并没有死循环）。所以改用定帧 pump 等待，更稳。
  Future<void> _pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: BackupPage()),
      ),
    );
    await _settle(tester);
  }

  testWidgets('复制为文本：把合法备份 JSON 写进剪贴板', (tester) async {
    // 先放一个源，让导出的内容非空
    await db.upsertDataSource(_sampleBackup().dataSources.single.config);
    await _pumpPage(tester);

    await tester.tap(find.text('复制为文本'));
    await _settle(tester);

    // 剪贴板里应该是一份能被 BackupService 重新解析的合法备份
    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, isNotEmpty);
    final decoded = jsonDecode(clipboard!.text!) as Map<String, dynamic>;
    expect(decoded['format'], 'filterflow-backup');
    final reParsed = BackupService.parse(clipboard.text!);
    expect(reParsed.dataSources.single.config.id, 'rss-ui');

    // 同时给个"已复制"的提示
    expect(find.text('备份内容已复制到剪贴板'), findsOneWidget);
  });

  testWidgets('导出为文件：调起分享且页面回显文件路径，不崩溃', (tester) async {
    await _pumpPage(tester);

    // 导出按钮触发的是"fire-and-forget"的异步导出，内部包含真实写文件
    // （dart:io）I/O。这类真实异步不会被 pump 自动驱动，必须用 runAsync 撑住
    // 事件循环；又因为导出 future 是点击后由手势回调异步创建的，runAsync 不会
    // 自动等它，所以这里显式等一段真实时间让"写文件+分享"跑完，再 pump 让
    // "已生成："刷新到界面。
    await tester.runAsync(() async {
      await tester.tap(find.text('导出为文件'));
      await Future.delayed(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 200));
    });
    await _settle(tester);

    // mock 的分享通道被调用后，页面会把生成的临时文件路径回显给用户
    expect(find.textContaining('已生成：'), findsOneWidget);
    // 全程没有任何异常
    expect(tester.takeException(), isNull);
  });

  testWidgets('从文本导入：粘贴合法备份 → 选合并 → 落库且提示完成', (
    tester,
  ) async {
    await _pumpPage(tester);

    // 1) 点"从文本导入" → 弹出粘贴框
    await tester.tap(find.text('从文本导入'));
    await _settle(tester);

    // 2) 在输入框里粘贴备份内容
    final json = BackupService.encode(_sampleBackup());
    await tester.enterText(find.byType(TextField), json);
    await _settle(tester);

    // 3) 点"下一步" → 弹出确认框
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await _settle(tester);

    // 4) 确认框里选"合并"
    await tester.tap(find.text('合并（保留现有配置）'));
    // 导入是异步写库，等它跑完（落库后才弹 snackbar）
    await _settle(tester);

    // 5) 提示导入完成
    expect(find.textContaining('导入完成'), findsOneWidget);

    // 6) 数据库里确实多了一个源和一个屏蔽词（证明 UI → controller → service → DB 整条链路打通）
    final sources = await db.getAllDataSources();
    expect(sources.map((s) => s.id), contains('rss-ui'));
    final keywords = await db.getAllBlockedKeywords();
    expect(keywords, contains('广告'));
  });

  testWidgets('从文本导入：粘贴非法内容时只报错不崩溃', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('从文本导入'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '这不是 json');
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await _settle(tester);

    // 解析失败应弹出错误提示，且不崩溃、不误写库
    // （页面直接把 BackupFormatException 的 message 作为错误提示，
    //  非法 JSON 时 message 以"不是合法的 JSON"开头）
    expect(find.textContaining('不是合法的 JSON'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(await db.getAllBlockedKeywords(), isEmpty);
  });
}
