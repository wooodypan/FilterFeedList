import 'package:freezed_annotation/freezed_annotation.dart';

part 'field_mapping.freezed.dart';
part 'field_mapping.g.dart';

/// 字段映射规则：描述"如何从一个数据源的 JSON 里抠出信息流列表和各项字段"。
///
/// 设计要点（见 task.md 3.1）：
/// - [listPath] 是【绝对路径】，从根 JSON 开始定位数组，例如 "data.list"。
/// - 其它字段（title/thumb/...）是【相对路径】，直接作用在数组的每一行元素上，
///   例如 titlePath="title" 表示取 `行元素.title`。
/// 这样同一套规则就能自动套用到数组里的每一项，不用重复写路径。
@freezed
abstract class FieldMapping with _$FieldMapping {
  const factory FieldMapping({
    /// 定位数组的绝对路径（必填）。例如 "data.list"
    required String listPath,

    /// 相对路径：标题字段（必填）。例如 "title"
    required String titlePath,

    /// 相对路径：缩略图字段（必填）。例如 "thumb" 或 "images[0]"
    required String thumbPath,

    /// 相对路径：摘要（选填）
    String? summaryPath,

    /// 相对路径：作者（选填）
    String? authorPath,

    /// 相对路径：发布时间（选填）
    String? publishTimePath,

    /// 相对路径：正文 HTML/纯文本（原生渲染详情时必填）
    String? contentPath,

    /// 相对路径：详情页跳转链接（WebView 模式时必填）
    String? detailUrlPath,

    /// 相对路径：唯一 id（去重/已读用）。缺省时用 title+thumb 做 md5
    String? uniqueIdPath,

    /// 是否把标题翻译成中文（译文怎么放由全局"翻译模式"决定）。
    ///
    /// 打开后：[titlePath] 取到的原文会被送去翻译，然后再按模式拼回去——
    /// 原文替换就是"标题变成译文"，双语共存就是"标题 = 原文\n译文"。
    @Default(false) bool translateTitle,

    /// 是否把摘要翻译成中文。译文写回文章的 summary 字段。
    ///
    /// 注意"摘要"指的是 [summaryPath] 取到的那段文字，它不一定来自 summary 字段：
    /// 比如 summaryPath 写 `title` 时，这段文字其实是标题原文，
    /// 打开本开关就等于"把标题翻成中文，译文放进摘要"。
    @Default(false) bool translateSummary,
  }) = _FieldMapping;

  /// 从 JSON 反序列化（drift 存 config 时用）。
  ///
  /// 直接交给 json_serializable 生成的代码，不做任何字段改写。
  factory FieldMapping.fromJson(Map<String, dynamic> json) =>
      _$FieldMappingFromJson(json);
}
