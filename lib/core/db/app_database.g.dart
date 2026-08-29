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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  List<GeneratedColumn> get $columns => [id, name, enabled, sortOrder, config];
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
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
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

  /// 信息流顶部 Tab 的排序序号（越小越靠前）。
  ///
  /// 用户在信息流页长按拖动 Tab 后，会按新顺序重新编号并写回本列，
  /// 这样下次启动 App 时 Tab 顺序和上次一致。
  /// 注意：序号是"全局"的——数据源表和插件表共用一套编号，
  /// 所以两表混合排序也能还原出用户排好的交错顺序。
  final int sortOrder;

  /// 完整配置（JSON 字符串，见 DataSourceConverter）
  final DataSourceConfig config;
  const DataSource({
    required this.id,
    required this.name,
    required this.enabled,
    required this.sortOrder,
    required this.config,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
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
      sortOrder: Value(sortOrder),
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
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
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
      'sortOrder': serializer.toJson<int>(sortOrder),
      'config': serializer.toJson<DataSourceConfig>(config),
    };
  }

  DataSource copyWith({
    String? id,
    String? name,
    bool? enabled,
    int? sortOrder,
    DataSourceConfig? config,
  }) => DataSource(
    id: id ?? this.id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    sortOrder: sortOrder ?? this.sortOrder,
    config: config ?? this.config,
  );
  DataSource copyWithCompanion(DataSourcesCompanion data) {
    return DataSource(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      config: data.config.present ? data.config.value : this.config,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataSource(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('config: $config')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, enabled, sortOrder, config);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataSource &&
          other.id == this.id &&
          other.name == this.name &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder &&
          other.config == this.config);
}

class DataSourcesCompanion extends UpdateCompanion<DataSource> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  final Value<DataSourceConfig> config;
  final Value<int> rowid;
  const DataSourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.config = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DataSourcesCompanion.insert({
    required String id,
    required String name,
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DataSourceConfig config,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       config = Value(config);
  static Insertable<DataSource> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
    Expression<String>? config,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (config != null) 'config': config,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DataSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? enabled,
    Value<int>? sortOrder,
    Value<DataSourceConfig>? config,
    Value<int>? rowid,
  }) {
    return DataSourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
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
          ..write('sortOrder: $sortOrder, ')
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
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
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

class $InstalledPluginsTable extends InstalledPlugins
    with TableInfo<$InstalledPluginsTable, InstalledPluginsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstalledPluginsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _scriptContentMeta = const VerificationMeta(
    'scriptContent',
  );
  @override
  late final GeneratedColumn<String> scriptContent = GeneratedColumn<String>(
    'script_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestJsonMeta = const VerificationMeta(
    'manifestJson',
  );
  @override
  late final GeneratedColumn<String> manifestJson = GeneratedColumn<String>(
    'manifest_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
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
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    scriptContent,
    manifestJson,
    sourceUrl,
    enabled,
    installedAt,
    version,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installed_plugins';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstalledPluginsRow> instance, {
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
    if (data.containsKey('script_content')) {
      context.handle(
        _scriptContentMeta,
        scriptContent.isAcceptableOrUnknown(
          data['script_content']!,
          _scriptContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scriptContentMeta);
    }
    if (data.containsKey('manifest_json')) {
      context.handle(
        _manifestJsonMeta,
        manifestJson.isAcceptableOrUnknown(
          data['manifest_json']!,
          _manifestJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestJsonMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstalledPluginsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstalledPluginsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      scriptContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script_content'],
      )!,
      manifestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_json'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $InstalledPluginsTable createAlias(String alias) {
    return $InstalledPluginsTable(attachedDatabase, alias);
  }
}

class InstalledPluginsRow extends DataClass
    implements Insertable<InstalledPluginsRow> {
  /// 插件唯一 id（来自 manifest 的 @id，主键）
  final String id;

  /// 展示名称
  final String name;

  /// 完整 JS 源码（本地持久化）
  final String scriptContent;

  /// 解析出的 manifest（JSON 字符串）
  final String manifestJson;

  /// 安装来源 URL（用于"检查更新"时重新拉取比对版本）
  final String sourceUrl;

  /// 是否启用（关闭后不参与信息流）
  final bool enabled;

  /// 安装时间
  final DateTime installedAt;

  /// 版本号
  final String version;

  /// 信息流顶部 Tab 的排序序号（越小越靠前）。
  ///
  /// 含义同 DataSources.sortOrder：插件和数据源共用一套全局编号，
  /// 所以"插件 Tab 排在数据源 Tab 前面"这种交错顺序也能被正确还原。
  final int sortOrder;
  const InstalledPluginsRow({
    required this.id,
    required this.name,
    required this.scriptContent,
    required this.manifestJson,
    required this.sourceUrl,
    required this.enabled,
    required this.installedAt,
    required this.version,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['script_content'] = Variable<String>(scriptContent);
    map['manifest_json'] = Variable<String>(manifestJson);
    map['source_url'] = Variable<String>(sourceUrl);
    map['enabled'] = Variable<bool>(enabled);
    map['installed_at'] = Variable<DateTime>(installedAt);
    map['version'] = Variable<String>(version);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  InstalledPluginsCompanion toCompanion(bool nullToAbsent) {
    return InstalledPluginsCompanion(
      id: Value(id),
      name: Value(name),
      scriptContent: Value(scriptContent),
      manifestJson: Value(manifestJson),
      sourceUrl: Value(sourceUrl),
      enabled: Value(enabled),
      installedAt: Value(installedAt),
      version: Value(version),
      sortOrder: Value(sortOrder),
    );
  }

  factory InstalledPluginsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstalledPluginsRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      scriptContent: serializer.fromJson<String>(json['scriptContent']),
      manifestJson: serializer.fromJson<String>(json['manifestJson']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
      version: serializer.fromJson<String>(json['version']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'scriptContent': serializer.toJson<String>(scriptContent),
      'manifestJson': serializer.toJson<String>(manifestJson),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'enabled': serializer.toJson<bool>(enabled),
      'installedAt': serializer.toJson<DateTime>(installedAt),
      'version': serializer.toJson<String>(version),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  InstalledPluginsRow copyWith({
    String? id,
    String? name,
    String? scriptContent,
    String? manifestJson,
    String? sourceUrl,
    bool? enabled,
    DateTime? installedAt,
    String? version,
    int? sortOrder,
  }) => InstalledPluginsRow(
    id: id ?? this.id,
    name: name ?? this.name,
    scriptContent: scriptContent ?? this.scriptContent,
    manifestJson: manifestJson ?? this.manifestJson,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    enabled: enabled ?? this.enabled,
    installedAt: installedAt ?? this.installedAt,
    version: version ?? this.version,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  InstalledPluginsRow copyWithCompanion(InstalledPluginsCompanion data) {
    return InstalledPluginsRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      scriptContent: data.scriptContent.present
          ? data.scriptContent.value
          : this.scriptContent,
      manifestJson: data.manifestJson.present
          ? data.manifestJson.value
          : this.manifestJson,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
      version: data.version.present ? data.version.value : this.version,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstalledPluginsRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('scriptContent: $scriptContent, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('version: $version, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    scriptContent,
    manifestJson,
    sourceUrl,
    enabled,
    installedAt,
    version,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstalledPluginsRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.scriptContent == this.scriptContent &&
          other.manifestJson == this.manifestJson &&
          other.sourceUrl == this.sourceUrl &&
          other.enabled == this.enabled &&
          other.installedAt == this.installedAt &&
          other.version == this.version &&
          other.sortOrder == this.sortOrder);
}

class InstalledPluginsCompanion extends UpdateCompanion<InstalledPluginsRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> scriptContent;
  final Value<String> manifestJson;
  final Value<String> sourceUrl;
  final Value<bool> enabled;
  final Value<DateTime> installedAt;
  final Value<String> version;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const InstalledPluginsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.scriptContent = const Value.absent(),
    this.manifestJson = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.enabled = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstalledPluginsCompanion.insert({
    required String id,
    required String name,
    required String scriptContent,
    required String manifestJson,
    required String sourceUrl,
    this.enabled = const Value.absent(),
    required DateTime installedAt,
    required String version,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       scriptContent = Value(scriptContent),
       manifestJson = Value(manifestJson),
       sourceUrl = Value(sourceUrl),
       installedAt = Value(installedAt),
       version = Value(version);
  static Insertable<InstalledPluginsRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? scriptContent,
    Expression<String>? manifestJson,
    Expression<String>? sourceUrl,
    Expression<bool>? enabled,
    Expression<DateTime>? installedAt,
    Expression<String>? version,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (scriptContent != null) 'script_content': scriptContent,
      if (manifestJson != null) 'manifest_json': manifestJson,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (enabled != null) 'enabled': enabled,
      if (installedAt != null) 'installed_at': installedAt,
      if (version != null) 'version': version,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstalledPluginsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? scriptContent,
    Value<String>? manifestJson,
    Value<String>? sourceUrl,
    Value<bool>? enabled,
    Value<DateTime>? installedAt,
    Value<String>? version,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return InstalledPluginsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      scriptContent: scriptContent ?? this.scriptContent,
      manifestJson: manifestJson ?? this.manifestJson,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt ?? this.installedAt,
      version: version ?? this.version,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (scriptContent.present) {
      map['script_content'] = Variable<String>(scriptContent.value);
    }
    if (manifestJson.present) {
      map['manifest_json'] = Variable<String>(manifestJson.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstalledPluginsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('scriptContent: $scriptContent, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('version: $version, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
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
  late final $InstalledPluginsTable installedPlugins = $InstalledPluginsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dataSources,
    blockedKeywords,
    installedPlugins,
  ];
}

typedef $$DataSourcesTableCreateCompanionBuilder =
    DataSourcesCompanion Function({
      required String id,
      required String name,
      Value<bool> enabled,
      Value<int> sortOrder,
      required DataSourceConfig config,
      Value<int> rowid,
    });
typedef $$DataSourcesTableUpdateCompanionBuilder =
    DataSourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<bool> enabled,
      Value<int> sortOrder,
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

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
          createFilteringComposer: () =>
              $$DataSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DataSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DataSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DataSourceConfig> config = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DataSourcesCompanion(
                id: id,
                name: name,
                enabled: enabled,
                sortOrder: sortOrder,
                config: config,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DataSourceConfig config,
                Value<int> rowid = const Value.absent(),
              }) => DataSourcesCompanion.insert(
                id: id,
                name: name,
                enabled: enabled,
                sortOrder: sortOrder,
                config: config,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
          createFilteringComposer: () =>
              $$BlockedKeywordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlockedKeywordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlockedKeywordsTableAnnotationComposer($db: db, $table: table),
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
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
typedef $$InstalledPluginsTableCreateCompanionBuilder =
    InstalledPluginsCompanion Function({
      required String id,
      required String name,
      required String scriptContent,
      required String manifestJson,
      required String sourceUrl,
      Value<bool> enabled,
      required DateTime installedAt,
      required String version,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$InstalledPluginsTableUpdateCompanionBuilder =
    InstalledPluginsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> scriptContent,
      Value<String> manifestJson,
      Value<String> sourceUrl,
      Value<bool> enabled,
      Value<DateTime> installedAt,
      Value<String> version,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$InstalledPluginsTableFilterComposer
    extends Composer<_$AppDatabase, $InstalledPluginsTable> {
  $$InstalledPluginsTableFilterComposer({
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

  ColumnFilters<String> get scriptContent => $composableBuilder(
    column: $table.scriptContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstalledPluginsTableOrderingComposer
    extends Composer<_$AppDatabase, $InstalledPluginsTable> {
  $$InstalledPluginsTableOrderingComposer({
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

  ColumnOrderings<String> get scriptContent => $composableBuilder(
    column: $table.scriptContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstalledPluginsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstalledPluginsTable> {
  $$InstalledPluginsTableAnnotationComposer({
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

  GeneratedColumn<String> get scriptContent => $composableBuilder(
    column: $table.scriptContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$InstalledPluginsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstalledPluginsTable,
          InstalledPluginsRow,
          $$InstalledPluginsTableFilterComposer,
          $$InstalledPluginsTableOrderingComposer,
          $$InstalledPluginsTableAnnotationComposer,
          $$InstalledPluginsTableCreateCompanionBuilder,
          $$InstalledPluginsTableUpdateCompanionBuilder,
          (
            InstalledPluginsRow,
            BaseReferences<
              _$AppDatabase,
              $InstalledPluginsTable,
              InstalledPluginsRow
            >,
          ),
          InstalledPluginsRow,
          PrefetchHooks Function()
        > {
  $$InstalledPluginsTableTableManager(
    _$AppDatabase db,
    $InstalledPluginsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstalledPluginsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstalledPluginsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstalledPluginsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> scriptContent = const Value.absent(),
                Value<String> manifestJson = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstalledPluginsCompanion(
                id: id,
                name: name,
                scriptContent: scriptContent,
                manifestJson: manifestJson,
                sourceUrl: sourceUrl,
                enabled: enabled,
                installedAt: installedAt,
                version: version,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String scriptContent,
                required String manifestJson,
                required String sourceUrl,
                Value<bool> enabled = const Value.absent(),
                required DateTime installedAt,
                required String version,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstalledPluginsCompanion.insert(
                id: id,
                name: name,
                scriptContent: scriptContent,
                manifestJson: manifestJson,
                sourceUrl: sourceUrl,
                enabled: enabled,
                installedAt: installedAt,
                version: version,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstalledPluginsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstalledPluginsTable,
      InstalledPluginsRow,
      $$InstalledPluginsTableFilterComposer,
      $$InstalledPluginsTableOrderingComposer,
      $$InstalledPluginsTableAnnotationComposer,
      $$InstalledPluginsTableCreateCompanionBuilder,
      $$InstalledPluginsTableUpdateCompanionBuilder,
      (
        InstalledPluginsRow,
        BaseReferences<
          _$AppDatabase,
          $InstalledPluginsTable,
          InstalledPluginsRow
        >,
      ),
      InstalledPluginsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DataSourcesTableTableManager get dataSources =>
      $$DataSourcesTableTableManager(_db, _db.dataSources);
  $$BlockedKeywordsTableTableManager get blockedKeywords =>
      $$BlockedKeywordsTableTableManager(_db, _db.blockedKeywords);
  $$InstalledPluginsTableTableManager get installedPlugins =>
      $$InstalledPluginsTableTableManager(_db, _db.installedPlugins);
}
