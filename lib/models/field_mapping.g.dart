// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'field_mapping.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FieldMappingImpl _$$FieldMappingImplFromJson(Map<String, dynamic> json) =>
    _$FieldMappingImpl(
      listPath: json['listPath'] as String,
      titlePath: json['titlePath'] as String,
      thumbPath: json['thumbPath'] as String,
      summaryPath: json['summaryPath'] as String?,
      authorPath: json['authorPath'] as String?,
      publishTimePath: json['publishTimePath'] as String?,
      contentPath: json['contentPath'] as String?,
      detailUrlPath: json['detailUrlPath'] as String?,
      uniqueIdPath: json['uniqueIdPath'] as String?,
    );

Map<String, dynamic> _$$FieldMappingImplToJson(_$FieldMappingImpl instance) =>
    <String, dynamic>{
      'listPath': instance.listPath,
      'titlePath': instance.titlePath,
      'thumbPath': instance.thumbPath,
      'summaryPath': instance.summaryPath,
      'authorPath': instance.authorPath,
      'publishTimePath': instance.publishTimePath,
      'contentPath': instance.contentPath,
      'detailUrlPath': instance.detailUrlPath,
      'uniqueIdPath': instance.uniqueIdPath,
    };
