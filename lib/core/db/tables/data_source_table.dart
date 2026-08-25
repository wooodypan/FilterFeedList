import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/data_source_config.dart';

/// 把 DataSourceConfig（复杂对象）和数据库里存的字符串互相转换。
///
/// drift 的列只能存基础类型，所以我们把整个配置序列化成 JSON 字符串存进 TEXT 列，
/// 读取时再反序列化回来。这是"结构化存储复杂配置"的常用技巧。
///
/// 注意：本应用写入时永远会带 config，所以转换器按"非空"实现即可。
class DataSourceConverter extends TypeConverter<DataSourceConfig, String> {
  const DataSourceConverter();

  @override
  DataSourceConfig fromSql(String fromDb) {
    return DataSourceConfig.fromJson(
      jsonDecode(fromDb) as Map<String, dynamic>,
    );
  }

  @override
  String toSql(DataSourceConfig value) {
    return jsonEncode(value.toJson());
  }
}

/// 数据源表：一行 = 一个数据源配置。
class DataSources extends Table {
  /// 数据源唯一 id（主键）
  TextColumn get id => text()();

  /// 展示名称
  TextColumn get name => text()();

  /// 是否启用
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 完整配置（JSON 字符串，见 DataSourceConverter）
  TextColumn get config => text().map(const DataSourceConverter())();

  @override
  Set<Column> get primaryKey => {id};
}
