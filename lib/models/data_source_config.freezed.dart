// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'data_source_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DataSourceConfig _$DataSourceConfigFromJson(Map<String, dynamic> json) {
  return _DataSourceConfig.fromJson(json);
}

/// @nodoc
mixin _$DataSourceConfig {
  /// 唯一 id（本地生成，用于数据库主键 / 去重标记）
  String get id => throw _privateConstructorUsedError;

  /// 数据源名称（用户自定义，展示在 Tab 上）
  String get name => throw _privateConstructorUsedError;

  /// 请求地址，支持占位符 {page} 和 {pageSize}（分页时自动替换）
  String get apiUrl => throw _privateConstructorUsedError;

  /// 请求方法，默认 GET
  String get method => throw _privateConstructorUsedError;

  /// 静态请求头（有些 API 需要带 token / 自定义 UA）
  Map<String, String>? get headers => throw _privateConstructorUsedError;

  /// 静态 query 参数（拼在 URL 后面，不参与 JSONPath）
  Map<String, String>? get queryParams => throw _privateConstructorUsedError;

  /// 核心：字段映射规则
  FieldMapping get fieldMapping => throw _privateConstructorUsedError;

  /// 详情页渲染方式
  @DetailRenderModeConverter()
  DetailRenderMode get detailMode => throw _privateConstructorUsedError;

  /// 详情页 URL 拼接模板（如果详情走 webview 且链接需要二次拼接）
  String? get detailUrlTemplate => throw _privateConstructorUsedError;

  /// 是否启用（关闭后不参与信息流聚合）
  bool get enabled => throw _privateConstructorUsedError;

  /// Serializes this DataSourceConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DataSourceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DataSourceConfigCopyWith<DataSourceConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DataSourceConfigCopyWith<$Res> {
  factory $DataSourceConfigCopyWith(
    DataSourceConfig value,
    $Res Function(DataSourceConfig) then,
  ) = _$DataSourceConfigCopyWithImpl<$Res, DataSourceConfig>;
  @useResult
  $Res call({
    String id,
    String name,
    String apiUrl,
    String method,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    FieldMapping fieldMapping,
    @DetailRenderModeConverter() DetailRenderMode detailMode,
    String? detailUrlTemplate,
    bool enabled,
  });

  $FieldMappingCopyWith<$Res> get fieldMapping;
}

/// @nodoc
class _$DataSourceConfigCopyWithImpl<$Res, $Val extends DataSourceConfig>
    implements $DataSourceConfigCopyWith<$Res> {
  _$DataSourceConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DataSourceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? apiUrl = null,
    Object? method = null,
    Object? headers = freezed,
    Object? queryParams = freezed,
    Object? fieldMapping = null,
    Object? detailMode = null,
    Object? detailUrlTemplate = freezed,
    Object? enabled = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            apiUrl:
                null == apiUrl
                    ? _value.apiUrl
                    : apiUrl // ignore: cast_nullable_to_non_nullable
                        as String,
            method:
                null == method
                    ? _value.method
                    : method // ignore: cast_nullable_to_non_nullable
                        as String,
            headers:
                freezed == headers
                    ? _value.headers
                    : headers // ignore: cast_nullable_to_non_nullable
                        as Map<String, String>?,
            queryParams:
                freezed == queryParams
                    ? _value.queryParams
                    : queryParams // ignore: cast_nullable_to_non_nullable
                        as Map<String, String>?,
            fieldMapping:
                null == fieldMapping
                    ? _value.fieldMapping
                    : fieldMapping // ignore: cast_nullable_to_non_nullable
                        as FieldMapping,
            detailMode:
                null == detailMode
                    ? _value.detailMode
                    : detailMode // ignore: cast_nullable_to_non_nullable
                        as DetailRenderMode,
            detailUrlTemplate:
                freezed == detailUrlTemplate
                    ? _value.detailUrlTemplate
                    : detailUrlTemplate // ignore: cast_nullable_to_non_nullable
                        as String?,
            enabled:
                null == enabled
                    ? _value.enabled
                    : enabled // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of DataSourceConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FieldMappingCopyWith<$Res> get fieldMapping {
    return $FieldMappingCopyWith<$Res>(_value.fieldMapping, (value) {
      return _then(_value.copyWith(fieldMapping: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DataSourceConfigImplCopyWith<$Res>
    implements $DataSourceConfigCopyWith<$Res> {
  factory _$$DataSourceConfigImplCopyWith(
    _$DataSourceConfigImpl value,
    $Res Function(_$DataSourceConfigImpl) then,
  ) = __$$DataSourceConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String apiUrl,
    String method,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    FieldMapping fieldMapping,
    @DetailRenderModeConverter() DetailRenderMode detailMode,
    String? detailUrlTemplate,
    bool enabled,
  });

  @override
  $FieldMappingCopyWith<$Res> get fieldMapping;
}

/// @nodoc
class __$$DataSourceConfigImplCopyWithImpl<$Res>
    extends _$DataSourceConfigCopyWithImpl<$Res, _$DataSourceConfigImpl>
    implements _$$DataSourceConfigImplCopyWith<$Res> {
  __$$DataSourceConfigImplCopyWithImpl(
    _$DataSourceConfigImpl _value,
    $Res Function(_$DataSourceConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DataSourceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? apiUrl = null,
    Object? method = null,
    Object? headers = freezed,
    Object? queryParams = freezed,
    Object? fieldMapping = null,
    Object? detailMode = null,
    Object? detailUrlTemplate = freezed,
    Object? enabled = null,
  }) {
    return _then(
      _$DataSourceConfigImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        apiUrl:
            null == apiUrl
                ? _value.apiUrl
                : apiUrl // ignore: cast_nullable_to_non_nullable
                    as String,
        method:
            null == method
                ? _value.method
                : method // ignore: cast_nullable_to_non_nullable
                    as String,
        headers:
            freezed == headers
                ? _value._headers
                : headers // ignore: cast_nullable_to_non_nullable
                    as Map<String, String>?,
        queryParams:
            freezed == queryParams
                ? _value._queryParams
                : queryParams // ignore: cast_nullable_to_non_nullable
                    as Map<String, String>?,
        fieldMapping:
            null == fieldMapping
                ? _value.fieldMapping
                : fieldMapping // ignore: cast_nullable_to_non_nullable
                    as FieldMapping,
        detailMode:
            null == detailMode
                ? _value.detailMode
                : detailMode // ignore: cast_nullable_to_non_nullable
                    as DetailRenderMode,
        detailUrlTemplate:
            freezed == detailUrlTemplate
                ? _value.detailUrlTemplate
                : detailUrlTemplate // ignore: cast_nullable_to_non_nullable
                    as String?,
        enabled:
            null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DataSourceConfigImpl implements _DataSourceConfig {
  const _$DataSourceConfigImpl({
    required this.id,
    required this.name,
    required this.apiUrl,
    this.method = 'GET',
    final Map<String, String>? headers,
    final Map<String, String>? queryParams,
    required this.fieldMapping,
    @DetailRenderModeConverter() this.detailMode = DetailRenderMode.webview,
    this.detailUrlTemplate,
    this.enabled = true,
  }) : _headers = headers,
       _queryParams = queryParams;

  factory _$DataSourceConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$DataSourceConfigImplFromJson(json);

  /// 唯一 id（本地生成，用于数据库主键 / 去重标记）
  @override
  final String id;

  /// 数据源名称（用户自定义，展示在 Tab 上）
  @override
  final String name;

  /// 请求地址，支持占位符 {page} 和 {pageSize}（分页时自动替换）
  @override
  final String apiUrl;

  /// 请求方法，默认 GET
  @override
  @JsonKey()
  final String method;

  /// 静态请求头（有些 API 需要带 token / 自定义 UA）
  final Map<String, String>? _headers;

  /// 静态请求头（有些 API 需要带 token / 自定义 UA）
  @override
  Map<String, String>? get headers {
    final value = _headers;
    if (value == null) return null;
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// 静态 query 参数（拼在 URL 后面，不参与 JSONPath）
  final Map<String, String>? _queryParams;

  /// 静态 query 参数（拼在 URL 后面，不参与 JSONPath）
  @override
  Map<String, String>? get queryParams {
    final value = _queryParams;
    if (value == null) return null;
    if (_queryParams is EqualUnmodifiableMapView) return _queryParams;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// 核心：字段映射规则
  @override
  final FieldMapping fieldMapping;

  /// 详情页渲染方式
  @override
  @JsonKey()
  @DetailRenderModeConverter()
  final DetailRenderMode detailMode;

  /// 详情页 URL 拼接模板（如果详情走 webview 且链接需要二次拼接）
  @override
  final String? detailUrlTemplate;

  /// 是否启用（关闭后不参与信息流聚合）
  @override
  @JsonKey()
  final bool enabled;

  @override
  String toString() {
    return 'DataSourceConfig(id: $id, name: $name, apiUrl: $apiUrl, method: $method, headers: $headers, queryParams: $queryParams, fieldMapping: $fieldMapping, detailMode: $detailMode, detailUrlTemplate: $detailUrlTemplate, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DataSourceConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.apiUrl, apiUrl) || other.apiUrl == apiUrl) &&
            (identical(other.method, method) || other.method == method) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            const DeepCollectionEquality().equals(
              other._queryParams,
              _queryParams,
            ) &&
            (identical(other.fieldMapping, fieldMapping) ||
                other.fieldMapping == fieldMapping) &&
            (identical(other.detailMode, detailMode) ||
                other.detailMode == detailMode) &&
            (identical(other.detailUrlTemplate, detailUrlTemplate) ||
                other.detailUrlTemplate == detailUrlTemplate) &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    apiUrl,
    method,
    const DeepCollectionEquality().hash(_headers),
    const DeepCollectionEquality().hash(_queryParams),
    fieldMapping,
    detailMode,
    detailUrlTemplate,
    enabled,
  );

  /// Create a copy of DataSourceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DataSourceConfigImplCopyWith<_$DataSourceConfigImpl> get copyWith =>
      __$$DataSourceConfigImplCopyWithImpl<_$DataSourceConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DataSourceConfigImplToJson(this);
  }
}

abstract class _DataSourceConfig implements DataSourceConfig {
  const factory _DataSourceConfig({
    required final String id,
    required final String name,
    required final String apiUrl,
    final String method,
    final Map<String, String>? headers,
    final Map<String, String>? queryParams,
    required final FieldMapping fieldMapping,
    @DetailRenderModeConverter() final DetailRenderMode detailMode,
    final String? detailUrlTemplate,
    final bool enabled,
  }) = _$DataSourceConfigImpl;

  factory _DataSourceConfig.fromJson(Map<String, dynamic> json) =
      _$DataSourceConfigImpl.fromJson;

  /// 唯一 id（本地生成，用于数据库主键 / 去重标记）
  @override
  String get id;

  /// 数据源名称（用户自定义，展示在 Tab 上）
  @override
  String get name;

  /// 请求地址，支持占位符 {page} 和 {pageSize}（分页时自动替换）
  @override
  String get apiUrl;

  /// 请求方法，默认 GET
  @override
  String get method;

  /// 静态请求头（有些 API 需要带 token / 自定义 UA）
  @override
  Map<String, String>? get headers;

  /// 静态 query 参数（拼在 URL 后面，不参与 JSONPath）
  @override
  Map<String, String>? get queryParams;

  /// 核心：字段映射规则
  @override
  FieldMapping get fieldMapping;

  /// 详情页渲染方式
  @override
  @DetailRenderModeConverter()
  DetailRenderMode get detailMode;

  /// 详情页 URL 拼接模板（如果详情走 webview 且链接需要二次拼接）
  @override
  String? get detailUrlTemplate;

  /// 是否启用（关闭后不参与信息流聚合）
  @override
  bool get enabled;

  /// Create a copy of DataSourceConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DataSourceConfigImplCopyWith<_$DataSourceConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
