# 插件系统架构文档（Plugin System Architecture）

> 面向**维护者 / 贡献者**：本文说明 FilterFlow 的插件系统“是怎么搭建起来的”——沙箱引擎选型、运行时设计、安全边界、数据模型、持久化、以及与原有 JSONPath 数据源如何并存。
>
> 如果你是要**写插件**而不是直接改系统，请看另一篇 [`插件开发文档.md`](./插件开发文档.md)，那里讲的是插件作者要遵守的契约（`buildRequest` / `parseResponse`、manifest 格式、内置工具库）。

---

## 1. 为什么需要插件系统

FilterFlow 的核心卖点是“零代码接入任意 API”。基础方案是 **JSONPath 声明式配置**：用户填一份字段映射规则（`listPath` / `titlePath` …），App 用通用解析器把任意 JSON 转成统一文章。这套方案对“公开、结构规整、无需鉴权”的 API 足够好。

但现实里很多内容源：

- 需要**签名 / 时间戳 / 随机数**参与请求构造（如 HMAC）；
- 响应结构是**层层嵌套、字段名不规范**，需要写逻辑去拍平；
- 干脆就是**反爬 / 私有接口**，必须用脚本才能稳定解析。

这些场景“声明式配置”表达不了，必须允许“用户写一段代码”。于是引入插件系统：**一段 JavaScript 脚本 = 一个数据源适配器**，由 App 在受控沙箱里执行。

设计目标：

| 目标 | 说明 |
|---|---|
| 能力够强 | 能处理签名、复杂解析，覆盖 JSONPath 方案够不到的源 |
| 安全 | 脚本跑在沙箱里，没有网络 / 文件 / 跨插件能力，不能危害用户设备 |
| 稳定 | 单个劣质脚本出错不能拖垮整个信息流；死循环不能冻住 UI |
| 并存 | 与原有 JSONPath 数据源共用一套 UI 与信息流，用户无感切换 |
| 离线 | 插件安装后脚本本地化，不依赖脚本服务器在线 |

---

## 2. 整体架构

```
                 ┌──────────────── 安装期（一次性） ────────────────┐
                 │                                                │
   用户输入 URL ─▶ PluginDownloader.fetch()                       │
                 │  (下载 + 解析 manifest + 校验函数存在性)        │
                 │                                                │
                 ▼                                                │
           确认安装弹窗 ──(用户点头)──▶ PluginRepository.install() │
                                      │                          │
                                      ▼                          │
                            drift: installed_plugins 表            │
                            (完整 JS 源码本地持久化)              │
                 └────────────────────────────────────────────────┘

                 ┌──────────────── 运行期（每次刷新） ────────────┐
                 │                                                │
   FeedListPage ─▶ allFeedSourcesProvider                        │
                  (JSONPath 源 → JsonPathFeedSource              │
                   插件源   → JsPluginFeedSource)                │
                      │                                         │
                      ▼                                         │
              FeedNotifier.fetchFeed()                          │
                      │                                         │
                      ▼                                         │
        ┌── PluginFeedRepository.fetchFeed(plugin) ──┐          │
        │                                            │          │
        │  ① JsEnginePool.callFunction('buildRequest')│          │
        │       └─▶ 独立 Isolate + 沙箱 JS 引擎       │          │
        │           算出一个“请求描述”对象            │          │
        │                                            │          │
        │  ② Dart 层用 dio 真正发请求（沙箱无网络）   │          │
        │                                            │          │
        │  ③ JsEnginePool.callFunction('parseResponse')│         │
        │       └─▶ 沙箱把响应 JSON 解析成文章数组    │          │
        │                                            │          │
        │  ④ KeywordFilterEngine 屏蔽词过滤           │          │
        └────────────────────────────────────────────┘          │
                      │                                         │
                      ▼                                         │
                 List<FeedArticle> ─▶ FeedListPage 渲染          │
                 └────────────────────────────────────────────────┘
```

关键结论：**JS 沙箱只做“纯数据变换”，真正的网络 IO 永远在 Dart 层**。这是整个安全模型的根。

---

## 3. JS 沙箱引擎选型

### 3.1 为什么是 `flutter_js`

需要在一个受控环境里跑用户 JS。候选对比：

| 方案 | 问题 |
|---|---|
| `dart:js` / `js` 包 | 只支持 Web 平台，移动端不可用 |
| `flutter_qjs` | 最新版（0.3.7，2022）SDK 约束 `Dart < 3.0.0`，与本项目 Dart 3.x **不兼容** |
| `quickjs`（纯 FFI 包） | 理想但需要 `native_assets`，在 Flutter 3.7 的 AOT 构建上有风险 |
| **`flutter_js`（0.8.7）** | Dart 3.x 兼容、标准 Flutter 插件、构建稳妥；底层 Android 用 QuickJS（FFI），iOS 用 JavaScriptCore |

最终选 **`flutter_js`**。

### 3.2 平台差异（重要）

`flutter_js` 的引擎是分平台的，我们的 `createSandboxEngine()` 据此选择：

| 平台 | 引擎 | 原生超时中断 | 说明 |
|---|---|---|---|
| Android / Linux / Windows | `QuickJsRuntime2`（FFI） | ✅ 有 | 原生支持 `timeout` 参数，JS 跑死循环时底层强制中止 |
| iOS / macOS | `JavascriptCoreRuntime`（系统框架） | ❌ 无 | 无原生 timeout，靠外层 Isolate 超时兜底（见 §4.2） |

两个关键决策：

1. **不走 `getJavascriptRuntime()`**：该工厂方法会自动 `enableFetch()` 给沙箱开网络，而我们恰恰要封死网络。所以**直接 `new` 具体引擎类**，绕开自动开网。
2. **`JavascriptCoreRuntime` 需单独 import**：它没被 `flutter_js.dart` 顶层导出（`import 'package:flutter_js/javascriptcore/jscore_runtime.dart'`）。在非 iOS/macOS 平台它只被 import、不会被实例化，跨平台编译安全。

---

## 4. 沙箱运行时设计

代码位置：`lib/plugin/js_runtime/`（`js_builtin_libs.dart`、`js_sandbox_runner.dart`、`js_engine_pool.dart`）。

### 4.1 每次调用都起独立 Isolate

`JsSandboxRunner.callFunction()` 用 `Isolate.spawn` 把脚本放进**独立工作 Isolate** 执行。好处：哪怕插件写了死循环，卡住的也只是那个工作 Isolate，主 UI 线程不受影响。

工作 Isolate 内部流程（`_sandboxWorker`）：

1. `createSandboxEngine()` 建引擎；
2. `evaluate(jsBuiltins)` 注入内置工具函数；
3. `evaluate(pluginScript)` 加载用户脚本（定义 `buildRequest` / `parseResponse`）；
4. 拼出调用表达式 `var __args=[...]; JSON.stringify(targetFn(...__args));`，`evaluate` 执行；
5. 结果 JSON 化后通过 `SendPort` 回传主线程；出错则回传错误信息。

### 4.2 两层超时保护（双保险）

| 层级 | 机制 | 作用 |
|---|---|---|
| 第 1 层 | `QuickJsRuntime2(timeout: ms)`（仅 Android/Linux/Windows） | 引擎底层在 JS 跑太久时直接中断执行 |
| 第 2 层 | `completer.future.timeout(t + 2s)` → `Isolate.kill()` | 万一脚本卡在引擎之外，主线程等待超时后**强杀**工作 Isolate，抛 `JsTimeoutException` |

默认单次执行超时 `5s`（`JsSandboxRunner.defaultTimeout`），对 `buildRequest` / `parseResponse` 这种轻量计算绰绰有余。

> 在 iOS/macOS 上只有第 2 层兜底（JavaScriptCore 无原生 timeout）。对良构插件完全够用；若担心恶意脚本，建议在 Android 上运行以获得原生中断保护。

### 4.3 内置工具库（`jsBuiltins`）

提供给插件的加密 / 编解码能力，**全部用纯 JS 实现并随包内置**，不依赖任何桥接。

为什么不用“JS 调 Dart 算 md5”那套桥接？因为 `flutter_js` 的 `setupBridge` 回调签名是 `void Function(dynamic)`，**返回值会被丢弃**——`sendMessage` 在 JS 侧拿不到结果，同步加密无法实现。于是改为纯 JS 实现：MD5 / SHA1 / SHA256 / HMAC / Base64 / UTF-8 编解码都是标准算法，用经典实现移植即可，且跨引擎（QuickJS / JSCore）行为一致。

插件作者可直接调用的全局 API（无需 import）：

```js
md5(str) / sha1(str) / sha256(str)
hmacSha256(str, key) / hmacMd5(str, key)
base64Encode(str) / base64Decode(str)
urlEncode(str) / urlDecode(str)
// 以及 crypto-js 兼容对象
CryptoJS.MD5(str).toString()
```

> 注：作者文档里提到的 `console.log` 转发调试面板、`pluginStorage` 私有存储、`ctx.extra` 自定义参数等能力，属于“插件契约/作者侧”范围，本文不展开，以 [`插件开发文档.md`](./插件开发文档.md) 为准。底层沙箱目前**未**实现 `console` 桥接与 `pluginStorage`，如需这些能力应在 `js_builtin_libs.dart` 中补齐内置实现。

---

## 5. 插件契约（摘要，详见作者文档）

一个插件 = 一段 JS 脚本 + 写在注释头里的 manifest。

- **Manifest**：`// ==DataSourcePlugin==` … `// ==/DataSourcePlugin==` 块，声明 `@id` / `@name` / `@version` / `@author` / `@description` 等。`@id` 是数据库主键，`@id` 与 `@name` 必填。
- **两个必导出的函数**：
  - `buildRequest(ctx)` → 返回请求描述对象（`url` / `method` / `headers` / `params` / `body`）。App 在 Dart 层据此发请求。
  - `parseResponse(responseJson, ctx)` → 返回文章数组。每条至少含 `id` 与 `title`。

`ctx` 由 App 自动注入：`{ page, pageSize, timestamp }`（外加作者文档描述的 `extra`）。

解析层对单条脏数据做了**容错**：`PluginArticle.fromJson` 用 try-catch 包裹，缺标题 / 解析失败的单条直接丢弃（`null`），不会让整页解析崩溃。

---

## 6. 安全模型

这是整个插件系统最不能妥协的部分。

```
┌──────────── JavaScript 沙箱（无网络） ────────────┐
│  buildRequest: 只“算”出请求参数，发不出去            │
│  parseResponse: 只把响应“算”成文章数组              │
│  可用：内置加密/编解码、纯计算                      │
│  禁止：fetch / XHR / 文件 / DOM / 跨插件访问        │
└──────────────────────┬───────────────────────────┘
                       │ 返回“请求描述”对象
                       ▼
┌──────────── Dart 层（有网络） ───────────────────┐
│  dio 真正发起 HTTP 请求                            │
│  → 响应回传给沙箱做 parseResponse                   │
│  → 屏蔽词过滤                                      │
└───────────────────────────────────────────────────┘
```

- **网络只在 Dart 侧发生**。恶意脚本最多“算”出请求参数，却无法在 JS 里偷偷把用户数据 POST 到别的服务器。
- **沙箱引擎不开网络**：`createSandboxEngine` 直接 `new` 引擎，不走会自动 `enableFetch` 的 `getJavascriptRuntime`。
- **资源隔离**：每次调用独立 Isolate + 超时强杀，死循环/内存泄漏被限制在单次调用内。
- **本地化**：插件安装后完整源码存库，行为固定，作者不能偷偷改线上脚本坑用户；“检查更新”需用户显式确认。

---

## 7. 数据模型与持久化

### 7.1 模型（`lib/plugin/models/`）

| 类 | 角色 |
|---|---|
| `PluginManifest` | manifest 解析结果（`parse()` 从脚本注释头抽取；缺 `@id`/`@name` 抛 `PluginManifestException`）。带 `toJson`/`fromJson` 便于入库 |
| `InstalledPlugin` | 一个“装到本地”的插件完整对象：`id` / `name` / `scriptContent`（全文）/ `manifest` / `sourceUrl` / `enabled` / `installedAt` / `version`。重写了 `==`/`hashCode`，让信息流 Tab 能感知“脚本被改过” |
| `PluginRequest` | `buildRequest` 返回值的安全翻译（`fromJson` 全程空值兜底，畸形数据抛 `PluginRequestException`） |
| `PluginArticle` | `parseResponse` 单条文章的安全翻译（`fromJson` 失败返回 `null` 由上层跳过），可 `toFeedArticle(sourceId)` 转成 App 内部统一 `FeedArticle` |

### 7.2 持久化（drift）

表：`installed_plugins`（`lib/core/db/tables/installed_plugin_table.dart`）。

- **关键设计：把完整 JS 源码直接存库**（`scriptContent` 列），而不是只存 URL 每次拉。理由：离线可用、行为固定、防作者偷改。
- `@DataClassName('InstalledPluginsRow')`：drift 默认生成的数据类会叫 `InstalledPlugin`，和我们手写的 `InstalledPlugin` 重名，显式改名避免冲突。
- 主键 `id`（来自 manifest 的 `@id`）；`enabled` 默认 `true`；`sourceUrl` 用于“检查更新”重新拉取比对版本。

> 本项目是全新 app，**未配置数据库迁移策略**：drift 默认 `schemaVersion` 行为即为全新安装 `createAll()` 直接建好全部表，无需 `onUpgrade`。

---

## 8. 下载与安装流程

代码：`PluginDownloader`（`lib/plugin/plugin_downloader.dart`）、`PluginRepository`、`installedPluginsProvider`。

```
用户输入脚本 URL
  │
  ▼
PluginDownloader.fetch(url)
  ├─ 校验 URL 以 http/https 开头
  ├─ dio 以纯文本下载脚本
  ├─ PluginManifest.parse() 解析清单（缺 @id/@name 抛错）
  └─ _requireFunction() 校验 buildRequest / parseResponse 存在
  │
  ▼
确认安装弹窗（展示 ID/版本/作者/来源 + 安全提示）
  │ (用户确认)
  ▼
InstalledPlugin(...) → installedPluginsProvider.inifier.install()
  └─ PluginRepository.install() → db.upsertInstalledPlugin()  (id 相同即覆盖)
```

编辑场景复用同一套校验：`PluginDownloader.validateScript()`（静态方法）在“保存插件”时再次检查脚本含两个核心函数，避免用户改坏脚本后跑不起来。

---

## 9. 与原有数据源“两套并存”

核心抽象：`FeedSource`（`lib/services/feed_source.dart`）。

```dart
abstract class FeedSource {
  String get id;
  String get name;
  bool get enabled;
  DetailRenderMode get detailMode;
  Future<List<FeedArticle>> fetchFeed({required int page, int pageSize = 20});
}
```

两套实现都 `implements FeedSource`，UI 层对它俩**一视同仁**：

| 实现 | 底层 |
|---|---|
| `JsonPathFeedSource` | 委托 `FeedRepository`（URL 占位符替换 → dio → 通用解析 → 屏蔽词过滤） |
| `JsPluginFeedSource` | 委托 `PluginFeedRepository`（沙箱跑 JS → dart 发请求 → 沙箱解析 → 屏蔽词过滤） |

聚合处：`allFeedSourcesProvider` 把“启用的 JSONPath 配置”和“启用的已安装插件”统一映射成 `FeedSource` 列表。之后：

- 聚合模式：`feedAggregateProvider` 合并所有源；
- 分源 Tab：`feedTabProvider(source)` 按单个源建 Tab。

Provider 的 `key` 用 `FeedSource` 对象本身——配置/脚本被改 → 对象变了 → 自动重建并重新拉取。这是“零额外胶水”地让两套体系无缝并存的关键。

UI 集成点：

- 设置 → 数据源管理：列表分段展示「API 数据源」和「插件」，插件行支持**启用开关 / 编辑（改显示名 + 脚本正文）/ 删除**；右上角加号可“手动配置”或“安装插件”。
- 信息流主页：聚合与分 Tab 都由 `allFeedSourcesProvider` 驱动，插件与 JSONPath 源混排。
- 详情页：接收 `FeedSource`（`source.detailMode` 决定 WebView / 原生渲染）。

---

## 10. 关键文件索引

| 文件 | 职责 |
|---|---|
| `lib/plugin/js_runtime/js_builtin_libs.dart` | 内置工具库（纯 JS 加密/编解码）+ 引擎按平台选择 |
| `lib/plugin/js_runtime/js_sandbox_runner.dart` | 独立 Isolate 执行器 + 两层超时 + `JsSandboxException`/`JsTimeoutException` |
| `lib/plugin/js_runtime/js_engine_pool.dart` | 并发限制（信号量，默认 4 并发，防大量 Isolate 同时拉起） |
| `lib/plugin/models/*.dart` | `PluginManifest` / `InstalledPlugin` / `PluginRequest` / `PluginArticle` |
| `lib/plugin/plugin_downloader.dart` | 下载 / 校验 / `validateScript` |
| `lib/plugin/plugin_repository.dart` | 已安装插件的本地 CRUD |
| `lib/plugin/plugin_feed_repository.dart` | 运行期数据流：沙箱算请求 → dart 发请求 → 沙箱解析 → 屏蔽词过滤 |
| `lib/plugin/plugin_feed_source.dart` | `JsPluginFeedSource implements FeedSource` |
| `lib/services/feed_source.dart` | `FeedSource` 抽象 + `JsonPathFeedSource` |
| `lib/providers/feed_list_provider.dart` | `allFeedSourcesProvider` 等聚合入口 |
| `lib/providers/plugin_provider.dart` | 已安装插件状态（含 `update`） |
| `lib/core/db/tables/installed_plugin_table.dart` | drift 插件表 |
| `lib/ui/settings/data_source_list_page.dart` | 数据源/插件管理页（含安装、编辑对话框） |

---

## 11. 已知限制与后续方向

- **iOS/macOS 缺原生 timeout**：防死循环仅靠 Isolate 超时兜底；若在 Android 跑可获得 QuickJS 原生中断保护。
- **`console` / `pluginStorage` 未实现**：作者文档里提到的调试日志转发与私有存储，底层沙箱尚未提供，需要时在 `jsBuiltinLibs` 补齐纯 JS 实现或通过桥接接入。
- **引擎选择写死为 `flutter_js`**：若未来换引擎，只需改 `createSandboxEngine`，上层沙箱 API 不变。
- **编辑只暴露“显示名 + 脚本正文”**：`id` / `manifest.id` 保持原值，避免覆盖写入时主键错位。
- **作者文档需同步**：`doc/插件开发文档.md` 头部仍写“适用引擎：QuickJS（通过 flutter_qjs 运行）”，实际实现已切换为 `flutter_js`，建议更正该说明以免误导插件作者。

---

## 12. 一句话总结

> 插件系统 = **`flutter_js` 引擎 + 独立 Isolate 沙箱 + 纯 JS 内置工具库 + 两层超时**，让一段用户脚本在“无网络、有计算能力”的受控环境里，把“任意 API 的怪异响应”翻译成 FilterFlow 统一的文章流；并通过 `FeedSource` 抽象与原 JSONPath 方案无缝并存。
