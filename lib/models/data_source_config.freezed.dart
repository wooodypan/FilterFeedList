// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'data_source_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DataSourceConfig {

/// 唯一 id（本地生成，用于数据库主键 / 去重标记）
 String get id;/// 数据源名称（用户自定义，展示在 Tab 上）
 String get name;/// 数据源类型（json = JSONPath 配置源；rss = RSS/Atom 订阅源）
@DataSourceTypeConverter() DataSourceType get sourceType;/// 请求地址。json 源支持占位符 {page} 和 {pageSize}（分页时自动替换）；
/// rss 源即 feed 的 URL。
 String get apiUrl;/// 请求方法，默认 GET（仅 json 源使用）
 String get method;/// 静态请求头（有些 API 需要带 token / 自定义 UA，仅 json 源使用）
 Map<String, String>? get headers;/// 静态 query 参数（拼在 URL 后面，不参与 JSONPath，仅 json 源使用）
 Map<String, String>? get queryParams;/// 核心：字段映射规则（仅 json 源使用；rss 源为 null）
 FieldMapping? get fieldMapping;/// 详情页渲染方式
@DetailRenderModeConverter() DetailRenderMode get detailMode;/// 详情页 URL 拼接模板（如果详情走 webview 且链接需要二次拼接）
 String? get detailUrlTemplate;/// 是否启用（关闭后不参与信息流聚合）
 bool get enabled;
/// Create a copy of DataSourceConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DataSourceConfigCopyWith<DataSourceConfig> get copyWith => _$DataSourceConfigCopyWithImpl<DataSourceConfig>(this as DataSourceConfig, _$identity);

  /// Serializes this DataSourceConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DataSourceConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.apiUrl, apiUrl) || other.apiUrl == apiUrl)&&(identical(other.method, method) || other.method == method)&&const DeepCollectionEquality().equals(other.headers, headers)&&const DeepCollectionEquality().equals(other.queryParams, queryParams)&&(identical(other.fieldMapping, fieldMapping) || other.fieldMapping == fieldMapping)&&(identical(other.detailMode, detailMode) || other.detailMode == detailMode)&&(identical(other.detailUrlTemplate, detailUrlTemplate) || other.detailUrlTemplate == detailUrlTemplate)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sourceType,apiUrl,method,const DeepCollectionEquality().hash(headers),const DeepCollectionEquality().hash(queryParams),fieldMapping,detailMode,detailUrlTemplate,enabled);

@override
String toString() {
  return 'DataSourceConfig(id: $id, name: $name, sourceType: $sourceType, apiUrl: $apiUrl, method: $method, headers: $headers, queryParams: $queryParams, fieldMapping: $fieldMapping, detailMode: $detailMode, detailUrlTemplate: $detailUrlTemplate, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $DataSourceConfigCopyWith<$Res>  {
  factory $DataSourceConfigCopyWith(DataSourceConfig value, $Res Function(DataSourceConfig) _then) = _$DataSourceConfigCopyWithImpl;
@useResult
$Res call({
 String id, String name,@DataSourceTypeConverter() DataSourceType sourceType, String apiUrl, String method, Map<String, String>? headers, Map<String, String>? queryParams, FieldMapping? fieldMapping,@DetailRenderModeConverter() DetailRenderMode detailMode, String? detailUrlTemplate, bool enabled
});


$FieldMappingCopyWith<$Res>? get fieldMapping;

}
/// @nodoc
class _$DataSourceConfigCopyWithImpl<$Res>
    implements $DataSourceConfigCopyWith<$Res> {
  _$DataSourceConfigCopyWithImpl(this._self, this._then);

  final DataSourceConfig _self;
  final $Res Function(DataSourceConfig) _then;

/// Create a copy of DataSourceConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sourceType = null,Object? apiUrl = null,Object? method = null,Object? headers = freezed,Object? queryParams = freezed,Object? fieldMapping = freezed,Object? detailMode = null,Object? detailUrlTemplate = freezed,Object? enabled = null,}) {
  return _then(DataSourceConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as DataSourceType,apiUrl: null == apiUrl ? _self.apiUrl : apiUrl // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,headers: freezed == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,queryParams: freezed == queryParams ? _self.queryParams : queryParams // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,fieldMapping: freezed == fieldMapping ? _self.fieldMapping : fieldMapping // ignore: cast_nullable_to_non_nullable
as FieldMapping?,detailMode: null == detailMode ? _self.detailMode : detailMode // ignore: cast_nullable_to_non_nullable
as DetailRenderMode,detailUrlTemplate: freezed == detailUrlTemplate ? _self.detailUrlTemplate : detailUrlTemplate // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of DataSourceConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FieldMappingCopyWith<$Res>? get fieldMapping {
    if (_self.fieldMapping == null) {
    return null;
  }

  return $FieldMappingCopyWith<$Res>(_self.fieldMapping!, (value) {
    return _then(_self.copyWith(fieldMapping: value));
  });
}
}


/// Adds pattern-matching-related methods to [DataSourceConfig].
extension DataSourceConfigPatterns on DataSourceConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DataSourceConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DataSourceConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DataSourceConfig value)  $default,){
final _that = this;
switch (_that) {
case _DataSourceConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DataSourceConfig value)?  $default,){
final _that = this;
switch (_that) {
case _DataSourceConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @DataSourceTypeConverter()  DataSourceType sourceType,  String apiUrl,  String method,  Map<String, String>? headers,  Map<String, String>? queryParams,  FieldMapping? fieldMapping, @DetailRenderModeConverter()  DetailRenderMode detailMode,  String? detailUrlTemplate,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DataSourceConfig() when $default != null:
return $default(_that.id,_that.name,_that.sourceType,_that.apiUrl,_that.method,_that.headers,_that.queryParams,_that.fieldMapping,_that.detailMode,_that.detailUrlTemplate,_that.enabled);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @DataSourceTypeConverter()  DataSourceType sourceType,  String apiUrl,  String method,  Map<String, String>? headers,  Map<String, String>? queryParams,  FieldMapping? fieldMapping, @DetailRenderModeConverter()  DetailRenderMode detailMode,  String? detailUrlTemplate,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _DataSourceConfig():
return $default(_that.id,_that.name,_that.sourceType,_that.apiUrl,_that.method,_that.headers,_that.queryParams,_that.fieldMapping,_that.detailMode,_that.detailUrlTemplate,_that.enabled);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @DataSourceTypeConverter()  DataSourceType sourceType,  String apiUrl,  String method,  Map<String, String>? headers,  Map<String, String>? queryParams,  FieldMapping? fieldMapping, @DetailRenderModeConverter()  DetailRenderMode detailMode,  String? detailUrlTemplate,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _DataSourceConfig() when $default != null:
return $default(_that.id,_that.name,_that.sourceType,_that.apiUrl,_that.method,_that.headers,_that.queryParams,_that.fieldMapping,_that.detailMode,_that.detailUrlTemplate,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DataSourceConfig implements DataSourceConfig {
  const _DataSourceConfig({required this.id, required this.name, @DataSourceTypeConverter() this.sourceType = DataSourceType.json, required this.apiUrl, this.method = 'GET',  Map<String, String>? headers,  Map<String, String>? queryParams, this.fieldMapping, @DetailRenderModeConverter() this.detailMode = DetailRenderMode.webview, this.detailUrlTemplate, this.enabled = true}): _headers = headers,_queryParams = queryParams;
  factory _DataSourceConfig.fromJson(Map<String, dynamic> json) => _$DataSourceConfigFromJson(json);

/// 唯一 id（本地生成，用于数据库主键 / 去重标记）
@override final  String id;
/// 数据源名称（用户自定义，展示在 Tab 上）
@override final  String name;
/// 数据源类型（json = JSONPath 配置源；rss = RSS/Atom 订阅源）
@override@JsonKey()@DataSourceTypeConverter() final  DataSourceType sourceType;
/// 请求地址。json 源支持占位符 {page} 和 {pageSize}（分页时自动替换）；
/// rss 源即 feed 的 URL。
@override final  String apiUrl;
/// 请求方法，默认 GET（仅 json 源使用）
@override@JsonKey() final  String method;
/// 静态请求头（有些 API 需要带 token / 自定义 UA，仅 json 源使用）
 final  Map<String, String>? _headers;
/// 静态请求头（有些 API 需要带 token / 自定义 UA，仅 json 源使用）
@override Map<String, String>? get headers {
  final value = _headers;
  if (value == null) return null;
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// 静态 query 参数（拼在 URL 后面，不参与 JSONPath，仅 json 源使用）
 final  Map<String, String>? _queryParams;
/// 静态 query 参数（拼在 URL 后面，不参与 JSONPath，仅 json 源使用）
@override Map<String, String>? get queryParams {
  final value = _queryParams;
  if (value == null) return null;
  if (_queryParams is EqualUnmodifiableMapView) return _queryParams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// 核心：字段映射规则（仅 json 源使用；rss 源为 null）
@override final  FieldMapping? fieldMapping;
/// 详情页渲染方式
@override@JsonKey()@DetailRenderModeConverter() final  DetailRenderMode detailMode;
/// 详情页 URL 拼接模板（如果详情走 webview 且链接需要二次拼接）
@override final  String? detailUrlTemplate;
/// 是否启用（关闭后不参与信息流聚合）
@override@JsonKey() final  bool enabled;

/// Create a copy of DataSourceConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DataSourceConfigCopyWith<_DataSourceConfig> get copyWith => __$DataSourceConfigCopyWithImpl<_DataSourceConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DataSourceConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DataSourceConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.apiUrl, apiUrl) || other.apiUrl == apiUrl)&&(identical(other.method, method) || other.method == method)&&const DeepCollectionEquality().equals(other._headers, _headers)&&const DeepCollectionEquality().equals(other._queryParams, _queryParams)&&(identical(other.fieldMapping, fieldMapping) || other.fieldMapping == fieldMapping)&&(identical(other.detailMode, detailMode) || other.detailMode == detailMode)&&(identical(other.detailUrlTemplate, detailUrlTemplate) || other.detailUrlTemplate == detailUrlTemplate)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sourceType,apiUrl,method,const DeepCollectionEquality().hash(_headers),const DeepCollectionEquality().hash(_queryParams),fieldMapping,detailMode,detailUrlTemplate,enabled);

@override
String toString() {
  return 'DataSourceConfig(id: $id, name: $name, sourceType: $sourceType, apiUrl: $apiUrl, method: $method, headers: $headers, queryParams: $queryParams, fieldMapping: $fieldMapping, detailMode: $detailMode, detailUrlTemplate: $detailUrlTemplate, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$DataSourceConfigCopyWith<$Res> implements $DataSourceConfigCopyWith<$Res> {
  factory _$DataSourceConfigCopyWith(_DataSourceConfig value, $Res Function(_DataSourceConfig) _then) = __$DataSourceConfigCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@DataSourceTypeConverter() DataSourceType sourceType, String apiUrl, String method, Map<String, String>? headers, Map<String, String>? queryParams, FieldMapping? fieldMapping,@DetailRenderModeConverter() DetailRenderMode detailMode, String? detailUrlTemplate, bool enabled
});


@override $FieldMappingCopyWith<$Res>? get fieldMapping;

}
/// @nodoc
class __$DataSourceConfigCopyWithImpl<$Res>
    implements _$DataSourceConfigCopyWith<$Res> {
  __$DataSourceConfigCopyWithImpl(this._self, this._then);

  final _DataSourceConfig _self;
  final $Res Function(_DataSourceConfig) _then;

/// Create a copy of DataSourceConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sourceType = null,Object? apiUrl = null,Object? method = null,Object? headers = freezed,Object? queryParams = freezed,Object? fieldMapping = freezed,Object? detailMode = null,Object? detailUrlTemplate = freezed,Object? enabled = null,}) {
  return _then(_DataSourceConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as DataSourceType,apiUrl: null == apiUrl ? _self.apiUrl : apiUrl // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,headers: freezed == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,queryParams: freezed == queryParams ? _self._queryParams : queryParams // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,fieldMapping: freezed == fieldMapping ? _self.fieldMapping : fieldMapping // ignore: cast_nullable_to_non_nullable
as FieldMapping?,detailMode: null == detailMode ? _self.detailMode : detailMode // ignore: cast_nullable_to_non_nullable
as DetailRenderMode,detailUrlTemplate: freezed == detailUrlTemplate ? _self.detailUrlTemplate : detailUrlTemplate // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of DataSourceConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FieldMappingCopyWith<$Res>? get fieldMapping {
    if (_self.fieldMapping == null) {
    return null;
  }

  return $FieldMappingCopyWith<$Res>(_self.fieldMapping!, (value) {
    return _then(_self.copyWith(fieldMapping: value));
  });
}
}

// dart format on
