import 'package:drift/drift.dart';

/// 屏蔽词表：一行 = 一个被屏蔽的关键词。
class BlockedKeywords extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 屏蔽词内容（唯一，避免重复添加）
  TextColumn get word => text().unique()();

  /// 添加时间（用于排序展示）
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
