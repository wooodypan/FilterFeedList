# 顶部 Tab 拖动排序功能 —— 代码审查与实现流程讲解

> 对应提交：`87252fb` 「增加顶部tab标签排序功能」（12 个文件，+873 / -49 行）

## 一、这个功能是做什么的

信息流页面顶部有一排数据源 Tab（API 源 / RSS 源 / JS 插件源）。本次提交让用户可以**长按任意 Tab 左右拖动**来调整它们的先后顺序，并且：

- 拖完立刻生效（Tab 按新顺序重排，正在看的源跟着走，不会跳走）；
- 顺序**持久化**到 SQLite，下次启动 App 还保持这个顺序；
- 数据源和插件存在两张不同的表里，但拖动后可以交错排列（插件 Tab 可以排在数据源 Tab 前面），顺序照样能还原。

---

## 二、整体数据流（先看全景再看细节）

```
┌─────────────────────── UI 层 ───────────────────────┐
│ feed_list_page.dart      feed_source_tab_bar.dart   │
│  用户长按拖动 Tab ──→ onReorder(oldIndex,newIndex)   │
│  TabBar 按 tabOrders 排序后渲染                      │
└──────────────┬──────────────────────▲───────────────┘
               │ saveOrder(新顺序列表)   │ watch 排序映射
┌──────────────▼──────────────────────┴───────────────┐
│ Provider 层（feed_list_provider.dart）               │
│  SourceSortOrderNotifier                            │
│  1. 先更新内存 Map<id, 序号>  ← Tab 立刻重排          │
│  2. 再写回数据库            ← 下次启动顺序还在        │
└──────────────┬────────────────────────▲─────────────┘
               │ updateXxxSortOrders     │ getAllSortOrders()
┌──────────────▼────────────────────────┴─────────────┐
│ 存储层（app_database.dart）                          │
│  data_sources.sort_order + installed_plugins.sort_order
│  两表共用一套全局序号，读时合并、写时按表分批          │
└─────────────────────────────────────────────────────┘
```

核心思路一句话：**序号（sortOrder）是每行数据自己的属性，存两张表里；读出来合并成一个 `Map<id, 序号>`，UI 拿它对 Tab 列表排序；用户拖动后按新顺序重新编号（0,1,2…）写回。**

---

## 三、逐层讲解实现

### 3.1 存储层：加一列 + 一次数据库迁移

**加列**（`data_source_table.dart` / `installed_plugin_table.dart`）：

```dart
IntColumn get sortOrder => integer().withDefault(const Constant(0))();
```

两表都加了一个非空、默认 0 的整数列。注释里点明了一个关键决策：**序号是“全局”的**——两张表共用一套编号，而不是各排各的。这样"插件排在数据源前面"这种交错顺序才可能被还原。

**迁移**（`app_database.dart`）：

```dart
@override
int get schemaVersion => 3;   // 2 -> 3

MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (migrator, from, to) async {
    if (from < 3) {
      await migrator.addColumn(dataSources, dataSources.sortOrder);
      await migrator.addColumn(installedPlugins, installedPlugins.sortOrder);
    }
  },
);
```

给初级程序员的三个要点：

1. **schemaVersion 必须手动 +1**。drift 看到 version 变了才会触发 `onUpgrade`，忘了加号迁移根本不会跑。
2. `addColumn` 要求新列**有默认值或可空**，否则老行没值可填、迁移会失败。这里默认 0 刚好满足。
3. 全新安装不走 `onUpgrade`，drift 直接 `createAll()` 建出含新列的完整表——所以迁移代码只需要考虑"老用户升级"这一条路径。

**upsert 时保住原有顺序**（`upsertDataSource` / `upsertInstalledPlugin`）：

```dart
final existingRow = await (select(dataSources)
      ..where((t) => t.id.equals(config.id))).getSingleOrNull();

await into(dataSources).insertOnConflictUpdate(
  DataSourcesCompanion.insert(
    ...
    sortOrder: Value(existingRow?.sortOrder ?? await _nextSortOrder()),
  ),
);
```

先查一次旧行：存在就**沿用原序号**（否则用户只是改个名字，Tab 就被挤到最后，体验很差）；不存在（新增）就问 `_nextSortOrder()` 要"当前最大序号 + 1"，排到队尾。

**读写序号的三个方法**：

- `getAllSortOrders()`：查两张表，合并成 `Map<String, int>`。交错排序靠的就是"读的时候合"。
- `updateDataSourceSortOrders()` / `updatePluginSortOrders()`：按表分批写回，用 drift 的 `batch` 把多条 UPDATE 打包成**一次**数据库往返，比循环里逐条 `await` 快得多。
- `_nextSortOrder()`：`orders.values.reduce(max) + 1`。删除源留下的序号"空洞"（比如 0,2,5）不影响正确性——排序只比大小，不要求连续。

### 3.2 Provider 层：先改内存，再写磁盘

`feed_list_provider.dart` 里新增了一个独立的状态机：

```dart
final sourceSortOrdersProvider =
    StateNotifierProvider<SourceSortOrderNotifier, Map<String, int>>((ref) {
  ...
  ref.listen(dataSourcesProvider, (_, __) => notifier.refresh());
  ref.listen(installedPluginsProvider, (_, __) => notifier.refresh());
  return notifier;
});
```

`ref.listen` 让它在**数据源/插件有任何增删改时自动重新读库**——新加的源要拿到它刚分配的序号。

`saveOrder` 是拖动回调的落点，两步走：

```dart
Future<void> saveOrder(List<FeedSource> ordered) async {
  // 1. 按"列表下标"重新编号（0,1,2... 天然就是最终顺序），
  //    并按 storage 字段分成两批——因为要写回不同的表
  for (var i = 0; i < ordered.length; i++) {
    switch (ordered[i].storage) {
      case FeedSourceStorage.dataSource: configOrders[ordered[i].id] = i;
      case FeedSourceStorage.plugin:     pluginOrders[ordered[i].id] = i;
    }
  }
  // 2. 先更新内存（UI 立刻重排，不卡顿），再异步写库
  state = {...configOrders, ...pluginOrders};
  await _db.updateDataSourceSortOrders(configOrders);
  await _db.updatePluginSortOrders(pluginOrders);
}
```

"先内存后写库"是 UI 状态管理的常见套路：界面响应速度取决于内存更新，磁盘写入哪怕失败（断电、异常），最坏结果也只是"下次启动回到旧顺序"，界面不会回退、不会报错给用户。

**两个非常值得学的"防御性设计"注释**（都在这个提交里写明了）：

- **为什么不把序号塞进 `DataSourceConfig`？** 因为 `JsonPathFeedSource` 的相等判断基于 config 对象，而 config 是 `feedTabProvider(source)` 这个 family provider 的 key。config 一变 → key 变 → 所有 Tab 的信息流被**重新拉取**。排序只是显示顺序，不该付出重拉全部数据的代价。所以单独开一个 provider 存 `Map<id, int>`，两者彻底解耦。
- **为什么 `allFeedSourcesProvider` 故意不排序？** 它被聚合模式的信息流依赖。如果在这里排序，序号一变整个列表就"变值"→ 聚合流重建 → 又是全量重拉。所以原始列表保持不动，只在 Tab 模式的 UI 层调用 `sortSourcesByTabOrder()` 按需排序。**"数据按最小影响面变化"** 是 Riverpod 这类响应式框架里省流量的关键手法。

### 3.3 排序函数：一个容易被忽视的稳定性问题

```dart
List<FeedSource> sortSourcesByTabOrder(
  List<FeedSource> sources, Map<String, int> orders) {
  const unknownOrder = 1 << 30;   // 查不到序号的源排最后，而不是挤到最前
  final indexed = sources.indexed.toList()
    ..sort((a, b) {
      final byOrder = (orders[a.$2.id] ?? unknownOrder)
          .compareTo(orders[b.$2.id] ?? unknownOrder);
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);  // 次要键：原始下标
    });
  return indexed.map((e) => e.$2).toList();
}
```

两个细节都对应真实的坑：

1. `orders[id] ?? unknownOrder`：刚新增还没写入映射的源排到**最后**。如果默认 0，新源会插队到第一名。
2. Dart 的 `List.sort` **不是稳定排序**。老用户迁移后所有人的序号都是 0，只按序号排会随机打乱。把"合并时的原始下标"当次要排序键，相同序号就保持原有相对顺序。

### 3.4 UI 层：手写可拖动的 TabBar

这是改动最大、坑最多的部分。

**为什么从 `DefaultTabController` 改成自己持有 `TabController`？** 因为 `_TabbedFeedView` 要在两种变化下做出不同反应，`DefaultTabController` 帮不上忙：

- **数量变了**（新增/删除/停用源）：旧控制器的索引全部失效，直接销毁重建、回到第一个 Tab；
- **数量没变但顺序变了**（用户拖动）：记录"当前正在看的源 id"，在新列表里找到它的新下标，`animateTo` 过去——用户拖完 Tab **视线里的内容不变**，而不是停在旧索引上看别的源。

```dart
@override
void didUpdateWidget(covariant _TabbedFeedView oldWidget) {
  if (old.length != next.length) { /* 重建控制器，回到第 0 个 */ }
  else if (!_isSameOrder(old, next)) {
    final currentId = old[_tabController!.index].id;
    final newIndex = next.indexWhere((s) => s.id == currentId);
    _tabController!.animateTo(newIndex);
  }
}
```

**为什么用 `SliverReorderableList` 重造 TabBar，而不用现成组件？** Flutter 官方的 `TabBar` 不支持拖动重排，`ReorderableListView` 又是纵向列表。所以用 `CustomScrollView + SliverReorderableList` 横向滚动 + 长按拖动，每个 Tab 自己画（选中下划线、加粗文字），牺牲了一点默认样式换来了拖拽能力。

**三个必须知道的坑**（测试里专门守住）：

1. **用 `ReorderableDelayedDragStartListener`（长按触发），不要用 `ReorderableDragStartListener`（按下即拖）**。后者会把"点击切换 Tab"的手势吃掉，Tab 变得点不动。
2. **`ReorderableList` 系列给的 `newIndex` 已经按"先移除旧项"修正过**，直接 `removeAt(oldIndex)` 再 `insert(newIndex)` 即可。（注意：普通 `ReorderableListView.onReorder` 反而要求你手动做 `newIndex > oldIndex ? newIndex - 1 : newIndex` 的修正——两个 API 行为不同，别背错。）
3. **每个 Tab 要自己包一层透明的 `Material`**。拖动时被拖项会被搬到 Overlay 浮层里渲染，浮层上方没有 Scaffold 提供的 Material，`InkWell` 找不到它就抛 `No Material widget found`。包一层 `Material(color: Colors.transparent)` 两边都能画水波纹。

**`ValueKey` 的两处使用**也是初级常见盲区：

- 每个 tab 子项 `key: ValueKey(source.id)`：重排时框架靠 key 识别"这是哪一个"，漏了就顺序错乱；
- 每个 TabBarView 子页 `key: ValueKey(s.id)`：不加的话，顺序变化后 Flutter 可能错误复用"第 2 页"的滚动位置给"第 3 页"。

---

## 四、代码评价

### 做得好的地方（值得照着写）

| 方面 | 评价 |
|---|---|
| **分层清晰** | UI（拖动手势）→ Provider（状态+落库时机）→ DB（纯存取），每层职责单一，改哪层都不牵连别的层 |
| **架构决策有注释讲 why** | "序号为什么不进 config"、"为什么 allFeedSourcesProvider 不排序"，这些不写下来半年后自己都看不懂，是这个提交最值钱的部分 |
| **老数据兼容想得全** | schemaVersion 迁移、upsert 沿用旧序号、迁移后全 0 的稳定排序兜底、查不到序号的排最后——四个"升级场景"全部覆盖 |
| **测试质量高** | 7 个用例不是凑数：数据库序列号分配、编辑保位、跨表交错、未知序号兜底、拖动手势不崩（Overlay/Material 坑的回归测试）、**用原生 sqlite3 造真·v2 库文件验证迁移**、稳定排序。尤其迁移测试，直接把"迁移写错上线就崩"这种事故在 CI 里拦住了 |
| **依赖克制** | 只为测试加了 dev 依赖 `sqlite3`（运行时 drift 已间接引入），没有引入任何拖拽/排序三方库 |
| **增量小而聚焦** | 873 行里约 1/3 是注释和测试，业务代码本身不到 400 行，没有顺手重构无关代码 |

### 可改进的地方（按重要性排序）

1. **`SourceSortOrderNotifier.saveOrder` 没有直接测试**。测试直接调了 db 层方法，但"按 storage 分表 + 按下标编号"这段分发逻辑本身没被测到。建议补一个 notifier 级别用例（甚至 fake db），把 0..n 编号规则锁住。
2. **upsert 的"先查后写"没有包在事务里**。理论上两次并发 upsert 会读到同一个 `null` 旧行、算出相同的 `_nextSortOrder()`。实际 UI 调用是串行的，风险极低，但用 `transaction((_) async {...})` 包一下更严谨。
3. **停用的源会留下"过期序号"**。`saveOrder` 只给**启用中**的源重新编号，停用源在 DB 里还持有旧序号。之后重新启用它，可能带着旧序号"跳"到奇怪的位置（有稳定排序兜底不至于错乱，但可能不合预期）。改进思路：启用/停用切换时也重排一次，或 saveOrder 时把停用源排到启用源之后统一编号。
4. **`_onTick` 对 controller 的每一次 tick 都 `setState`**。Tab 左右滑动的动画期间每帧都整栏重建。Tab 数量少时无感，若将来 Tab 很多可换成 `AnimatedBuilder(animation: controller)` 只重建受影响的子项。属于提前优化，现在不必做。
5. **手绘 TabBar 丢失了官方 TabBar 的部分能力**（如 `indicatorSize`、无障碍 semantics 标注）。功能上没缺失，但如果后续需要更"Material"的视觉细节，要继续手写补齐。

### 总评

**这是一个可以当作教学样本的提交**（给初级程序员的标准打个比方：90 分）。业务代码不到 400 行就完成了跨两张表的持久化排序，真正的价值在于：

- 对"哪些状态变化会触发重拉数据"有清醒认知，用独立 provider + 故意不排序的原始列表，把显示顺序和数据加载彻底解耦；
- 把升级迁移、重复 upsert、稳定排序、手势冲突、Overlay 缺 Material 这类**只有踩过才知道的坑**全部预防或测试覆盖；
- 注释全部在讲"为什么这么设计"而不是"这行代码在干什么"，半年后接手的人能直接读懂决策依据。

要挑刺的话，主要是测试覆盖在 notifier 层有一小块空白，以及几个"现在没痛、将来可能痛"的小隐患（事务、停用源序号），都属于锦上添花的改进。

---

## 五、给初级程序员的复习清单

读完本文，建议你能不查代码回答这几个问题：

1. 为什么排序序号单独开 provider 存，而不放进 `DataSourceConfig`？
2. schemaVersion 从 2 改到 3 之后，drift 在"全新安装"和"老用户升级"两种场景下分别走哪条路径？
3. `List.sort` 为什么需要次要排序键？什么情况下会踩这个坑？
4. `ReorderableDragStartListener` 和 `ReorderableDelayedDragStartListener` 的区别，选错的后果是什么？
5. 拖动时 `No Material widget found` 是怎么发生的？怎么修？
6. "先更新内存 state，再异步写数据库"的好处和最坏情况各是什么？
