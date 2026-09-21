import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:filter_flow/core/db/app_database.dart';
import 'package:filter_flow/models/data_source_config.dart';
import 'package:filter_flow/models/feed_article.dart';
import 'package:filter_flow/plugin/models/installed_plugin.dart';
import 'package:filter_flow/plugin/models/plugin_manifest.dart';
import 'package:filter_flow/providers/feed_list_provider.dart';
import 'package:filter_flow/services/feed_source.dart';
import 'package:filter_flow/ui/feed/widgets/feed_source_tab_bar.dart';

/// 一个极简的假数据源：只为了测排序，不需要真的去拉数据。
class _FakeFeedSource implements FeedSource {
  @override
  final String id;
  @override
  final FeedSourceStorage storage;

  const _FakeFeedSource(this.id, this.storage);

  @override
  String get name => id;

  @override
  bool get enabled => true;

  @override
  DetailRenderMode get detailMode => DetailRenderMode.webview;

  @override
  String? get detailUrlTemplate => null;

  @override
  bool get useAppDeepLink => true;

  @override
  bool get supportsPagination => false;

  @override
  Future<List<FeedArticle>> fetchFeed({
    required int page,
    int pageSize = 20,
  }) async => const [];
}

DataSourceConfig _rssConfig(String id) => DataSourceConfig(
  id: id,
  name: id,
  apiUrl: 'https://example.com/$id.xml',
  sourceType: DataSourceType.rss,
);

InstalledPlugin _plugin(String id) => InstalledPlugin(
  id: id,
  name: id,
  scriptContent: '// empty',
  manifest: PluginManifest(id: id, name: id, version: '1.0.0'),
  sourceUrl: 'https://example.com/$id.js',
  enabled: true,
  installedAt: DateTime(2026),
  version: '1.0.0',
);

/// 拖拽测试用的宿主：给 FeedSourceTabBar 提供一个 TabController。
class _TabBarHarness extends StatefulWidget {
  final List<FeedSource> sources;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// 限制 Tab 栏宽度（测居中时用：宽度有限才滚得起来）。
  /// 不传就是撑满可用宽度。
  final double? width;

  /// 初始选中第几个 Tab（用来验证"启动就恢复某个靠后的 Tab"）
  final int initialIndex;

  /// 控制器建好后回调出去，方便测试里模拟"从别处切 Tab"。
  final ValueChanged<TabController>? onController;

  const _TabBarHarness({
    required this.sources,
    required this.onReorder,
    this.width,
    this.initialIndex = 0,
    this.onController,
  });

  @override
  State<_TabBarHarness> createState() => _TabBarHarnessState();
}

class _TabBarHarnessState extends State<_TabBarHarness>
    with TickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: widget.sources.length,
      initialIndex: widget.initialIndex,
      vsync: this,
    );
    widget.onController?.call(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只挂 Tab 栏即可（它不依赖 TabBarView），避免为了凑长度写无用的子页
    final bar = FeedSourceTabBar(
      sources: widget.sources,
      controller: _controller,
      onReorder: widget.onReorder,
    );
    final width = widget.width;
    if (width == null) return bar;
    return Center(
      child: SizedBox(width: width, child: bar),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('新增的数据源按添加顺序拿到递增的 Tab 序号', () async {
    await db.upsertDataSource(_rssConfig('a'));
    await db.upsertDataSource(_rssConfig('b'));
    await db.upsertInstalledPlugin(_plugin('p'));

    final orders = await db.getAllSortOrders();
    // 第一个从 0 开始，之后依次 +1，插件也共用同一套编号
    expect(orders, {'a': 0, 'b': 1, 'p': 2});
  });

  test('编辑已有数据源不会把它挤到末尾', () async {
    await db.upsertDataSource(_rssConfig('a'));
    await db.upsertDataSource(_rssConfig('b'));

    // 改个名字再存一次
    await db.upsertDataSource(_rssConfig('a').copyWith(name: '改名后的 a'));

    final orders = await db.getAllSortOrders();
    expect(orders['a'], 0, reason: '编辑后应保持原来的 Tab 位置');
  });

  test('拖动排序后序号写回数据库，且数据源与插件可交错排列', () async {
    await db.upsertDataSource(_rssConfig('a'));
    await db.upsertDataSource(_rssConfig('b'));
    await db.upsertInstalledPlugin(_plugin('p'));

    // 模拟用户把插件 p 拖到第一位：新顺序是 p -> b -> a
    await db.updatePluginSortOrders({'p': 0});
    await db.updateDataSourceSortOrders({'b': 1, 'a': 2});

    final orders = await db.getAllSortOrders();
    expect(orders, {'p': 0, 'b': 1, 'a': 2});

    // 合并排序后能还原出"插件夹在数据源中间"的顺序，而不是按表分堆
    final merged = <FeedSource>[
      const _FakeFeedSource('a', FeedSourceStorage.dataSource),
      const _FakeFeedSource('b', FeedSourceStorage.dataSource),
      const _FakeFeedSource('p', FeedSourceStorage.plugin),
    ];
    final sorted = sortSourcesByTabOrder(merged, orders);
    expect(sorted.map((s) => s.id).toList(), ['p', 'b', 'a']);
  });

  test('没有排序记录的源排在最后，而不是挤到最前面', () async {
    await db.upsertDataSource(_rssConfig('a'));
    await db.upsertDataSource(_rssConfig('b'));

    // 只为 a 写序号，b 在映射里查不到
    final orders = {'a': 0};
    final merged = <FeedSource>[
      const _FakeFeedSource('a', FeedSourceStorage.dataSource),
      const _FakeFeedSource('b', FeedSourceStorage.dataSource),
    ];

    expect(sortSourcesByTabOrder(merged, orders).map((s) => s.id).toList(), [
      'a',
      'b',
    ]);
  });

  testWidgets('长按拖动 Tab：拖拽过程不报错，并回调新的位置', (tester) async {
    // 这个用例专门守住一个坑：拖动时被拖项会被移进 Overlay 渲染，
    // 那里没有 Scaffold 提供的 Material，若 Tab 内部的 InkWell 没有
    // 自带 Material 就会抛 "No Material widget found"。
    const sources = <FeedSource>[
      _FakeFeedSource('a', FeedSourceStorage.dataSource),
      _FakeFeedSource('b', FeedSourceStorage.dataSource),
      _FakeFeedSource('c', FeedSourceStorage.dataSource),
    ];
    final reorders = <List<int>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TabBarHarness(
            sources: sources,
            onReorder: (oldIndex, newIndex) {
              reorders.add([oldIndex, newIndex]);
            },
          ),
        ),
      ),
    );

    // 长按第一个 Tab 触发拖拽，再往右拖过后面的 Tab
    final start = tester.getCenter(find.text('a'));
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout); // 等长按被识别
    await gesture.moveBy(const Offset(400, 0));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    // 不抛异常，且确实触发了重排回调
    expect(tester.takeException(), isNull);
    expect(reorders, isNotEmpty, reason: '拖动后应该回调 onReorder');
    expect(reorders.first.first, 0, reason: '拖动的是第一个 Tab');
  });

  group('选中的 Tab 自动居中', () {
    // 12 个 Tab、Tab 栏只给 300 宽 → 必然要横向滚动才看得全
    const tabNames = <String>[
      '源一号',
      '源二号',
      '源三号',
      '源四号',
      '源五号',
      '源六号',
      '源七号',
      '源八号',
      '源九号',
      '源十号',
      '源甲号',
      '源乙号',
    ];

    List<FeedSource> centeringSources() => [
      for (final name in tabNames)
        _FakeFeedSource(name, FeedSourceStorage.dataSource),
    ];

    /// Tab 栏可视区（视口）的矩形
    Rect barRect(WidgetTester tester) =>
        tester.getRect(find.byType(FeedSourceTabBar));

    /// 某个 Tab **整项**的矩形（含左右各 16 的内边距），不是里面那行文字。
    ///
    /// 这里必须显式写 `skipOffstage: false`：finder 默认只找"当前画在可视区里"的东西，而 Tab 栏为了能定位屏幕外的项，把它们都提前搭出来了（见源码里的 cacheExtent），那些项在 finder 眼里属于 offstage，不加这个参数就找不到。
    Rect tabRect(WidgetTester tester, String name) => tester.getRect(
      find
          .ancestor(
            of: find.text(name, skipOffstage: false),
            matching: find.byType(InkWell, skipOffstage: false),
          )
          .first,
    );

    Future<void> pumpBar(
      WidgetTester tester,
      List<FeedSource> sources, {
      ValueChanged<TabController>? onController,
      int initialIndex = 0,
    }) async {
      // 点击 Tab 会读全局设置（要不要振动），所以得有 ProviderScope；
      // 顺手把 SharedPreferences 换成内存实现，不然读设置会卡在平台通道上。
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TabBarHarness(
                sources: sources,
                width: 300,
                initialIndex: initialIndex,
                onController: onController,
                onReorder: (_, _) {},
              ),
            ),
          ),
        ),
      );
      // 居中是在帧末回调里启动的滚动动画，要等它跑完才能断言位置
      await tester.pumpAndSettle();
    }

    testWidgets('点击某个 Tab 后，它停在 Tab 栏正中间', (tester) async {
      await pumpBar(tester, centeringSources());

      // 「源三号」初始就在可视区里，点得到
      await tester.tap(find.text('源三号'));
      await tester.pumpAndSettle();

      expect(
        tabRect(tester, '源三号').center.dx,
        closeTo(barRect(tester).center.dx, 1.0),
        reason: '点击的 Tab 应该滚到正中间',
      );
    });

    testWidgets('从别处切到屏幕外的 Tab（如"全部数据源"面板），也会居中', (tester) async {
      late TabController controller;
      await pumpBar(
        tester,
        centeringSources(),
        onController: (c) => controller = c,
      );

      // 第 6 个初始完全在屏幕外（视口只看得到前 4 个）
      expect(
        tabRect(tester, '源六号').left,
        greaterThan(barRect(tester).right),
        reason: '前置条件：这时候它确实在屏幕外',
      );

      controller.animateTo(5);
      await tester.pumpAndSettle();

      expect(
        tabRect(tester, '源六号').center.dx,
        closeTo(barRect(tester).center.dx, 1.0),
        reason: '屏幕外的 Tab 被选中后也要滚进正中间',
      );
    });

    testWidgets('首次进入就选中靠后的 Tab 时，首帧也会居中', (tester) async {
      await pumpBar(tester, centeringSources(), initialIndex: 5);

      expect(
        tabRect(tester, '源六号').center.dx,
        closeTo(barRect(tester).center.dx, 1.0),
        reason: '启动就恢复某个 Tab 时，它不能藏在屏幕外',
      );
    });

    testWidgets('靠边的 Tab 滚到能滚的极限位置为止，不会崩也不会留空', (tester) async {
      late TabController controller;
      await pumpBar(
        tester,
        centeringSources(),
        onController: (c) => controller = c,
      );

      // 最后一个 Tab 的右边没内容了，居中不了，只能贴右边缘
      controller.animateTo(11);
      await tester.pumpAndSettle();

      final viewportRect = barRect(tester);
      final lastTab = tabRect(tester, '源乙号');
      expect(tester.takeException(), isNull);
      expect(
        lastTab.right,
        closeTo(viewportRect.right, 1.0),
        reason: '滚到底时最后一个 Tab 应该刚好贴住右边缘',
      );
      // 第一个 Tab 同理：滚到最左边时贴住左边缘（不能滚出负偏移）
      controller.animateTo(0);
      await tester.pumpAndSettle();
      expect(
        tabRect(tester, '源一号').left,
        closeTo(viewportRect.left, 1.0),
        reason: '滚到顶时第一个 Tab 应该刚好贴住左边缘',
      );
    });
  });

  test('老用户从 schema v2 升级到 v3：数据不丢、新列可用', () async {
    // 这一段很关键：App 已经有人在用，升级时如果迁移写错会直接崩。
    // 做法是先用原生 sqlite3 造一个"老版本"的数据库文件，
    // 再用当前代码打开，验证迁移能正常跑通。
    final dir = Directory.systemTemp.createTempSync('filter_flow_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/old.sqlite');

    final raw = sqlite3.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE data_sources (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        config TEXT NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      CREATE TABLE blocked_keywords (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE installed_plugins (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        script_content TEXT NOT NULL,
        manifest_json TEXT NOT NULL,
        source_url TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        installed_at INTEGER NOT NULL,
        version TEXT NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    // 造一条老数据（config 列存的是 DataSourceConfig 的 JSON）
    raw.execute(
      "INSERT INTO data_sources (id, name, enabled, config) VALUES "
      "('old1', '老数据源', 1, '{\"id\":\"old1\",\"name\":\"老数据源\","
      "\"sourceType\":\"rss\",\"apiUrl\":\"https://example.com/old.xml\","
      "\"method\":\"GET\",\"detailMode\":\"webview\",\"enabled\":true}')",
    );
    raw.execute('PRAGMA user_version = 2;');
    raw.close();

    // 用当前代码打开：应该自动执行 v2 -> v3 的加列迁移
    final db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);

    // 老数据还在
    final list = await db.getAllDataSources();
    expect(list.single.id, 'old1');
    expect(list.single.name, '老数据源');

    // 迁移加的 sort_order 列可读，默认值为 0
    final orders = await db.getAllSortOrders();
    expect(orders, {'old1': 0});

    // 迁移后依然能正常写入新序号（模拟用户拖动排序）
    await db.updateDataSourceSortOrders({'old1': 3});
    expect(await db.getAllSortOrders(), {'old1': 3});
  });

  test('序号相同的源保持原有相对顺序（排序稳定）', () {
    // 老数据迁移后序号全是 0，此时不应该随机打乱
    final orders = {'a': 0, 'b': 0, 'c': 0};
    final merged = <FeedSource>[
      const _FakeFeedSource('a', FeedSourceStorage.dataSource),
      const _FakeFeedSource('b', FeedSourceStorage.dataSource),
      const _FakeFeedSource('c', FeedSourceStorage.plugin),
    ];

    expect(sortSourcesByTabOrder(merged, orders).map((s) => s.id).toList(), [
      'a',
      'b',
      'c',
    ]);
  });
}
