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

| 类别 | 选型 | 说明 |
|---|---|---|
| 状态管理 | **Riverpod 2.x**（riverpod + hooks_riverpod + riverpod_generator） | 比 Bloc 轻量，比 Provider 类型安全，适合多数据源异步组合 |
| 路由 | **go_router** | 声明式路由，支持 deep link 跳转详情页 |
| 网络请求 | **dio** | 拦截器机制方便做统一的请求头/签名/重试 |
| JSON 动态取值 | **dart_jsonpath** 或自研简化版（见下方） | 用于按路径字符串提取字段 |
| 本地存储（配置/屏蔽词） | **drift**（SQLite ORM） | 数据源配置、屏蔽词、缓存都结构化存储，比 Hive 更适合有查询需求的场景 |
| 轻量 KV | **shared_preferences** | 存全局开关类设置 |
| 图片加载缓存 | **cached_network_image** | 缩略图列表核心依赖 |
| 详情页展示 | **webview_flutter** + **flutter_widget_from_html_core**（原生渲染二选一） | 见下方"详情页双模式"说明 |
| 下拉刷新/加载更多 | **pull_to_refresh_flutter3** 或自实现 CustomScrollView + Slivers | |
| 表单/规则配置 UI | **flutter_form_builder**（可选） | 数据源配置表单 |
| 序列化 | **freezed + json_serializable** | 数据模型 + 数据源配置模型代码生成 |
| 依赖注入 | Riverpod 自带（无需额外 get_it） | |
| 日志 | **logger** | 便于调试第三方 API 解析失败问题 |

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

| 表单项 | 说明 |
|---|---|
| 数据源名称 | 必填 |
| API 地址 | 支持 `{page}`占位符 |
| 请求方式 | GET/POST |
| Headers | 动态 key-value 列表（有些 API 需要 token） |
| listPath | 必填，如 `data.list` |
| titlePath / thumbPath | 必填 |
| summaryPath / authorPath / publishTimePath | 选填 |
| 详情模式 | Radio: WebView / 原生渲染 |
| detailUrlPath（WebView模式必填）/ contentPath（原生模式必填） | 条件必填校验 |
| **"测试连接"按钮** | 立即请求+解析，展示解析结果预览卡片，解析失败展示具体报错（如"listPath 未命中"） |

---

## 九、其它工程建议

1. **异常分级处理**：网络异常、JSON 解析异常、字段映射异常要分开捕获，分别给用户不同的提示文案（"网络不通" vs "该数据源配置有误"）。
2. **缓存策略**：drift 存最近一次成功解析结果作为离线兜底，网络失败时展示缓存 + toast 提示。
3. **图片懒加载**：`CachedNetworkImage` 配合 `ListView.builder`（非 `SliverList` 也可）确保长列表性能，缩略图统一走 `errorWidget` 兜底占位图（部分 API 返回空 thumb 很常见）。
4. **去重**：多数据源聚合时用 `uniqueIdPath` 或 fallback 的 md5 hash 做已读/去重标记，存 drift。
5. **单元测试重点**：`JsonPathResolver` 和 `GenericFeedParser` 是全项目最该覆盖测试的部分，建议对多种畸形 JSON（缺字段、类型不匹配、空数组）写针对性 test case。

这套方案的核心价值在于——**新增一个数据源不需要写代码，只需要在设置页填一份 JSONPath 映射配置**，工程师后续只需要维护好这套通用解析引擎和容错逻辑即可。