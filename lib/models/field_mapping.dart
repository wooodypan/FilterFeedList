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
class FieldMapping with _$FieldMapping {
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
  }) = _FieldMapping;

  /// 从 JSON 反序列化（drift 存 config 时用）
  factory FieldMapping.fromJson(Map<String, dynamic> json) =>
      _$FieldMappingFromJson(json);
}
