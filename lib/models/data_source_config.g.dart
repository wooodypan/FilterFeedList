// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_source_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DataSourceConfig _$DataSourceConfigFromJson(Map<String, dynamic> json) =>
    _DataSourceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceType: json['sourceType'] == null
          ? DataSourceType.json
          : const DataSourceTypeConverter().fromJson(
              json['sourceType'] as String,
            ),
      apiUrl: json['apiUrl'] as String,
      method: json['method'] as String? ?? 'GET',
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      queryParams: (json['queryParams'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      fieldMapping: json['fieldMapping'] == null
          ? null
          : FieldMapping.fromJson(json['fieldMapping'] as Map<String, dynamic>),
      detailMode: json['detailMode'] == null
          ? DetailRenderMode.webview
          : const DetailRenderModeConverter().fromJson(
              json['detailMode'] as String,
            ),
      detailUrlTemplate: json['detailUrlTemplate'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      useAppDeepLink: json['useAppDeepLink'] as bool? ?? true,
    );

Map<String, dynamic> _$DataSourceConfigToJson(
  _DataSourceConfig instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'sourceType': const DataSourceTypeConverter().toJson(instance.sourceType),
  'apiUrl': instance.apiUrl,
  'method': instance.method,
  'headers': instance.headers,
  'queryParams': instance.queryParams,
  'fieldMapping': instance.fieldMapping,
  'detailMode': const DetailRenderModeConverter().toJson(instance.detailMode),
  'detailUrlTemplate': instance.detailUrlTemplate,
  'enabled': instance.enabled,
  'useAppDeepLink': instance.useAppDeepLink,
};
