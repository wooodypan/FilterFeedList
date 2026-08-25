// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'field_mapping.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FieldMapping _$FieldMappingFromJson(Map<String, dynamic> json) {
  return _FieldMapping.fromJson(json);
}

/// @nodoc
mixin _$FieldMapping {
  /// 定位数组的绝对路径（必填）。例如 "data.list"
  String get listPath => throw _privateConstructorUsedError;

  /// 相对路径：标题字段（必填）。例如 "title"
  String get titlePath => throw _privateConstructorUsedError;

  /// 相对路径：缩略图字段（必填）。例如 "thumb" 或 "images[0]"
  String get thumbPath => throw _privateConstructorUsedError;

  /// 相对路径：摘要（选填）
  String? get summaryPath => throw _privateConstructorUsedError;

  /// 相对路径：作者（选填）
  String? get authorPath => throw _privateConstructorUsedError;

  /// 相对路径：发布时间（选填）
  String? get publishTimePath => throw _privateConstructorUsedError;

  /// 相对路径：正文 HTML/纯文本（原生渲染详情时必填）
  String? get contentPath => throw _privateConstructorUsedError;

  /// 相对路径：详情页跳转链接（WebView 模式时必填）
  String? get detailUrlPath => throw _privateConstructorUsedError;

  /// 相对路径：唯一 id（去重/已读用）。缺省时用 title+thumb 做 md5
  String? get uniqueIdPath => throw _privateConstructorUsedError;

  /// Serializes this FieldMapping to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FieldMapping
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FieldMappingCopyWith<FieldMapping> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FieldMappingCopyWith<$Res> {
  factory $FieldMappingCopyWith(
    FieldMapping value,
    $Res Function(FieldMapping) then,
  ) = _$FieldMappingCopyWithImpl<$Res, FieldMapping>;
  @useResult
  $Res call({
    String listPath,
    String titlePath,
    String thumbPath,
    String? summaryPath,
    String? authorPath,
    String? publishTimePath,
    String? contentPath,
    String? detailUrlPath,
    String? uniqueIdPath,
  });
}

/// @nodoc
class _$FieldMappingCopyWithImpl<$Res, $Val extends FieldMapping>
    implements $FieldMappingCopyWith<$Res> {
  _$FieldMappingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FieldMapping
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? listPath = null,
    Object? titlePath = null,
    Object? thumbPath = null,
    Object? summaryPath = freezed,
    Object? authorPath = freezed,
    Object? publishTimePath = freezed,
    Object? contentPath = freezed,
    Object? detailUrlPath = freezed,
    Object? uniqueIdPath = freezed,
  }) {
    return _then(
      _value.copyWith(
            listPath:
                null == listPath
                    ? _value.listPath
                    : listPath // ignore: cast_nullable_to_non_nullable
                        as String,
            titlePath:
                null == titlePath
                    ? _value.titlePath
                    : titlePath // ignore: cast_nullable_to_non_nullable
                        as String,
            thumbPath:
                null == thumbPath
                    ? _value.thumbPath
                    : thumbPath // ignore: cast_nullable_to_non_nullable
                        as String,
            summaryPath:
                freezed == summaryPath
                    ? _value.summaryPath
                    : summaryPath // ignore: cast_nullable_to_non_nullable
                        as String?,
            authorPath:
                freezed == authorPath
                    ? _value.authorPath
                    : authorPath // ignore: cast_nullable_to_non_nullable
                        as String?,
            publishTimePath:
                freezed == publishTimePath
                    ? _value.publishTimePath
                    : publishTimePath // ignore: cast_nullable_to_non_nullable
                        as String?,
            contentPath:
                freezed == contentPath
                    ? _value.contentPath
                    : contentPath // ignore: cast_nullable_to_non_nullable
                        as String?,
            detailUrlPath:
                freezed == detailUrlPath
                    ? _value.detailUrlPath
                    : detailUrlPath // ignore: cast_nullable_to_non_nullable
                        as String?,
            uniqueIdPath:
                freezed == uniqueIdPath
                    ? _value.uniqueIdPath
                    : uniqueIdPath // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FieldMappingImplCopyWith<$Res>
    implements $FieldMappingCopyWith<$Res> {
  factory _$$FieldMappingImplCopyWith(
    _$FieldMappingImpl value,
    $Res Function(_$FieldMappingImpl) then,
  ) = __$$FieldMappingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String listPath,
    String titlePath,
    String thumbPath,
    String? summaryPath,
    String? authorPath,
    String? publishTimePath,
    String? contentPath,
    String? detailUrlPath,
    String? uniqueIdPath,
  });
}

/// @nodoc
class __$$FieldMappingImplCopyWithImpl<$Res>
    extends _$FieldMappingCopyWithImpl<$Res, _$FieldMappingImpl>
    implements _$$FieldMappingImplCopyWith<$Res> {
  __$$FieldMappingImplCopyWithImpl(
    _$FieldMappingImpl _value,
    $Res Function(_$FieldMappingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FieldMapping
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? listPath = null,
    Object? titlePath = null,
    Object? thumbPath = null,
    Object? summaryPath = freezed,
    Object? authorPath = freezed,
    Object? publishTimePath = freezed,
    Object? contentPath = freezed,
    Object? detailUrlPath = freezed,
    Object? uniqueIdPath = freezed,
  }) {
    return _then(
      _$FieldMappingImpl(
        listPath:
            null == listPath
                ? _value.listPath
                : listPath // ignore: cast_nullable_to_non_nullable
                    as String,
        titlePath:
            null == titlePath
                ? _value.titlePath
                : titlePath // ignore: cast_nullable_to_non_nullable
                    as String,
        thumbPath:
            null == thumbPath
                ? _value.thumbPath
                : thumbPath // ignore: cast_nullable_to_non_nullable
                    as String,
        summaryPath:
            freezed == summaryPath
                ? _value.summaryPath
                : summaryPath // ignore: cast_nullable_to_non_nullable
                    as String?,
        authorPath:
            freezed == authorPath
                ? _value.authorPath
                : authorPath // ignore: cast_nullable_to_non_nullable
                    as String?,
        publishTimePath:
            freezed == publishTimePath
                ? _value.publishTimePath
                : publishTimePath // ignore: cast_nullable_to_non_nullable
                    as String?,
        contentPath:
            freezed == contentPath
                ? _value.contentPath
                : contentPath // ignore: cast_nullable_to_non_nullable
                    as String?,
        detailUrlPath:
            freezed == detailUrlPath
                ? _value.detailUrlPath
                : detailUrlPath // ignore: cast_nullable_to_non_nullable
                    as String?,
        uniqueIdPath:
            freezed == uniqueIdPath
                ? _value.uniqueIdPath
                : uniqueIdPath // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FieldMappingImpl implements _FieldMapping {
  const _$FieldMappingImpl({
    required this.listPath,
    required this.titlePath,
    required this.thumbPath,
    this.summaryPath,
    this.authorPath,
    this.publishTimePath,
    this.contentPath,
    this.detailUrlPath,
    this.uniqueIdPath,
  });

  factory _$FieldMappingImpl.fromJson(Map<String, dynamic> json) =>
      _$$FieldMappingImplFromJson(json);

  /// 定位数组的绝对路径（必填）。例如 "data.list"
  @override
  final String listPath;

  /// 相对路径：标题字段（必填）。例如 "title"
  @override
  final String titlePath;

  /// 相对路径：缩略图字段（必填）。例如 "thumb" 或 "images[0]"
  @override
  final String thumbPath;

  /// 相对路径：摘要（选填）
  @override
  final String? summaryPath;

  /// 相对路径：作者（选填）
  @override
  final String? authorPath;

  /// 相对路径：发布时间（选填）
  @override
  final String? publishTimePath;

  /// 相对路径：正文 HTML/纯文本（原生渲染详情时必填）
  @override
  final String? contentPath;

  /// 相对路径：详情页跳转链接（WebView 模式时必填）
  @override
  final String? detailUrlPath;

  /// 相对路径：唯一 id（去重/已读用）。缺省时用 title+thumb 做 md5
  @override
  final String? uniqueIdPath;

  @override
  String toString() {
    return 'FieldMapping(listPath: $listPath, titlePath: $titlePath, thumbPath: $thumbPath, summaryPath: $summaryPath, authorPath: $authorPath, publishTimePath: $publishTimePath, contentPath: $contentPath, detailUrlPath: $detailUrlPath, uniqueIdPath: $uniqueIdPath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FieldMappingImpl &&
            (identical(other.listPath, listPath) ||
                other.listPath == listPath) &&
            (identical(other.titlePath, titlePath) ||
                other.titlePath == titlePath) &&
            (identical(other.thumbPath, thumbPath) ||
                other.thumbPath == thumbPath) &&
            (identical(other.summaryPath, summaryPath) ||
                other.summaryPath == summaryPath) &&
            (identical(other.authorPath, authorPath) ||
                other.authorPath == authorPath) &&
            (identical(other.publishTimePath, publishTimePath) ||
                other.publishTimePath == publishTimePath) &&
            (identical(other.contentPath, contentPath) ||
                other.contentPath == contentPath) &&
            (identical(other.detailUrlPath, detailUrlPath) ||
                other.detailUrlPath == detailUrlPath) &&
            (identical(other.uniqueIdPath, uniqueIdPath) ||
                other.uniqueIdPath == uniqueIdPath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    listPath,
    titlePath,
    thumbPath,
    summaryPath,
    authorPath,
    publishTimePath,
    contentPath,
    detailUrlPath,
    uniqueIdPath,
  );

  /// Create a copy of FieldMapping
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FieldMappingImplCopyWith<_$FieldMappingImpl> get copyWith =>
      __$$FieldMappingImplCopyWithImpl<_$FieldMappingImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FieldMappingImplToJson(this);
  }
}

abstract class _FieldMapping implements FieldMapping {
  const factory _FieldMapping({
    required final String listPath,
    required final String titlePath,
    required final String thumbPath,
    final String? summaryPath,
    final String? authorPath,
    final String? publishTimePath,
    final String? contentPath,
    final String? detailUrlPath,
    final String? uniqueIdPath,
  }) = _$FieldMappingImpl;

  factory _FieldMapping.fromJson(Map<String, dynamic> json) =
      _$FieldMappingImpl.fromJson;

  /// 定位数组的绝对路径（必填）。例如 "data.list"
  @override
  String get listPath;

  /// 相对路径：标题字段（必填）。例如 "title"
  @override
  String get titlePath;

  /// 相对路径：缩略图字段（必填）。例如 "thumb" 或 "images[0]"
  @override
  String get thumbPath;

  /// 相对路径：摘要（选填）
  @override
  String? get summaryPath;

  /// 相对路径：作者（选填）
  @override
  String? get authorPath;

  /// 相对路径：发布时间（选填）
  @override
  String? get publishTimePath;

  /// 相对路径：正文 HTML/纯文本（原生渲染详情时必填）
  @override
  String? get contentPath;

  /// 相对路径：详情页跳转链接（WebView 模式时必填）
  @override
  String? get detailUrlPath;

  /// 相对路径：唯一 id（去重/已读用）。缺省时用 title+thumb 做 md5
  @override
  String? get uniqueIdPath;

  /// Create a copy of FieldMapping
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FieldMappingImplCopyWith<_$FieldMappingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
