// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'field_mapping.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FieldMapping {

/// 定位数组的绝对路径（必填）。例如 "data.list"
 String get listPath;/// 相对路径：标题字段（必填）。例如 "title"
 String get titlePath;/// 相对路径：缩略图字段（必填）。例如 "thumb" 或 "images[0]"
 String get thumbPath;/// 相对路径：摘要（选填）
 String? get summaryPath;/// 相对路径：作者（选填）
 String? get authorPath;/// 相对路径：发布时间（选填）
 String? get publishTimePath;/// 相对路径：正文 HTML/纯文本（原生渲染详情时必填）
 String? get contentPath;/// 相对路径：详情页跳转链接（WebView 模式时必填）
 String? get detailUrlPath;/// 相对路径：唯一 id（去重/已读用）。缺省时用 title+thumb 做 md5
 String? get uniqueIdPath;
/// Create a copy of FieldMapping
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FieldMappingCopyWith<FieldMapping> get copyWith => _$FieldMappingCopyWithImpl<FieldMapping>(this as FieldMapping, _$identity);

  /// Serializes this FieldMapping to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FieldMapping&&(identical(other.listPath, listPath) || other.listPath == listPath)&&(identical(other.titlePath, titlePath) || other.titlePath == titlePath)&&(identical(other.thumbPath, thumbPath) || other.thumbPath == thumbPath)&&(identical(other.summaryPath, summaryPath) || other.summaryPath == summaryPath)&&(identical(other.authorPath, authorPath) || other.authorPath == authorPath)&&(identical(other.publishTimePath, publishTimePath) || other.publishTimePath == publishTimePath)&&(identical(other.contentPath, contentPath) || other.contentPath == contentPath)&&(identical(other.detailUrlPath, detailUrlPath) || other.detailUrlPath == detailUrlPath)&&(identical(other.uniqueIdPath, uniqueIdPath) || other.uniqueIdPath == uniqueIdPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,listPath,titlePath,thumbPath,summaryPath,authorPath,publishTimePath,contentPath,detailUrlPath,uniqueIdPath);

@override
String toString() {
  return 'FieldMapping(listPath: $listPath, titlePath: $titlePath, thumbPath: $thumbPath, summaryPath: $summaryPath, authorPath: $authorPath, publishTimePath: $publishTimePath, contentPath: $contentPath, detailUrlPath: $detailUrlPath, uniqueIdPath: $uniqueIdPath)';
}


}

/// @nodoc
abstract mixin class $FieldMappingCopyWith<$Res>  {
  factory $FieldMappingCopyWith(FieldMapping value, $Res Function(FieldMapping) _then) = _$FieldMappingCopyWithImpl;
@useResult
$Res call({
 String listPath, String titlePath, String thumbPath, String? summaryPath, String? authorPath, String? publishTimePath, String? contentPath, String? detailUrlPath, String? uniqueIdPath
});




}
/// @nodoc
class _$FieldMappingCopyWithImpl<$Res>
    implements $FieldMappingCopyWith<$Res> {
  _$FieldMappingCopyWithImpl(this._self, this._then);

  final FieldMapping _self;
  final $Res Function(FieldMapping) _then;

/// Create a copy of FieldMapping
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? listPath = null,Object? titlePath = null,Object? thumbPath = null,Object? summaryPath = freezed,Object? authorPath = freezed,Object? publishTimePath = freezed,Object? contentPath = freezed,Object? detailUrlPath = freezed,Object? uniqueIdPath = freezed,}) {
  return _then(FieldMapping(
listPath: null == listPath ? _self.listPath : listPath // ignore: cast_nullable_to_non_nullable
as String,titlePath: null == titlePath ? _self.titlePath : titlePath // ignore: cast_nullable_to_non_nullable
as String,thumbPath: null == thumbPath ? _self.thumbPath : thumbPath // ignore: cast_nullable_to_non_nullable
as String,summaryPath: freezed == summaryPath ? _self.summaryPath : summaryPath // ignore: cast_nullable_to_non_nullable
as String?,authorPath: freezed == authorPath ? _self.authorPath : authorPath // ignore: cast_nullable_to_non_nullable
as String?,publishTimePath: freezed == publishTimePath ? _self.publishTimePath : publishTimePath // ignore: cast_nullable_to_non_nullable
as String?,contentPath: freezed == contentPath ? _self.contentPath : contentPath // ignore: cast_nullable_to_non_nullable
as String?,detailUrlPath: freezed == detailUrlPath ? _self.detailUrlPath : detailUrlPath // ignore: cast_nullable_to_non_nullable
as String?,uniqueIdPath: freezed == uniqueIdPath ? _self.uniqueIdPath : uniqueIdPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FieldMapping].
extension FieldMappingPatterns on FieldMapping {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FieldMapping value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FieldMapping() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FieldMapping value)  $default,){
final _that = this;
switch (_that) {
case _FieldMapping():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FieldMapping value)?  $default,){
final _that = this;
switch (_that) {
case _FieldMapping() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String listPath,  String titlePath,  String thumbPath,  String? summaryPath,  String? authorPath,  String? publishTimePath,  String? contentPath,  String? detailUrlPath,  String? uniqueIdPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FieldMapping() when $default != null:
return $default(_that.listPath,_that.titlePath,_that.thumbPath,_that.summaryPath,_that.authorPath,_that.publishTimePath,_that.contentPath,_that.detailUrlPath,_that.uniqueIdPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String listPath,  String titlePath,  String thumbPath,  String? summaryPath,  String? authorPath,  String? publishTimePath,  String? contentPath,  String? detailUrlPath,  String? uniqueIdPath)  $default,) {final _that = this;
switch (_that) {
case _FieldMapping():
return $default(_that.listPath,_that.titlePath,_that.thumbPath,_that.summaryPath,_that.authorPath,_that.publishTimePath,_that.contentPath,_that.detailUrlPath,_that.uniqueIdPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String listPath,  String titlePath,  String thumbPath,  String? summaryPath,  String? authorPath,  String? publishTimePath,  String? contentPath,  String? detailUrlPath,  String? uniqueIdPath)?  $default,) {final _that = this;
switch (_that) {
case _FieldMapping() when $default != null:
return $default(_that.listPath,_that.titlePath,_that.thumbPath,_that.summaryPath,_that.authorPath,_that.publishTimePath,_that.contentPath,_that.detailUrlPath,_that.uniqueIdPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FieldMapping implements FieldMapping {
  const _FieldMapping({required this.listPath, required this.titlePath, required this.thumbPath, this.summaryPath, this.authorPath, this.publishTimePath, this.contentPath, this.detailUrlPath, this.uniqueIdPath});
  factory _FieldMapping.fromJson(Map<String, dynamic> json) => _$FieldMappingFromJson(json);

/// 定位数组的绝对路径（必填）。例如 "data.list"
@override final  String listPath;
/// 相对路径：标题字段（必填）。例如 "title"
@override final  String titlePath;
/// 相对路径：缩略图字段（必填）。例如 "thumb" 或 "images[0]"
@override final  String thumbPath;
/// 相对路径：摘要（选填）
@override final  String? summaryPath;
/// 相对路径：作者（选填）
@override final  String? authorPath;
/// 相对路径：发布时间（选填）
@override final  String? publishTimePath;
/// 相对路径：正文 HTML/纯文本（原生渲染详情时必填）
@override final  String? contentPath;
/// 相对路径：详情页跳转链接（WebView 模式时必填）
@override final  String? detailUrlPath;
/// 相对路径：唯一 id（去重/已读用）。缺省时用 title+thumb 做 md5
@override final  String? uniqueIdPath;

/// Create a copy of FieldMapping
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FieldMappingCopyWith<_FieldMapping> get copyWith => __$FieldMappingCopyWithImpl<_FieldMapping>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FieldMappingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FieldMapping&&(identical(other.listPath, listPath) || other.listPath == listPath)&&(identical(other.titlePath, titlePath) || other.titlePath == titlePath)&&(identical(other.thumbPath, thumbPath) || other.thumbPath == thumbPath)&&(identical(other.summaryPath, summaryPath) || other.summaryPath == summaryPath)&&(identical(other.authorPath, authorPath) || other.authorPath == authorPath)&&(identical(other.publishTimePath, publishTimePath) || other.publishTimePath == publishTimePath)&&(identical(other.contentPath, contentPath) || other.contentPath == contentPath)&&(identical(other.detailUrlPath, detailUrlPath) || other.detailUrlPath == detailUrlPath)&&(identical(other.uniqueIdPath, uniqueIdPath) || other.uniqueIdPath == uniqueIdPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,listPath,titlePath,thumbPath,summaryPath,authorPath,publishTimePath,contentPath,detailUrlPath,uniqueIdPath);

@override
String toString() {
  return 'FieldMapping(listPath: $listPath, titlePath: $titlePath, thumbPath: $thumbPath, summaryPath: $summaryPath, authorPath: $authorPath, publishTimePath: $publishTimePath, contentPath: $contentPath, detailUrlPath: $detailUrlPath, uniqueIdPath: $uniqueIdPath)';
}


}

/// @nodoc
abstract mixin class _$FieldMappingCopyWith<$Res> implements $FieldMappingCopyWith<$Res> {
  factory _$FieldMappingCopyWith(_FieldMapping value, $Res Function(_FieldMapping) _then) = __$FieldMappingCopyWithImpl;
@override @useResult
$Res call({
 String listPath, String titlePath, String thumbPath, String? summaryPath, String? authorPath, String? publishTimePath, String? contentPath, String? detailUrlPath, String? uniqueIdPath
});




}
/// @nodoc
class __$FieldMappingCopyWithImpl<$Res>
    implements _$FieldMappingCopyWith<$Res> {
  __$FieldMappingCopyWithImpl(this._self, this._then);

  final _FieldMapping _self;
  final $Res Function(_FieldMapping) _then;

/// Create a copy of FieldMapping
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? listPath = null,Object? titlePath = null,Object? thumbPath = null,Object? summaryPath = freezed,Object? authorPath = freezed,Object? publishTimePath = freezed,Object? contentPath = freezed,Object? detailUrlPath = freezed,Object? uniqueIdPath = freezed,}) {
  return _then(_FieldMapping(
listPath: null == listPath ? _self.listPath : listPath // ignore: cast_nullable_to_non_nullable
as String,titlePath: null == titlePath ? _self.titlePath : titlePath // ignore: cast_nullable_to_non_nullable
as String,thumbPath: null == thumbPath ? _self.thumbPath : thumbPath // ignore: cast_nullable_to_non_nullable
as String,summaryPath: freezed == summaryPath ? _self.summaryPath : summaryPath // ignore: cast_nullable_to_non_nullable
as String?,authorPath: freezed == authorPath ? _self.authorPath : authorPath // ignore: cast_nullable_to_non_nullable
as String?,publishTimePath: freezed == publishTimePath ? _self.publishTimePath : publishTimePath // ignore: cast_nullable_to_non_nullable
as String?,contentPath: freezed == contentPath ? _self.contentPath : contentPath // ignore: cast_nullable_to_non_nullable
as String?,detailUrlPath: freezed == detailUrlPath ? _self.detailUrlPath : detailUrlPath // ignore: cast_nullable_to_non_nullable
as String?,uniqueIdPath: freezed == uniqueIdPath ? _self.uniqueIdPath : uniqueIdPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
