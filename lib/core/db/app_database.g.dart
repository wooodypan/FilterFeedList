// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DataSourcesTable extends DataSources
    with TableInfo<$DataSourcesTable, DataSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DataSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSourceConfig, String> config =
      GeneratedColumn<String>(
        'config',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DataSourceConfig>($DataSourcesTable.$converterconfig);
  @override
  List<GeneratedColumn> get $columns => [id, name, enabled, config];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'data_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<DataSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DataSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DataSource(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      enabled:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}enabled'],
          )!,
      config: $DataSourcesTable.$converterconfig.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}config'],
        )!,
      ),
    );
  }

  @override
  $DataSourcesTable createAlias(String alias) {
    return $DataSourcesTable(attachedDatabase, alias);
  }

  static TypeConverter<DataSourceConfig, String> $converterconfig =
      const DataSourceConverter();
}

class DataSource extends DataClass implements Insertable<DataSource> {
  /// 数据源唯一 id（主键）
  final String id;

  /// 展示名称
  final String name;

  /// 是否启用
  final bool enabled;

  /// 完整配置（JSON 字符串，见 DataSourceConverter）
  final DataSourceConfig config;
  const DataSource({
    required this.id,
    required this.name,
    required this.enabled,
    required this.config,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['enabled'] = Variable<bool>(enabled);
    {
      map['config'] = Variable<String>(
        $DataSourcesTable.$converterconfig.toSql(config),
      );
    }
    return map;
  }

  DataSourcesCompanion toCompanion(bool nullToAbsent) {
    return DataSourcesCompanion(
      id: Value(id),
      name: Value(name),
      enabled: Value(enabled),
      config: Value(config),
    );
  }

  factory DataSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DataSource(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      config: serializer.fromJson<DataSourceConfig>(json['config']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'enabled': serializer.toJson<bool>(enabled),
      'config': serializer.toJson<DataSourceConfig>(config),
    };
  }

  DataSource copyWith({
    String? id,
    String? name,
    bool? enabled,
    DataSourceConfig? config,
  }) => DataSource(
    id: id ?? this.id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    config: config ?? this.config,
  );
  DataSource copyWithCompanion(DataSourcesCompanion data) {
    return DataSource(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      config: data.config.present ? data.config.value : this.config,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataSource(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('enabled: $enabled, ')
          ..write('config: $config')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, enabled, config);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataSource &&
          other.id == this.id &&
          other.name == this.name &&
          other.enabled == this.enabled &&
          other.config == this.config);
}

class DataSourcesCompanion extends UpdateCompanion<DataSource> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> enabled;
  final Value<DataSourceConfig> config;
  final Value<int> rowid;
  const DataSourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.enabled = const Value.absent(),
    this.config = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DataSourcesCompanion.insert({
    required String id,
    required String name,
    this.enabled = const Value.absent(),
    required DataSourceConfig config,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       config = Value(config);
  static Insertable<DataSource> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? enabled,
    Expression<String>? config,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (enabled != null) 'enabled': enabled,
      if (config != null) 'config': config,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DataSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? enabled,
    Value<DataSourceConfig>? config,
    Value<int>? rowid,
  }) {
    return DataSourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      config: config ?? this.config,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(
        $DataSourcesTable.$converterconfig.toSql(config.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DataSourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('enabled: $enabled, ')
          ..write('config: $config, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlockedKeywordsTable extends BlockedKeywords
    with TableInfo<$BlockedKeywordsTable, BlockedKeyword> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockedKeywordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, word, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocked_keywords';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockedKeyword> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlockedKeyword map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockedKeyword(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      word:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}word'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $BlockedKeywordsTable createAlias(String alias) {
    return $BlockedKeywordsTable(attachedDatabase, alias);
  }
}

class BlockedKeyword extends DataClass implements Insertable<BlockedKeyword> {
  /// 自增主键
  final int id;

  /// 屏蔽词内容（唯一，避免重复添加）
  final String word;

  /// 添加时间（用于排序展示）
  final DateTime createdAt;
  const BlockedKeyword({
    required this.id,
    required this.word,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BlockedKeywordsCompanion toCompanion(bool nullToAbsent) {
    return BlockedKeywordsCompanion(
      id: Value(id),
      word: Value(word),
      createdAt: Value(createdAt),
    );
  }

  factory BlockedKeyword.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockedKeyword(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BlockedKeyword copyWith({int? id, String? word, DateTime? createdAt}) =>
      BlockedKeyword(
        id: id ?? this.id,
        word: word ?? this.word,
        createdAt: createdAt ?? this.createdAt,
      );
  BlockedKeyword copyWithCompanion(BlockedKeywordsCompanion data) {
    return BlockedKeyword(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockedKeyword(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockedKeyword &&
          other.id == this.id &&
          other.word == this.word &&
          other.createdAt == this.createdAt);
}

class BlockedKeywordsCompanion extends UpdateCompanion<BlockedKeyword> {
  final Value<int> id;
  final Value<String> word;
  final Value<DateTime> createdAt;
  const BlockedKeywordsCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BlockedKeywordsCompanion.insert({
    this.id = const Value.absent(),
    required String word,
    this.createdAt = const Value.absent(),
  }) : word = Value(word);
  static Insertable<BlockedKeyword> custom({
    Expression<int>? id,
    Expression<String>? word,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BlockedKeywordsCompanion copyWith({
    Value<int>? id,
    Value<String>? word,
    Value<DateTime>? createdAt,
  }) {
    return BlockedKeywordsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockedKeywordsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DataSourcesTable dataSources = $DataSourcesTable(this);
  late final $BlockedKeywordsTable blockedKeywords = $BlockedKeywordsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dataSources,
    blockedKeywords,
  ];
}

typedef $$DataSourcesTableCreateCompanionBuilder =
    DataSourcesCompanion Function({
      required String id,
      required String name,
      Value<bool> enabled,
      required DataSourceConfig config,
      Value<int> rowid,
    });
typedef $$DataSourcesTableUpdateCompanionBuilder =
    DataSourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<bool> enabled,
      Value<DataSourceConfig> config,
      Value<int> rowid,
    });

class $$DataSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $DataSourcesTable> {
  $$DataSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSourceConfig, DataSourceConfig, String>
  get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$DataSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $DataSourcesTable> {
  $$DataSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DataSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DataSourcesTable> {
  $$DataSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DataSourceConfig, String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => column);
}

class $$DataSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DataSourcesTable,
          DataSource,
          $$DataSourcesTableFilterComposer,
          $$DataSourcesTableOrderingComposer,
          $$DataSourcesTableAnnotationComposer,
          $$DataSourcesTableCreateCompanionBuilder,
          $$DataSourcesTableUpdateCompanionBuilder,
          (
            DataSource,
            BaseReferences<_$AppDatabase, $DataSourcesTable, DataSource>,
          ),
          DataSource,
          PrefetchHooks Function()
        > {
  $$DataSourcesTableTableManager(_$AppDatabase db, $DataSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DataSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$DataSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$DataSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DataSourceConfig> config = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DataSourcesCompanion(
                id: id,
                name: name,
                enabled: enabled,
                config: config,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<bool> enabled = const Value.absent(),
                required DataSourceConfig config,
                Value<int> rowid = const Value.absent(),
              }) => DataSourcesCompanion.insert(
                id: id,
                name: name,
                enabled: enabled,
                config: config,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DataSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DataSourcesTable,
      DataSource,
      $$DataSourcesTableFilterComposer,
      $$DataSourcesTableOrderingComposer,
      $$DataSourcesTableAnnotationComposer,
      $$DataSourcesTableCreateCompanionBuilder,
      $$DataSourcesTableUpdateCompanionBuilder,
      (
        DataSource,
        BaseReferences<_$AppDatabase, $DataSourcesTable, DataSource>,
      ),
      DataSource,
      PrefetchHooks Function()
    >;
typedef $$BlockedKeywordsTableCreateCompanionBuilder =
    BlockedKeywordsCompanion Function({
      Value<int> id,
      required String word,
      Value<DateTime> createdAt,
    });
typedef $$BlockedKeywordsTableUpdateCompanionBuilder =
    BlockedKeywordsCompanion Function({
      Value<int> id,
      Value<String> word,
      Value<DateTime> createdAt,
    });

class $$BlockedKeywordsTableFilterComposer
    extends Composer<_$AppDatabase, $BlockedKeywordsTable> {
  $$BlockedKeywordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlockedKeywordsTableOrderingComposer
    extends Composer<_$AppDatabase, $BlockedKeywordsTable> {
  $$BlockedKeywordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlockedKeywordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlockedKeywordsTable> {
  $$BlockedKeywordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BlockedKeywordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlockedKeywordsTable,
          BlockedKeyword,
          $$BlockedKeywordsTableFilterComposer,
          $$BlockedKeywordsTableOrderingComposer,
          $$BlockedKeywordsTableAnnotationComposer,
          $$BlockedKeywordsTableCreateCompanionBuilder,
          $$BlockedKeywordsTableUpdateCompanionBuilder,
          (
            BlockedKeyword,
            BaseReferences<
              _$AppDatabase,
              $BlockedKeywordsTable,
              BlockedKeyword
            >,
          ),
          BlockedKeyword,
          PrefetchHooks Function()
        > {
  $$BlockedKeywordsTableTableManager(
    _$AppDatabase db,
    $BlockedKeywordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$BlockedKeywordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$BlockedKeywordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$BlockedKeywordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BlockedKeywordsCompanion(
                id: id,
                word: word,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String word,
                Value<DateTime> createdAt = const Value.absent(),
              }) => BlockedKeywordsCompanion.insert(
                id: id,
                word: word,
                createdAt: createdAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlockedKeywordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlockedKeywordsTable,
      BlockedKeyword,
      $$BlockedKeywordsTableFilterComposer,
      $$BlockedKeywordsTableOrderingComposer,
      $$BlockedKeywordsTableAnnotationComposer,
      $$BlockedKeywordsTableCreateCompanionBuilder,
      $$BlockedKeywordsTableUpdateCompanionBuilder,
      (
        BlockedKeyword,
        BaseReferences<_$AppDatabase, $BlockedKeywordsTable, BlockedKeyword>,
      ),
      BlockedKeyword,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DataSourcesTableTableManager get dataSources =>
      $$DataSourcesTableTableManager(_db, _db.dataSources);
  $$BlockedKeywordsTableTableManager get blockedKeywords =>
      $$BlockedKeywordsTableTableManager(_db, _db.blockedKeywords);
}
