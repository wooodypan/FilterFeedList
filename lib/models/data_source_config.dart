import 'package:freezed_annotation/freezed_annotation.dart';

import 'field_mapping.dart';

part 'data_source_config.freezed.dart';
part 'data_source_config.g.dart';

/// 详情页渲染方式。
enum DetailRenderMode {
  /// 用 WebView 加载原文链接（适合"标题 + 跳转原文"型 API）
  webview,

  /// 用原生 Widget 渲染正文 HTML（适合返回了完整正文的 API，无广告、可定制样式）
  native,
}

/// DetailRenderMode 的 JSON 转换器。
///
/// freezed 默认不会把枚举序列化成字符串，这里手动告诉它：
/// 枚举 <-> 字符串（webview / native）互转。
class DetailRenderModeConverter
    implements JsonConverter<DetailRenderMode, String> {
  const DetailRenderModeConverter();

  @override
  DetailRenderMode fromJson(String json) {
    // 找不到就默认走 webview，保证老数据不崩
    return DetailRenderMode.values.where((e) => e.name == json).firstOrNull ??
        DetailRenderMode.webview;
  }

  @override
  String toJson(DetailRenderMode mode) => mode.name;
}

/// 数据源类型。
///
/// 同一份 [DataSourceConfig] 通过它区分两种接入方式：
/// - json：JSONPath 声明式配置（配合必读的 [DataSourceConfig.fieldMapping]）
/// - rss：RSS/Atom 订阅（fieldMapping 为 null，feed 地址存在 apiUrl）
enum DataSourceType {
  /// JSONPath 声明式 API 数据源
  json,

  /// RSS/Atom 订阅数据源
  rss,
}

/// DataSourceType 的 JSON 转换器。
///
/// 老版本库里存的 JSON 没有 sourceType 这个 key，反序列化时缺省为 json，
/// 保证升级后老配置照常工作。
class DataSourceTypeConverter implements JsonConverter<DataSourceType, String> {
  const DataSourceTypeConverter();

  @override
  DataSourceType fromJson(String json) {
    return DataSourceType.values.where((e) => e.name == json).firstOrNull ??
        DataSourceType.json;
  }

  @override
  String toJson(DataSourceType type) => type.name;
}

/// 数据源配置：一个数据源 = 一个 API + 一套字段映射规则。
///
/// 这是整个 app 的核心。用户只要在设置页填一份配置（不用写代码），
/// 就能接入任何一个结构不同的 API。
@freezed
abstract class DataSourceConfig with _$DataSourceConfig {
  const factory DataSourceConfig({
    /// 唯一 id（本地生成，用于数据库主键 / 去重标记）
    required String id,

    /// 数据源名称（用户自定义，展示在 Tab 上）
    required String name,

    /// 数据源类型（json = JSONPath 配置源；rss = RSS/Atom 订阅源）
    @DataSourceTypeConverter()
    @Default(DataSourceType.json)
    DataSourceType sourceType,

    /// 请求地址。json 源支持占位符 {page} 和 {pageSize}（分页时自动替换）；
    /// rss 源即 feed 的 URL。
    required String apiUrl,

    /// 请求方法，默认 GET（仅 json 源使用）
    @Default('GET') String method,

    /// 静态请求头（有些 API 需要带 token / 自定义 UA，仅 json 源使用）
    Map<String, String>? headers,

    /// 静态 query 参数（拼在 URL 后面，不参与 JSONPath，仅 json 源使用）
    Map<String, String>? queryParams,

    /// 核心：字段映射规则（仅 json 源使用；rss 源为 null）
    FieldMapping? fieldMapping,

    /// 详情页渲染方式
    @DetailRenderModeConverter()
    @Default(DetailRenderMode.webview)
    DetailRenderMode detailMode,

    /// 详情页 URL 拼接模板（如果详情走 webview 且链接需要二次拼接）
    String? detailUrlTemplate,

    /// 是否启用（关闭后不参与信息流聚合）
    @Default(true) bool enabled,

    /// 是否启用"App 深链直达"：开启后，若某条文章带 appDeepLink（如
    /// smzdm://youhui/123），点开时优先用它拉起对应 App；拉起失败再退回 WebView。
    /// 默认开启，与 smzdm 这类支持深链的插件配合体验最佳。
    @Default(true) bool useAppDeepLink,
  }) = _DataSourceConfig;

  /// 从 JSON 反序列化（drift 存取配置时用）
  factory DataSourceConfig.fromJson(Map<String, dynamic> json) =>
      _$DataSourceConfigFromJson(json);
}
