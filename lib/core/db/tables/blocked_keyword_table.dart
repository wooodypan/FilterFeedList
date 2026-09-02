import 'package:drift/drift.dart';

/// 屏蔽词表：一行 = 一个被屏蔽的关键词。
class BlockedKeywords extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 屏蔽词内容（唯一，避免重复添加）
  TextColumn get word => text().unique()();

  /// 添加时间（用于排序展示）
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 屏蔽到期时间。
  ///
  /// - 为 NULL 表示「永久屏蔽」，永远不会自动失效；
  /// - 有值表示「只在该时间之前生效」，过期后自动失效（但行仍保留在库里，
  ///   便于页面显示「已过期」状态，也方便用户续期 / 恢复）。
  ///
  /// 老数据库升级时这一列默认就是 NULL，天然等价于「永久」，
  /// 无需写额外 UPDATE 把老数据回填成永久。
  DateTimeColumn get expiresAt => dateTime().nullable()();
}
