// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_source_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DataSourceConfigImpl _$$DataSourceConfigImplFromJson(
  Map<String, dynamic> json,
) => _$DataSourceConfigImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  apiUrl: json['apiUrl'] as String,
  method: json['method'] as String? ?? 'GET',
  headers: (json['headers'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  queryParams: (json['queryParams'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  fieldMapping: FieldMapping.fromJson(
    json['fieldMapping'] as Map<String, dynamic>,
  ),
  detailMode:
      json['detailMode'] == null
          ? DetailRenderMode.webview
          : const DetailRenderModeConverter().fromJson(
            json['detailMode'] as String,
          ),
  detailUrlTemplate: json['detailUrlTemplate'] as String?,
  enabled: json['enabled'] as bool? ?? true,
);

Map<String, dynamic> _$$DataSourceConfigImplToJson(
  _$DataSourceConfigImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'apiUrl': instance.apiUrl,
  'method': instance.method,
  'headers': instance.headers,
  'queryParams': instance.queryParams,
  'fieldMapping': instance.fieldMapping,
  'detailMode': const DetailRenderModeConverter().toJson(instance.detailMode),
  'detailUrlTemplate': instance.detailUrlTemplate,
  'enabled': instance.enabled,
};
