使用flutter开发一个app，包含聚合的信息流列表（包括略缩图和标题）页面、图文详情（WebView或原始界面展示）页面，还有一个设置界面，用户可以设置自定义的屏蔽词，如果信息流包含这个词就不展示。

用户可以自己找API开当数据源，不通平台的api及响应不同，app要设计一套通用的规则来兼容所有的API请求及响应，比如响应json如何找到数组对象（比如根据`res.data.list`这个路径取响应json的数组对象），数组对象的哪个字段是略缩图（比如根据`res.data.list[0].thumb`这个路径取响应json的略缩图对象），哪个字段是标题

按照下面的方案开发，app英文名叫FilterFlow，中文名叫漏斗阅读

## 一、整体思路

核心难点是"通用 API 适配层"——不同数据源的 JSON 结构不同，需要一套**可配置的字段映射规则（Schema Mapping）**，而不是为每个 API 写死解析逻辑。方案分三大块：

1. **数据源配置系统**（JSONPath 映射 + 可视化配置）
2. **信息流 + 详情 + 设置的 UI 架构**
3. **屏蔽词过滤引擎**

---

## 二、技术栈选型

| 类别                    | 选型                                                                      | 说明                                                                 |
| ----------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| 状态管理                | **Riverpod 2.x**（riverpod + hooks_riverpod + riverpod_generator）        | 比 Bloc 轻量，比 Provider 类型安全，适合多数据源异步组合             |
| 路由                    | **go_router**                                                             | 声明式路由，支持 deep link 跳转详情页                                |
| 网络请求                | **dio**                                                                   | 拦截器机制方便做统一的请求头/签名/重试                               |
| JSON 动态取值           | **dart_jsonpath** 或自研简化版（见下方）                                  | 用于按路径字符串提取字段                                             |
| 本地存储（配置/屏蔽词） | **drift**（SQLite ORM）                                                   | 数据源配置、屏蔽词、缓存都结构化存储，比 Hive 更适合有查询需求的场景 |
| 轻量 KV                 | **shared_preferences**                                                    | 存全局开关类设置                                                     |
| 图片加载缓存            | **cached_network_image**                                                  | 缩略图列表核心依赖                                                   |
| 详情页展示              | **webview_flutter** + **flutter_widget_from_html_core**（原生渲染二选一） | 见下方"详情页双模式"说明                                             |
| 下拉刷新/加载更多       | **pull_to_refresh_flutter3** 或自实现 CustomScrollView + Slivers          |                                                                      |
| 表单/规则配置 UI        | **flutter_form_builder**（可选）                                          | 数据源配置表单                                                       |
| 序列化                  | **freezed + json_serializable**                                           | 数据模型 + 数据源配置模型代码生成                                    |
| 依赖注入                | Riverpod 自带（无需额外 get_it）                                          |                                                                      |
| 日志                    | **logger**                                                                | 便于调试第三方 API 解析失败问题                                      |

---

## 三、核心设计：通用数据源适配层

### 3.1 数据源配置模型（DataSourceConfig）

这是整个方案的核心，用 `freezed` 定义：

```dart
@freezed
class DataSourceConfig with _$DataSourceConfig {
  const factory DataSourceConfig({
    required String id,
    required String name,               // 数据源名称，用户自定义
    required String apiUrl,              // 请求地址（支持分页占位符 {page}/{pageSize}）
    @Default('GET') String method,
    Map<String, String>? headers,
    Map<String, String>? queryParams,    // 静态 query 参数
    required FieldMapping fieldMapping,  // 核心：字段映射规则
    @Default(DetailRenderMode.webview) DetailRenderMode detailMode,
    String? detailUrlTemplate,           // 详情页 URL 拼接规则（如果详情走 webview）
  }) = _DataSourceConfig;

  factory DataSourceConfig.fromJson(Map<String, dynamic> json) =>
      _$DataSourceConfigFromJson(json);
}

@freezed
class FieldMapping with _$FieldMapping {
  const factory FieldMapping({
    required String listPath,       // 如 "data.list" —— 定位数组的路径
    required String titlePath,      // 相对路径，如 "title"
    required String thumbPath,      // 如 "thumb" 或 "images[0]"
    String? summaryPath,            // 摘要
    String? authorPath,
    String? publishTimePath,
    String? contentPath,            // 原生渲染详情时的正文字段（HTML/纯文本）
    String? detailUrlPath,          // 详情页跳转链接字段（WebView 模式）
    String? uniqueIdPath,           // 用于去重/已读标记，缺省用 title+thumb 做 hash
  }) = _FieldMapping;

  factory FieldMapping.fromJson(Map<String, dynamic> json) =>
      _$FieldMappingFromJson(json);
}

enum DetailRenderMode { webview, native }
```

**关键设计点**：`listPath` 是绝对路径（从根 JSON 开始），而 `titlePath`、`thumbPath` 等是**相对于数组元素的路径**，这样同一套字段映射可以直接 apply 到数组里的每一项。

### 3.2 通用 JSONPath 取值工具（自研简化版，无需重依赖）

考虑到只需要支持 `a.b.c`、`a.b[0].c`、`a.b[0].c[1]` 这种有限语法，自己写一个几十行的解析器比引入完整 JSONPath 库更可控、性能更好：

```dart
class JsonPathResolver {
  /// 支持语法: "data.list", "data.list[0]", "images[0].url"
  static dynamic resolve(dynamic json, String path) {
    if (path.isEmpty) return json;
    dynamic current = json;
    final segments = _tokenize(path);
    for (final seg in segments) {
      if (current == null) return null;
      if (seg.isIndex) {
        if (current is List && seg.index! < current.length) {
          current = current[seg.index!];
        } else {
          return null;
        }
      } else {
        if (current is Map) {
          current = current[seg.key];
        } else {
          return null;
        }
      }
    }
    return current;
  }

  static List<_PathSegment> _tokenize(String path) {
    final segments = <_PathSegment>[];
    final parts = path.split('.');
    for (final part in parts) {
      final regex = RegExp(r'([^\[\]]+)|\[(\d+)\]');
      final matches = regex.allMatches(part);
      for (final m in matches) {
        if (m.group(1) != null) {
          segments.add(_PathSegment.key(m.group(1)!));
        } else if (m.group(2) != null) {
          segments.add(_PathSegment.index(int.parse(m.group(2)!)));
        }
      }
    }
    return segments;
  }

  /// 提供"取值失败自动降级/兜底"的封装
  static String resolveAsString(dynamic json, String? path, {String fallback = ''}) {
    if (path == null || path.isEmpty) return fallback;
    final v = resolve(json, path);
    if (v == null) return fallback;
    return v.toString();
  }
}

class _PathSegment {
  final String? key;
  final int? index;
  bool get isIndex => index != null;
  _PathSegment.key(this.key) : index = null;
  _PathSegment.index(this.index) : key = null;
}
```

### 3.3 通用解析器（ArticleParser）

```dart
class FeedArticle {
  final String id;
  final String title;
  final String thumbUrl;
  final String? summary;
  final String? author;
  final String? publishTime;
  final String? contentHtml;
  final String? detailUrl;
  final String sourceId; // 归属哪个数据源

  FeedArticle({...});
}

class GenericFeedParser {
  static List<FeedArticle> parse(
    Map<String, dynamic> responseJson,
    DataSourceConfig config,
  ) {
    final listRaw = JsonPathResolver.resolve(responseJson, config.fieldMapping.listPath);
    if (listRaw is! List) {
      throw FeedParseException('listPath "${config.fieldMapping.listPath}" 未定位到数组，实际类型: ${listRaw.runtimeType}');
    }

    return listRaw.map((item) {
      final mapping = config.fieldMapping;
      final title = JsonPathResolver.resolveAsString(item, mapping.titlePath);
      final thumb = _resolveThumb(item, mapping.thumbPath);

      return FeedArticle(
        id: mapping.uniqueIdPath != null
            ? JsonPathResolver.resolveAsString(item, mapping.uniqueIdPath)
            : _fallbackId(title, thumb),
        title: title,
        thumbUrl: thumb,
        summary: JsonPathResolver.resolveAsString(item, mapping.summaryPath, fallback: ''),
        author: JsonPathResolver.resolveAsString(item, mapping.authorPath, fallback: ''),
        publishTime: JsonPathResolver.resolveAsString(item, mapping.publishTimePath, fallback: ''),
        contentHtml: mapping.contentPath != null
            ? JsonPathResolver.resolveAsString(item, mapping.contentPath)
            : null,
        detailUrl: mapping.detailUrlPath != null
            ? JsonPathResolver.resolveAsString(item, mapping.detailUrlPath)
            : null,
        sourceId: config.id,
      );
    }).where((a) => a.title.isNotEmpty).toList(); // 过滤脏数据
  }

  /// 缩略图字段有时是字符串，有时是数组（取第一张），做兼容
  static String _resolveThumb(dynamic item, String path) {
    final v = JsonPathResolver.resolve(item, path);
    if (v is String) return v;
    if (v is List && v.isNotEmpty) return v.first.toString();
    return '';
  }

  static String _fallbackId(String title, String thumb) =>
      md5.convert(utf8.encode('$title|$thumb')).toString();
}
```

**容错要点**：

- listPath 找不到数组要抛出**明确的可读异常**，方便用户在配置数据源时定位问题（不要静默返回空列表）。
- 单条 title 为空的脏数据直接过滤，避免出现空白 item。
- 缩略图字段支持"字符串 or 数组取第一项"两种常见形态自动兼容。
- 建议在数据源配置页提供"**测试/预览**"按钮：输入 API 后立即请求一次，展示解析出的前 3 条结果，让用户在保存配置前就能验证映射规则对不对。

---

## 四、屏蔽词过滤引擎

```dart
class KeywordFilterEngine {
  final List<String> _blockedWords;

  KeywordFilterEngine(this._blockedWords);

  bool isBlocked(FeedArticle article) {
    final text = '${article.title} ${article.summary ?? ''}'.toLowerCase();
    return _blockedWords.any((word) => text.contains(word.toLowerCase().trim()));
  }

  List<FeedArticle> filter(List<FeedArticle> articles) {
    return articles.where((a) => !isBlocked(a)).toList();
  }
}
```

- 屏蔽词存 drift 表 `blocked_keywords(id, word, created_at)`。
- 过滤发生在 **Repository 层**（获取数据后、下发给 UI 前），而不是在 UI 层过滤，避免列表分页/去重逻辑绕过过滤。
- 后续可扩展：正则模式、命中高亮标记为"已过滤 N 条"提示。

---

## 五、详情页：WebView / 原生二选一

数据源配置里的 `detailMode` 决定：

- **`webview`**：直接用 `webview_flutter` 加载 `detailUrl`，适合"标题+跳转原文链接"型 API。
- **`native`**：用 `flutter_widget_from_html_core` 渲染 `contentHtml` 字段，适合返回了完整正文 HTML 的 API，体验更流畅、无广告、可自定义样式。

```dart
class ArticleDetailPage extends ConsumerWidget {
  final FeedArticle article;
  final DataSourceConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(article.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: config.detailMode == DetailRenderMode.webview
          ? WebViewWidget(controller: _buildController(article.detailUrl!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HtmlWidget(article.contentHtml ?? '<p>无内容</p>'),
            ),
    );
  }
}
```

---

## 六、App 整体架构分层

```
lib/
├── main.dart
├── app.dart                          # MaterialApp + go_router 配置
│
├── core/
│   ├── network/
│   │   ├── dio_client.dart           # 统一 dio 实例，拦截器（超时/重试/日志）
│   │   └── json_path_resolver.dart   # 通用 JSONPath 解析
│   ├── db/
│   │   ├── app_database.dart         # drift database
│   │   └── tables/
│   │       ├── data_source_table.dart
│   │       └── blocked_keyword_table.dart
│   └── error/
│       └── feed_parse_exception.dart
│
├── models/
│   ├── data_source_config.dart       # freezed model
│   ├── field_mapping.dart
│   └── feed_article.dart
│
├── services/
│   ├── generic_feed_parser.dart      # 通用解析器
│   ├── keyword_filter_engine.dart    # 屏蔽词引擎
│   └── feed_repository.dart          # 组合: 请求 -> 解析 -> 过滤 -> 返回
│
├── providers/                         # Riverpod
│   ├── data_source_provider.dart      # 数据源 CRUD 状态
│   ├── feed_list_provider.dart        # 分页信息流状态（含 loadMore）
│   └── blocked_keyword_provider.dart
│
├── ui/
│   ├── feed/
│   │   ├── feed_list_page.dart        # 聚合信息流（可多 Tab = 多数据源）
│   │   └── widgets/
│   │       ├── feed_item_card.dart    # 缩略图+标题 卡片
│   │       └── feed_source_tab_bar.dart
│   ├── detail/
│   │   └── article_detail_page.dart
│   └── settings/
│       ├── settings_page.dart
│       ├── data_source_list_page.dart
│       ├── data_source_edit_page.dart  # 配置/测试数据源映射规则
│       └── blocked_keyword_page.dart
│
└── utils/
    └── validators.dart                # 校验 URL/JSONPath 格式合法性
```

---

## 七、数据流（Feed Repository 组合逻辑）

```dart
class FeedRepository {
  final Dio dio;
  final AppDatabase db;

  Future<List<FeedArticle>> fetchFeed(DataSourceConfig config, {int page = 1}) async {
    final url = config.apiUrl
        .replaceAll('{page}', page.toString())
        .replaceAll('{pageSize}', '20');

    final response = await dio.request(
      url,
      options: Options(method: config.method, headers: config.headers),
      queryParameters: config.queryParams,
    );

    final json = response.data is String ? jsonDecode(response.data) : response.data;

    List<FeedArticle> articles;
    try {
      articles = GenericFeedParser.parse(json, config);
    } on FeedParseException catch (e) {
      // 上报/记录，UI 层展示"该数据源解析失败，请检查字段映射"
      rethrow;
    }

    final keywords = await db.getAllBlockedKeywords();
    return KeywordFilterEngine(keywords).filter(articles);
  }
}
```

多数据源聚合（如果要把多个源混在一条 Feed 流里）：在 `feed_list_provider` 里并发请求所有启用的数据源，`Future.wait` 后按 `publishTime` 排序合并，或者用 Tab 分开展示——两种模式都建议支持，通过设置切换"聚合模式 / 分源 Tab 模式"。

---

## 八、设置页 - 数据源配置表单要点

工程师实现这个表单时注意字段：

| 表单项                                                        | 说明                                                                             |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| 数据源名称                                                    | 必填                                                                             |
| API 地址                                                      | 支持 `{page}`占位符                                                              |
| 请求方式                                                      | GET/POST                                                                         |
| Headers                                                       | 动态 key-value 列表（有些 API 需要 token）                                       |
| listPath                                                      | 必填，如 `data.list`                                                             |
| titlePath / thumbPath                                         | 必填                                                                             |
| summaryPath / authorPath / publishTimePath                    | 选填                                                                             |
| 详情模式                                                      | Radio: WebView / 原生渲染                                                        |
| detailUrlPath（WebView模式必填）/ contentPath（原生模式必填） | 条件必填校验                                                                     |
| **"测试连接"按钮**                                            | 立即请求+解析，展示解析结果预览卡片，解析失败展示具体报错（如"listPath 未命中"） |

---

## 九、其它工程建议

1. **异常分级处理**：网络异常、JSON 解析异常、字段映射异常要分开捕获，分别给用户不同的提示文案（"网络不通" vs "该数据源配置有误"）。
2. **缓存策略**：drift 存最近一次成功解析结果作为离线兜底，网络失败时展示缓存 + toast 提示。
3. **图片懒加载**：`CachedNetworkImage` 配合 `ListView.builder`（非 `SliverList` 也可）确保长列表性能，缩略图统一走 `errorWidget` 兜底占位图（部分 API 返回空 thumb 很常见）。
4. **去重**：多数据源聚合时用 `uniqueIdPath` 或 fallback 的 md5 hash 做已读/去重标记，存 drift。
5. **单元测试重点**：`JsonPathResolver` 和 `GenericFeedParser` 是全项目最该覆盖测试的部分，建议对多种畸形 JSON（缺字段、类型不匹配、空数组）写针对性 test case。

这套方案的核心价值在于——**新增一个数据源不需要写代码，只需要在设置页填一份 JSONPath 映射配置**，工程师后续只需要维护好这套通用解析引擎和容错逻辑即可。

# 数据源"插件化"方案：内嵌 JS 引擎

问：

```
{
    "apiUrl": "https://hn.algolia.com/api/v1/search?tags=story&page={page}&hitsPerPage={pageSize}",
    "detailMode": "webview",
    "detailUrlTemplate": null,
    "enabled": true,
    "fieldMapping": {
        "authorPath": "author",
        "contentPath": null,
        "detailUrlPath": "url",
        "listPath": "hits",
        "publishTimePath": "created_at",
        "summaryPath": null,
        "thumbPath": "thumbnail",
        "titlePath": "title",
        "uniqueIdPath": null
    },
    "headers": null,
    "id": "hn_demo",
    "method": "GET",
    "name": "Hacker News (示例)",
    "queryParams": null
}
这是我的一个数据源。数据源目前不够灵活，比如API地址：
https://hn.algolia.com/api/v1/search?tags=story&page={page}&hitsPerPage={pageSize}

page和pageSize是占位符，标题路径titlePath对应的值为title，但是有些API需要获取当前时间戳并且通过算法自己计算生成 sign，我想做成更加灵活的形式，用户输入一个URL就可以作为插件下载安装，是用JS还是什么什么方案？
```

架构师Sonet说：

纯 JSONPath 声明式配置只能覆盖"字段映射"这一层，一旦涉及到**请求前处理**（动态时间戳、签名算法、加密参数）和**响应后处理**（非标准结构、需要计算派生字段），声明式配置就不够用了，必须上"可执行代码"。这是几乎所有做"聚合类/订阅类"App（比如 RSS 阅读器插件系统、tampermonkey 脚本）最终都会走到的路子。

下面给你一套完整方案

---

## 一、技术选型：为什么是 JS，以及具体引擎

### 1.1 为什么选 JS 而不是其它方案

| 方案                    | 评估                                                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **JS 脚本引擎**（推荐） | 生态最大，用户/第三方开发者写起来零门槛（前端程序员遍地都是），签名算法（HMAC/MD5/AES）网上现成 JS 实现一搜一大把，直接抄来改改就能跑 |
| Lua 脚本                | 性能更好、体积更小，但生态和"能写的人"远少于 JS，签名算法要自己移植                                                                   |
| WASM 插件               | 性能最强、隔离最彻底，但用户写插件的门槛极高（需要 Rust/C 编译），不适合"UGC 插件"场景                                                |
| Dart 反射/动态执行      | Dart 没有官方稳定的动态 eval 方案，pub.dev 上的动态执行库都不成熟，排除                                                               |

**结论：JS 引擎是唯一在"表达能力"和"用户可写性"之间平衡最好的方案**，类似 Quantumult X / Loon / Surge 的 JS 脚本模块、Flutter 生态里 flutter_js 的典型用法。

### 1.2 具体库选型

| 库                       | 说明                                                                                | 推荐度                       |
| ------------------------ | ----------------------------------------------------------------------------------- | ---------------------------- |
| **flutter_js**           | 基于 QuickJS（iOS）/ JavaScriptCore（部分平台），纯 Dart 绑定，无需 WebView         | ⭐️⭐️⭐️⭐️⭐️ 首选              |
| **flutter_qjs**          | 直接绑定 QuickJS，体积小、启动快、跨平台一致性好（不依赖系统 JSCore）               | ⭐️⭐️⭐️⭐️⭐️ 备选/更优（推荐） |
| flutter_eval (dart_eval) | 执行 Dart 子集而非 JS，生态和语法都不如 JS 直观                                     | ⭐️⭐️ 不推荐                  |
| WebView 隐藏执行 JS      | 用一个不可见的 WebView 跑 JS，能用但性能差、生命周期难管理、无法在后台/isolate 运行 | ⭐️ 仅作 fallback             |

**最终推荐：`flutter_qjs`**（QuickJS 绑定），理由：

- 跨平台行为一致（不依赖 iOS/Android 系统自带 JS 引擎版本差异）
- 体积小、启动快，适合频繁调用（每次刷新列表都要跑一次脚本）
- 支持在 **Isolate 中运行**，脚本卡死/死循环不会阻塞主 UI 线程——这点对"用户可以下载不受信任的第三方插件"极其重要，必须做好沙箱隔离

---

## 二、插件协议设计

### 2.1 插件本质：一个 JS 文件 + 一份 manifest

用户输入一个 URL，App 下载的是这样一个结构（可以打包成单文件 JS，用注释头存 manifest，类似 Tampermonkey 脚本头）：

```js
// ==DataSourcePlugin==
// @id           hn_demo
// @name         Hacker News
// @version      1.0.0
// @author       yourname
// @description  Hacker News 热门文章聚合
// @icon         https://hn.algolia.com/favicon.ico
// @homepage     https://github.com/xxx/hn-plugin
// ==/DataSourcePlugin==

/**
 * 构建请求参数。返回值会被 Dio 用来发起真实网络请求。
 * @param {object} ctx - 上下文，包含 page, pageSize, timestamp 等运行时变量
 * @returns {object} { url, method, headers, params, body }
 */
function buildRequest(ctx) {
  const timestamp = Date.now();
  const sign = md5(`secret_key_${timestamp}`); // 内置 crypto 工具函数

  return {
    url: "https://hn.algolia.com/api/v1/search",
    method: "GET",
    headers: {},
    params: {
      tags: "story",
      page: ctx.page - 1,
      hitsPerPage: ctx.pageSize,
      // sign, timestamp  // 需要签名的 API 在这里加
    },
  };
}

/**
 * 解析响应，返回统一的文章数组
 * @param {object} responseJson - 原始响应 JSON（已由 Dart 层 decode）
 * @param {object} ctx
 * @returns {Array<object>} 统一格式的文章列表
 */
function parseResponse(responseJson, ctx) {
  const hits = responseJson.data.hits || [];
  return hits.map((item) => ({
    id: item.objectID,
    title: item.title,
    thumb: item.thumbnail || "",
    summary: item.story_text || "",
    author: item.author || "",
    publishTime: item.created_at || "",
    detailUrl:
      item.url || `https://news.ycombinator.com/item?id=${item.objectID}`,
    contentHtml: null,
  }));
}
```

### 2.2 为什么用"函数式约定"而不是纯 JSONPath 字符串

关键设计决策：**把 `fieldMapping` 从"配置数据"升级为"函数"**，但保持接口极简——插件只需要实现两个**纯函数**：

- `buildRequest(ctx)` → 返回请求描述对象（Dart 侧真正发起网络请求，JS 不直接访问网络，这是安全边界的关键）
- `parseResponse(json, ctx)` → 返回标准化文章数组（JS 只做数据变换，不做副作用）

这样即使插件是不受信任的第三方代码，**JS 引擎沙箱里也没有网络权限**，所有网络 IO 都在 Dart 层执行，极大降低安全风险（防止插件偷偷把用户数据发到攻击者服务器）。

---

## 三、Flutter 侧执行架构

```
lib/
├── plugin/
│   ├── plugin_manifest.dart        # 解析注释头 manifest
│   ├── plugin_downloader.dart      # 从 URL 下载 JS 脚本、校验、存本地
│   ├── plugin_repository.dart      # 已安装插件 CRUD（drift 存储脚本内容+manifest）
│   ├── js_runtime/
│   │   ├── js_engine_pool.dart     # flutter_qjs 引擎实例池/复用
│   │   ├── js_sandbox_runner.dart  # 在 Isolate 中跑脚本，带超时熔断
│   │   └── js_builtin_libs.dart    # 注入内置工具函数：md5/sha1/hmac/base64/crypto-js polyfill
│   └── models/
│       ├── plugin_request.dart     # buildRequest 返回值的 Dart 映射
│       └── plugin_article.dart     # parseResponse 返回值的 Dart 映射
```

### 3.1 执行流程

```dart
class PluginFeedRepository {
  final JsSandboxRunner jsRunner;
  final Dio dio;

  Future<List<FeedArticle>> fetchFeed(InstalledPlugin plugin, {required int page}) async {
    // 1. 在沙箱中执行 buildRequest，拿到请求描述（超时保护，比如 3s）
    final reqDesc = await jsRunner.callFunction(
      script: plugin.scriptContent,
      functionName: 'buildRequest',
      args: [
        {'page': page, 'pageSize': 20, 'timestamp': DateTime.now().millisecondsSinceEpoch}
      ],
      timeout: const Duration(seconds: 3),
    );

    // 2. Dart 层真正发起网络请求（JS 沙箱不能直接访问网络）
    final pluginReq = PluginRequest.fromJson(reqDesc);
    final response = await dio.request(
      pluginReq.url,
      options: Options(method: pluginReq.method, headers: pluginReq.headers),
      queryParameters: pluginReq.params,
    );

    // 3. 把响应 JSON 传回沙箱，执行 parseResponse
    final articlesRaw = await jsRunner.callFunction(
      script: plugin.scriptContent,
      functionName: 'parseResponse',
      args: [
        {'data': response.data},
        {'page': page}
      ],
      timeout: const Duration(seconds: 3),
    );

    // 4. 转成 Dart Model，走既有的屏蔽词过滤逻辑
    final articles = (articlesRaw as List)
        .map((e) => FeedArticle.fromPluginJson(e, sourceId: plugin.id))
        .toList();

    final keywords = await db.getAllBlockedKeywords();
    return KeywordFilterEngine(keywords).filter(articles);
  }
}
```

### 3.2 内置工具库（必须预注入，否则用户没法写签名算法）

签名算法是最典型的痛点，一定要在 JS 沙箱里预置这些能力，否则每个插件作者都要自己实现一遍 MD5/HMAC：

```dart
// js_builtin_libs.dart —— 在引擎初始化时注入
const jsBuiltins = '''
// 内置 crypto-js 精简移植 或 直接把 crypto-js 打包进沙箱
var md5 = function(str) { /* ... */ };
var hmacSha256 = function(str, key) { /* ... */ };
var base64Encode = function(str) { /* ... */ };
var urlEncode = function(str) { /* ... */ };

// console.log 转发到 Dart 日志，方便插件调试
var console = {
  log: function(...args) { __native_log(JSON.stringify(args)); }
};
''';
```

实操上直接把 **crypto-js** 的精简 UMD 版本作为字符串常量打包进 App（不联网加载），初始化引擎时先 `eval` 这段库代码，再 eval 用户插件脚本，这样 `CryptoJS.MD5(...)`、`CryptoJS.HmacSHA256(...)` 等 API 用户插件里可以直接用，和网上抄来的签名算法代码几乎不用改。

---

## 四、安全与稳定性（重点，插件系统最容易翻车的地方）

| 风险                                           | 应对方案                                                                                                                                                                                        |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 插件死循环卡死 App                             | 必须在独立 **Isolate** 中执行 JS，设置执行超时（如 3-5 秒），超时强制 kill isolate                                                                                                              |
| 插件访问不该访问的能力                         | 沙箱内**不注入** `fetch`/`XMLHttpRequest`/文件系统 API，网络 IO 全部由 Dart 层代理执行，JS 只做纯计算                                                                                           |
| 恶意脚本读取用户其它插件数据                   | 每个插件的 JS 执行环境相互隔离，不共享全局变量/存储；如果要给插件提供"存储"能力（如插件自己的 token 缓存），单独设计一个 `pluginStorage.get/set(key, value)` 的受限 API，按插件 id 隔离命名空间 |
| 插件返回格式不对导致崩溃                       | `PluginArticle.fromJson` 用 try-catch 包裹，单条解析失败跳过而非整体崩溃；字段用 `?? ''` 兜底                                                                                                   |
| 用户安装了恶意/劣质插件                        | 上线"插件市场"前，建议先做**本地安装 + 显式风险提示**（"该插件将读取网络数据并在本地沙箱执行，请仅安装可信来源"），后续再考虑插件签名校验/审核机制                                              |
| 内置工具函数版本过旧导致签名算法跑不出正确结果 | crypto-js 库随 App 版本更新即可，不需要用户自己维护                                                                                                                                             |

---

## 五、插件安装/管理 UI 流程

```
设置页 → 数据源管理 → "+" 添加数据源
  ├── 方式一：手动配置（保留现有 JSONPath 声明式表单，给不需要签名的简单 API）
  └── 方式二：安装插件（新增）
         → 输入插件 JS 脚本 URL
         → App 下载脚本，解析 manifest 注释头，展示 名称/作者/描述/图标 供用户确认
         → 点击"安装并测试" → 沙箱跑一次 buildRequest + 真实请求 + parseResponse
         → 展示解析出的前 3 条数据预览，用户确认无误后正式启用
```

`InstalledPlugin` 存储（drift 表）：

```dart
class InstalledPlugins extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get scriptContent => text()();   // 完整 JS 源码，本地持久化
  TextColumn get manifestJson => text()();     // 解析出的 manifest
  TextColumn get sourceUrl => text()();        // 安装来源 URL，用于后续检查更新
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get installedAt => dateTime()();
  TextColumn get version => text()();
}
```

后续还可以加"检查更新"功能——定期用 `sourceUrl` 重新拉取脚本，对比 manifest 里的 `@version` 字段提示用户升级。

---

## 六、两套体系并存的建议

不建议完全抛弃之前的 JSONPath 声明式配置，而是**分层设计**：

1. **简单 API**（无需签名，直接 GET）→ 继续用之前的 `DataSourceConfig`（JSONPath 映射），零代码，普通用户友好。
2. **复杂 API**（需要签名/时间戳/加密）→ 走 **JS 插件**方案。

技术上可以让 `FeedRepository` 统一抽象成一个接口，两种数据源类型都实现它：

```dart
abstract class FeedSource {
  Future<List<FeedArticle>> fetchFeed({required int page});
}

class JsonPathFeedSource implements FeedSource { ... }   // 原有方案
class JsPluginFeedSource implements FeedSource { ... }    // 新增插件方案
```

这样 UI 层（信息流列表、Tab 切换）完全不用关心底层是哪种数据源，`DataSourceConfig.type` 字段（`jsonpath` / `js_plugin`）决定实例化哪个实现即可，架构上平滑扩展、互不影响。
