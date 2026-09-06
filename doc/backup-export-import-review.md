# 配置导出 / 导入功能 —— 代码审查与实现流程讲解

> 对应未提交改动：新增 5 个文件（约 1370 行）+ 6 个文件的小改动
> 新文件：`lib/models/app_backup.dart`、`lib/services/backup_service.dart`、`lib/providers/backup_provider.dart`、`lib/ui/settings/backup_page.dart`、`test/backup_test.dart`

## 一、这个功能是做什么的

在「设置」里新增「备份与恢复」页，把用户的四类配置打包成一个 `.json` 文件，支持导出和导入：

| 数据 | 存哪里 | 备份里带什么 |
|---|---|---|
| 数据源（RSS + API） | SQLite `data_sources` 表 | 完整配置 + Tab 排序序号 |
| JS 插件 | SQLite `installed_plugins` 表 | 脚本全文 + 清单 + Tab 序号（导入后无需重新下载） |
| 屏蔽词 | SQLite `blocked_keywords` 表 | 词列表（去重） |
| 全局设置（聚合模式 / 缩略图） | SharedPreferences | 开关值 |

典型场景：换手机搬配置、备份防手滑、把订阅列表分享给朋友。

导入有两种方式：

- **合并**：保留现有配置，同 id 的覆盖、新的追加（新源排在 Tab 最后）
- **覆盖**：清空现有全部配置，按备份原样重建（连 Tab 交错顺序都还原）

---

## 二、整体架构（先看全景）

```
        ┌───────────── UI 层 ─────────────┐
        │ backup_page.dart                 │
        │ 概览条数 / 导出按钮 / 导入按钮     │
        │ 确认对话框（合并 or 覆盖）        │
        └───────────────┬─────────────────┘
                        │ 只调 controller、拿结果
        ┌───────────────▼─────────────────┐
        │ 编排层 backup_provider.dart      │
        │ BackupController                │
        │ 文件读写 / 分享面板 / 刷新各列表   │
        └──────┬─────────────────┬────────┘
               │                 │
   ┌───────────▼──────┐   ┌─────▼──────────────────┐
   │ 服务层            │   │ 平台能力                │
   │ backup_service    │   │ file_picker 选文件      │
   │ 纯数据打包/写回，  │   │ share_plus 系统分享     │
   │ 不碰文件和 UI      │   │ path_provider 临时目录  │
   └───────┬──────────┘   └────────────────────────┘
           │
   ┌───────▼──────────────────────────────────────┐
   │ 数据层                                        │
   │ app_database.dart（SQLite）+ SharedPreferences │
   └──────────────────────────────────────────────┘
```

分层是这次改动最值得学的地方：**服务层（BackupService）完全不碰文件和 UI**，只负责"对象 ↔ JSON ↔ 数据库"。文件选择、系统分享这些平台能力全部隔离在编排层（BackupController）。好处立刻体现在测试里——`backup_test.dart` 传一个内存数据库就能把导出、解析、两种导入模式全部测掉，一行 mock 都不用写。

---

## 三、备份文件格式：一个可以抄的设计

`app_backup.dart` 定义了备份的 JSON 结构，三个设计决策都很经典：

### 3.1 格式"暗号"：`format` 字段

```json
{ "format": "filterflow-backup", "version": 1, ... }
```

导入时先认这个字符串，不是它就直接拒绝。防的是用户误选别的 App 导出的 JSON——没有暗号的话，任何结构碰巧相似的 JSON 都可能被"半懂不懂"地灌进数据库。

### 3.2 版本号的前向兼容规则

```dart
if (version > kBackupVersion) {
  throw BackupFormatException('备份文件版本（$version）比当前 App 支持的最高版本…新，请升级 App 后再导入');
}
```

**备份比当前 App 新 → 直接拒绝**，而不是"能读多少读多少"。因为新版本可能有当前版本不认识的新字段，硬读会恢复出一份残缺配置，用户还以为恢复成功了，实际丢了一半。反过来，比当前版本**老**的备份正常接受，将来结构变了就在解析代码里按版本写兼容分支。

### 3.3 单条损坏不拖垮整体

每条数据源 / 插件的反序列化都走 `tryFromJson`，解析失败返回 `null` 直接跳过：

```dart
static BackupDataSourceEntry? tryFromJson(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  ...
  try {
    config = DataSourceConfig.fromJson(configRaw);
  } catch (_) {
    return null;   // 跳过这一条，而不是让整份导入失败
  }
  ...
}
```

设计取舍很清楚：**整体格式错了（暗号、版本）要硬拒绝；个别条目烂了要容忍**。备份里有一个源配置写坏了，不该让用户什么都导不进来。

细节加分项：屏蔽词解析时用 `Set` 顺手去重 + `trim`；`exportedAt` / `installedAt` 解析失败用当前时间兜底（只影响展示，不值得为它失败）。

---

## 四、导出流程（逐步拆解）

用户在备份页点「导出为文件」，调用链：

```
BackupPage._exportToFile()
  └─ _runBusy(...)                        ← 统一的忙时保护（见 4.3）
      └─ BackupController.exportToFile()
          ├─ buildBackup()                ← 服务层读库打包
          │   └─ BackupService.exportBackup(settings)
          │       ├─ db.getAllDataSourceRows()   ← 读原始行：Tab 序号只在行上有
          │       ├─ db.getAllPluginRows()
          │       └─ db.getAllBlockedKeywords()
          ├─ BackupService.encode()       ← JsonEncoder.withIndent 美化
          ├─ 写入临时目录文件（文件名只生成一次！）
          └─ SharePlus.instance.share(...) ← 唤起系统分享面板
```

三个值得注意的点：

1. **为什么读"原始行"而不是模型？** Tab 排序序号（`sortOrder`）是表的列，不在 `DataSourceConfig` 模型里。导出要保住用户排好的顺序，所以必须读行。这也是为什么 DB 层把私有方法 `_rowToInstalledPlugin` 改成了公开的 `rowToInstalledPlugin` 供服务层复用。

2. **全局设置要单独传参**。数据源 / 插件 / 屏蔽词在 SQLite，但聚合模式、缩略图开关存在 SharedPreferences 里——不在数据库里就读不出来，所以 `exportBackup(settings)` 由编排层从 `feedSettingsProvider` 读好传进去。

3. **文件名一致性**（容易踩的坑）：

   ```dart
   final fileName = _backupFileName(DateTime.now());   // 只生成一次
   final file = File('${dir.path}/$fileName');
   ...
   fileNameOverrides: [fileName],   // 分享时复用同一个名字
   ```

   如果写文件时算一次时间、分享时再算一次，跨分钟就会出现"存进去叫 A、发出去叫 B"的错位。`fileNameOverrides` 则是 Android 的已知行为：缓存目录会忽略 `XFile` 自带的文件名，不显式声明用户收到的就是一串随机字符。

另外还有一条「复制为文本」的导出路径（`exportToText`），给不方便传文件的场景用，和文件导出共用同一套打包 + 编码逻辑。

---

## 五、导入流程（逐步拆解）

```
用户点「从文件导入」/「从文本导入」
  ├─ 拿内容：FilePicker.pickFiles → readAsBytes → utf8.decode
  │          或 粘贴对话框拿文本
  ├─ BackupService.parse(text)          ← 校验：空 / 非法 JSON / 顶层非对象 / 暗号 / 版本
  ├─ 弹出确认对话框 _ImportConfirmDialog
  │    显示：来源文件名、导出时间、各类条数
  │    让用户选：合并（默认推荐） or 覆盖（红色危险样式 + 不可撤销警告）
  └─ BackupController.importBackup(backup, mode)
      ├─ BackupService.importBackup     ← 整个写库包在一个事务里
      │    ├─ 合并：同 id 覆盖（保留现有 Tab 位置）、新 id 追加（序号 = 当前最大 +1 起）
      │    └─ 覆盖：清空三张表 → 按备份里存的原序号重建（交错顺序得以还原）
      ├─ 刷新三个列表 Provider（数据源 / 插件 / 屏蔽词的 reload()）
      ├─ sourceSortOrdersProvider.refresh()   ← Tab 序号重新读库
      └─ feedSettingsProvider.apply(backup.settings)   ← 开关写回 SharedPreferences
```

### 5.1 事务：导入要么全成，要么全不做

```dart
Future<ImportResult> importBackup(AppBackup backup, {required ImportMode mode}) {
  return _db.transaction(() async { ... });
}
```

覆盖模式是"先清空三张表再重建"，如果重建到一半出错（比如某条数据触发了约束），没有事务的话用户会看到"源导进来一半、插件没了"的半吊子状态。包在事务里，中途任何异常整体回滚，数据库回到导入前的样子。

### 5.2 合并模式的序号策略（延续 Tab 排序功能的设计）

数据源和插件**共用一套全局序号**（上个功能定的规矩），所以合并导入时：

- **已存在的源**：覆盖配置，但沿用本地现在的序号——不打扰用户已经排好的顺序（备份里存的序号直接丢弃）；
- **新源**：从 `当前最大序号 + 1` 开始递增分配，排在所有现有 Tab 后面，避免和已有编号撞车。测试里专门锁住了这条行为（本地有源序号 5，导入两个新源应拿到 6、7）。

覆盖模式则相反——三张表已清空，直接用备份里存的原序号写回，这样"插件排在数据源前面"这种跨表交错顺序才能被还原。

### 5.3 Provider 刷新链：写库之后界面怎么自己变

数据库改完了，但界面上各 Provider 还持有旧数据。Controller 逐个触发刷新：

```dart
await _ref.read(dataSourcesProvider.notifier).reload();       // 三个列表各自重载
await _ref.read(installedPluginsProvider.notifier).reload();
await _ref.read(blockedKeywordsProvider.notifier).reload();
await _ref.read(sourceSortOrdersProvider.notifier).refresh(); // Tab 序号
await _ref.read(feedSettingsProvider.notifier).apply(...);    // SharedPreferences 单独写
```

为此，三个列表 Notifier 各加了一个 `reload()` 方法（就是暴露私有的 `_load()`）。而信息流本身**不需要手动刷新**：`dataSourcesProvider` 一变 → `allFeedSourcesProvider` 自动重建 → `FeedNotifier` 自动重拉——响应式框架的依赖链替你完成了最后一步。

### 5.4 `_runBusy`：UI 层统一的忙时保护

```dart
Future<void> _runBusy(Future<void> Function() action) async {
  setState(() => _busy = true);
  try {
    await action();
  } on BackupFormatException catch (e) {
    if (mounted) _showError(e.message);          // 格式错误直接展示原因
  } catch (e) {
    if (mounted) _showError('操作失败：$e');       // 兜底，绝不留转圈
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}
```

三个好习惯值得抄：① 处理期间 `_busy = true`，所有按钮 `enabled: !_busy` 防重复点击；② 每个 `await` 之后、每次 `setState` 之前都检查 `mounted`（页面可能已被用户返回关掉）；③ `finally` 里恢复 `_busy`，无论成功失败页面都不会卡在转圈状态。

---

## 六、代码评价

### 做得好的地方

| 方面 | 评价 |
|---|---|
| **分层边界清晰** | 服务层不碰文件 / UI，编排层不做数据逻辑，UI 不碰数据库。收益直接兑现在测试上：内存数据库就能覆盖全链路 |
| **备份格式设计成熟** | 格式暗号、版本号"新拒老容"、单条损坏跳过而非整体失败——三条规则把"导入别人的烂文件"这种脏活全防住了 |
| **事务保护破坏性操作** | 覆盖模式的清空 + 重建在一个事务里，异常整体回滚。这是"危险操作"代码的底线，很多项目会漏 |
| **和已有功能的衔接想过了** | Tab 序号的合并 / 覆盖策略分别设计且有测试；导入后靠 Provider 依赖链自动刷新信息流，没有遗漏的状态 |
| **用户体验细节** | 导入前确认对话框展示备份摘要；覆盖用红色危险样式 + "不可撤销"警告；导出后显示文件路径；`ImportResult.summary` 把"导进来多少"说清楚 |
| **平台坑注释** | 文件名只生成一次、`fileNameOverrides`、`readAsBytes` 而非读路径（macOS 沙盒）——全是踩过才写得出的注释 |
| **依赖克制** | 只新增 `file_picker` 一个依赖，`share_plus` / `path_provider` 复用已有 |

### 可改进的地方（按重要性排序）

1. **安全边界值得明示**：备份会把插件 JS 脚本**全文打包**，导入 = 执行别人写的脚本。项目有 JS 沙箱（`plugin_feed_repository`）兜底，风险可控，但确认对话框里可以加一句"备份中的插件脚本将被直接运行"的提示，把信任边界讲清楚。
2. **`AppBackup.isEmpty` 是死代码**：定义了但导出 / 导入 / UI 都没调用。要么用起来（导出前空配置时提醒用户），要么删掉。另外它没把 `settings` 算进去，语义也不完整。
3. **非 UTF-8 文件的错误信息不友好**：`pickBackupFile` 里 `utf8.decode` 遇到 UTF-16 等编码会抛 `FormatException`，被 `_runBusy` 兜底捕获后只显示通用的"操作失败：…"。可以捕获后包装成 `BackupFormatException('文件编码不是 UTF-8…')`，和别的导入错误口径一致。
4. **重复逻辑**：`BackupService._nextAvailableOrder` 和 `AppDatabase._nextSortOrder` 是同一段"最大值 +1"，可以复用后者（改成公开）而不是写两份。
5. **备份内重复 id 的小边角**：合并模式里 `existingSourceIds` 在循环前一次性取快照，同一份备份里若出现两条同 id 的新源，两条都走"追加"分支，第二条覆盖第一条但浪费一个序号。不会出错，但解析时顺手按 id 去重更干净。
6. **测试小空白**：`tryFromJson` 的坏条目跳过分支（缺脚本 / 缺 manifest）没有直接测试；编排层的 Provider 刷新顺序（尤其"设置最后写"）也没有测试。前者补起来很便宜。
7. **分层小瑕疵**：`app_backup.dart`（models 目录）import 了 `providers/feed_settings_provider.dart` 里的 `FeedSettings`。`FeedSettings` 本质是个数据类，放在 providers 目录导致 model 反向依赖 provider 层。把 `FeedSettings` 挪到 models 即可理顺。

### 总评

**88 分左右，可以放心合入**。比"功能能跑"高出一截的地方在于：它对"导入一份不可信的外部文件"这件危险的事做了系统性的防御（暗号、版本、逐条容错、事务、确认对话框、危险操作红字警告），并且把平台集成和数据逻辑切得很干净，使核心逻辑在纯内存环境里可测。上面列的问题都是打磨级别的，其中第 1 条（脚本信任边界提示）建议顺手补上，其余可以进待办。

---

## 七、给初级程序员的复习清单

1. 备份文件里的 `format` 暗号和 `version` 字段，分别防的是什么问题？为什么"备份版本更新"要拒绝而不是硬读？
2. "单条数据解析失败返回 `null` 跳过"和"抛异常终止"，各自适合什么场景？
3. 为什么覆盖导入必须包在数据库事务里？没有事务，最坏的用户体验是什么？
4. 合并导入时，为什么已存在的源要**丢弃**备份里的序号、而新源要从"最大序号 +1"开始排？
5. 写完数据库之后，为什么还要手动 `reload()` 三个列表 Provider？信息流列表为什么又不需要手动刷新？
6. `_runBusy` 里的 `mounted` 检查防的是什么？不加会出什么问题？
