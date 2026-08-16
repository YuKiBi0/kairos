// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalTasksTable extends LocalTasks
    with TableInfo<$LocalTasksTable, LocalTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quadrantMeta = const VerificationMeta(
    'quadrant',
  );
  @override
  late final GeneratedColumn<int> quadrant = GeneratedColumn<int>(
    'quadrant',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtUtcMeta = const VerificationMeta(
    'dueAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> dueAtUtc = GeneratedColumn<DateTime>(
    'due_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _depthMeta = const VerificationMeta('depth');
  @override
  late final GeneratedColumn<int> depth = GeneratedColumn<int>(
    'depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checklistGroupIdMeta = const VerificationMeta(
    'checklistGroupId',
  );
  @override
  late final GeneratedColumn<String> checklistGroupId = GeneratedColumn<String>(
    'checklist_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAtUtc = GeneratedColumn<DateTime>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtUtcMeta = const VerificationMeta(
    'completedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> completedAtUtc =
      GeneratedColumn<DateTime>(
        'completed_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(true),
  );
  static const VerificationMeta _updatedByDeviceIdMeta = const VerificationMeta(
    'updatedByDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedByDeviceId =
      GeneratedColumn<String>(
        'updated_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    quadrant,
    status,
    dueAtUtc,
    parentId,
    depth,
    sortOrder,
    projectId,
    checklistGroupId,
    version,
    deletedAtUtc,
    createdAtUtc,
    updatedAtUtc,
    completedAtUtc,
    dirty,
    updatedByDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('quadrant')) {
      context.handle(
        _quadrantMeta,
        quadrant.isAcceptableOrUnknown(data['quadrant']!, _quadrantMeta),
      );
    } else if (isInserting) {
      context.missing(_quadrantMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('due_at_utc')) {
      context.handle(
        _dueAtUtcMeta,
        dueAtUtc.isAcceptableOrUnknown(data['due_at_utc']!, _dueAtUtcMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('depth')) {
      context.handle(
        _depthMeta,
        depth.isAcceptableOrUnknown(data['depth']!, _depthMeta),
      );
    } else if (isInserting) {
      context.missing(_depthMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('checklist_group_id')) {
      context.handle(
        _checklistGroupIdMeta,
        checklistGroupId.isAcceptableOrUnknown(
          data['checklist_group_id']!,
          _checklistGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('completed_at_utc')) {
      context.handle(
        _completedAtUtcMeta,
        completedAtUtc.isAcceptableOrUnknown(
          data['completed_at_utc']!,
          _completedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('updated_by_device_id')) {
      context.handle(
        _updatedByDeviceIdMeta,
        updatedByDeviceId.isAcceptableOrUnknown(
          data['updated_by_device_id']!,
          _updatedByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedByDeviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      quadrant: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quadrant'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      dueAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at_utc'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      depth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}depth'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      checklistGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checklist_group_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      completedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at_utc'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      updatedByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by_device_id'],
      )!,
    );
  }

  @override
  $LocalTasksTable createAlias(String alias) {
    return $LocalTasksTable(attachedDatabase, alias);
  }
}

class LocalTask extends DataClass implements Insertable<LocalTask> {
  final String id;
  final String title;
  final String? description;
  final int quadrant;
  final int status;
  final DateTime? dueAtUtc;
  final String? parentId;
  final int depth;
  final int sortOrder;
  final String? projectId;
  final String? checklistGroupId;
  final int version;
  final DateTime? deletedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? completedAtUtc;
  final bool dirty;
  final String updatedByDeviceId;
  const LocalTask({
    required this.id,
    required this.title,
    this.description,
    required this.quadrant,
    required this.status,
    this.dueAtUtc,
    this.parentId,
    required this.depth,
    required this.sortOrder,
    this.projectId,
    this.checklistGroupId,
    required this.version,
    this.deletedAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.completedAtUtc,
    required this.dirty,
    required this.updatedByDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['quadrant'] = Variable<int>(quadrant);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || dueAtUtc != null) {
      map['due_at_utc'] = Variable<DateTime>(dueAtUtc);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['depth'] = Variable<int>(depth);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || checklistGroupId != null) {
      map['checklist_group_id'] = Variable<String>(checklistGroupId);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    if (!nullToAbsent || completedAtUtc != null) {
      map['completed_at_utc'] = Variable<DateTime>(completedAtUtc);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['updated_by_device_id'] = Variable<String>(updatedByDeviceId);
    return map;
  }

  LocalTasksCompanion toCompanion(bool nullToAbsent) {
    return LocalTasksCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      quadrant: Value(quadrant),
      status: Value(status),
      dueAtUtc: dueAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAtUtc),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      depth: Value(depth),
      sortOrder: Value(sortOrder),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      checklistGroupId: checklistGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(checklistGroupId),
      version: Value(version),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      completedAtUtc: completedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtUtc),
      dirty: Value(dirty),
      updatedByDeviceId: Value(updatedByDeviceId),
    );
  }

  factory LocalTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTask(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      quadrant: serializer.fromJson<int>(json['quadrant']),
      status: serializer.fromJson<int>(json['status']),
      dueAtUtc: serializer.fromJson<DateTime?>(json['dueAtUtc']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      depth: serializer.fromJson<int>(json['depth']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      checklistGroupId: serializer.fromJson<String?>(json['checklistGroupId']),
      version: serializer.fromJson<int>(json['version']),
      deletedAtUtc: serializer.fromJson<DateTime?>(json['deletedAtUtc']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
      completedAtUtc: serializer.fromJson<DateTime?>(json['completedAtUtc']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      updatedByDeviceId: serializer.fromJson<String>(json['updatedByDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'quadrant': serializer.toJson<int>(quadrant),
      'status': serializer.toJson<int>(status),
      'dueAtUtc': serializer.toJson<DateTime?>(dueAtUtc),
      'parentId': serializer.toJson<String?>(parentId),
      'depth': serializer.toJson<int>(depth),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'projectId': serializer.toJson<String?>(projectId),
      'checklistGroupId': serializer.toJson<String?>(checklistGroupId),
      'version': serializer.toJson<int>(version),
      'deletedAtUtc': serializer.toJson<DateTime?>(deletedAtUtc),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
      'completedAtUtc': serializer.toJson<DateTime?>(completedAtUtc),
      'dirty': serializer.toJson<bool>(dirty),
      'updatedByDeviceId': serializer.toJson<String>(updatedByDeviceId),
    };
  }

  LocalTask copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    int? quadrant,
    int? status,
    Value<DateTime?> dueAtUtc = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    int? depth,
    int? sortOrder,
    Value<String?> projectId = const Value.absent(),
    Value<String?> checklistGroupId = const Value.absent(),
    int? version,
    Value<DateTime?> deletedAtUtc = const Value.absent(),
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    Value<DateTime?> completedAtUtc = const Value.absent(),
    bool? dirty,
    String? updatedByDeviceId,
  }) => LocalTask(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    quadrant: quadrant ?? this.quadrant,
    status: status ?? this.status,
    dueAtUtc: dueAtUtc.present ? dueAtUtc.value : this.dueAtUtc,
    parentId: parentId.present ? parentId.value : this.parentId,
    depth: depth ?? this.depth,
    sortOrder: sortOrder ?? this.sortOrder,
    projectId: projectId.present ? projectId.value : this.projectId,
    checklistGroupId: checklistGroupId.present
        ? checklistGroupId.value
        : this.checklistGroupId,
    version: version ?? this.version,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    completedAtUtc: completedAtUtc.present
        ? completedAtUtc.value
        : this.completedAtUtc,
    dirty: dirty ?? this.dirty,
    updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
  );
  LocalTask copyWithCompanion(LocalTasksCompanion data) {
    return LocalTask(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      quadrant: data.quadrant.present ? data.quadrant.value : this.quadrant,
      status: data.status.present ? data.status.value : this.status,
      dueAtUtc: data.dueAtUtc.present ? data.dueAtUtc.value : this.dueAtUtc,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      depth: data.depth.present ? data.depth.value : this.depth,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      checklistGroupId: data.checklistGroupId.present
          ? data.checklistGroupId.value
          : this.checklistGroupId,
      version: data.version.present ? data.version.value : this.version,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      completedAtUtc: data.completedAtUtc.present
          ? data.completedAtUtc.value
          : this.completedAtUtc,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      updatedByDeviceId: data.updatedByDeviceId.present
          ? data.updatedByDeviceId.value
          : this.updatedByDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTask(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('quadrant: $quadrant, ')
          ..write('status: $status, ')
          ..write('dueAtUtc: $dueAtUtc, ')
          ..write('parentId: $parentId, ')
          ..write('depth: $depth, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('projectId: $projectId, ')
          ..write('checklistGroupId: $checklistGroupId, ')
          ..write('version: $version, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('dirty: $dirty, ')
          ..write('updatedByDeviceId: $updatedByDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    quadrant,
    status,
    dueAtUtc,
    parentId,
    depth,
    sortOrder,
    projectId,
    checklistGroupId,
    version,
    deletedAtUtc,
    createdAtUtc,
    updatedAtUtc,
    completedAtUtc,
    dirty,
    updatedByDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTask &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.quadrant == this.quadrant &&
          other.status == this.status &&
          other.dueAtUtc == this.dueAtUtc &&
          other.parentId == this.parentId &&
          other.depth == this.depth &&
          other.sortOrder == this.sortOrder &&
          other.projectId == this.projectId &&
          other.checklistGroupId == this.checklistGroupId &&
          other.version == this.version &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.completedAtUtc == this.completedAtUtc &&
          other.dirty == this.dirty &&
          other.updatedByDeviceId == this.updatedByDeviceId);
}

class LocalTasksCompanion extends UpdateCompanion<LocalTask> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<int> quadrant;
  final Value<int> status;
  final Value<DateTime?> dueAtUtc;
  final Value<String?> parentId;
  final Value<int> depth;
  final Value<int> sortOrder;
  final Value<String?> projectId;
  final Value<String?> checklistGroupId;
  final Value<int> version;
  final Value<DateTime?> deletedAtUtc;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<DateTime?> completedAtUtc;
  final Value<bool> dirty;
  final Value<String> updatedByDeviceId;
  final Value<int> rowid;
  const LocalTasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.quadrant = const Value.absent(),
    this.status = const Value.absent(),
    this.dueAtUtc = const Value.absent(),
    this.parentId = const Value.absent(),
    this.depth = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.projectId = const Value.absent(),
    this.checklistGroupId = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.completedAtUtc = const Value.absent(),
    this.dirty = const Value.absent(),
    this.updatedByDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTasksCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required int quadrant,
    required int status,
    this.dueAtUtc = const Value.absent(),
    this.parentId = const Value.absent(),
    required int depth,
    required int sortOrder,
    this.projectId = const Value.absent(),
    this.checklistGroupId = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.completedAtUtc = const Value.absent(),
    this.dirty = const Value.absent(),
    required String updatedByDeviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       quadrant = Value(quadrant),
       status = Value(status),
       depth = Value(depth),
       sortOrder = Value(sortOrder),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc),
       updatedByDeviceId = Value(updatedByDeviceId);
  static Insertable<LocalTask> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? quadrant,
    Expression<int>? status,
    Expression<DateTime>? dueAtUtc,
    Expression<String>? parentId,
    Expression<int>? depth,
    Expression<int>? sortOrder,
    Expression<String>? projectId,
    Expression<String>? checklistGroupId,
    Expression<int>? version,
    Expression<DateTime>? deletedAtUtc,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<DateTime>? completedAtUtc,
    Expression<bool>? dirty,
    Expression<String>? updatedByDeviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (quadrant != null) 'quadrant': quadrant,
      if (status != null) 'status': status,
      if (dueAtUtc != null) 'due_at_utc': dueAtUtc,
      if (parentId != null) 'parent_id': parentId,
      if (depth != null) 'depth': depth,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (projectId != null) 'project_id': projectId,
      if (checklistGroupId != null) 'checklist_group_id': checklistGroupId,
      if (version != null) 'version': version,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (completedAtUtc != null) 'completed_at_utc': completedAtUtc,
      if (dirty != null) 'dirty': dirty,
      if (updatedByDeviceId != null) 'updated_by_device_id': updatedByDeviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<int>? quadrant,
    Value<int>? status,
    Value<DateTime?>? dueAtUtc,
    Value<String?>? parentId,
    Value<int>? depth,
    Value<int>? sortOrder,
    Value<String?>? projectId,
    Value<String?>? checklistGroupId,
    Value<int>? version,
    Value<DateTime?>? deletedAtUtc,
    Value<DateTime>? createdAtUtc,
    Value<DateTime>? updatedAtUtc,
    Value<DateTime?>? completedAtUtc,
    Value<bool>? dirty,
    Value<String>? updatedByDeviceId,
    Value<int>? rowid,
  }) {
    return LocalTasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      quadrant: quadrant ?? this.quadrant,
      status: status ?? this.status,
      dueAtUtc: dueAtUtc ?? this.dueAtUtc,
      parentId: parentId ?? this.parentId,
      depth: depth ?? this.depth,
      sortOrder: sortOrder ?? this.sortOrder,
      projectId: projectId ?? this.projectId,
      checklistGroupId: checklistGroupId ?? this.checklistGroupId,
      version: version ?? this.version,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      completedAtUtc: completedAtUtc ?? this.completedAtUtc,
      dirty: dirty ?? this.dirty,
      updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (quadrant.present) {
      map['quadrant'] = Variable<int>(quadrant.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (dueAtUtc.present) {
      map['due_at_utc'] = Variable<DateTime>(dueAtUtc.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (depth.present) {
      map['depth'] = Variable<int>(depth.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (checklistGroupId.present) {
      map['checklist_group_id'] = Variable<String>(checklistGroupId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (completedAtUtc.present) {
      map['completed_at_utc'] = Variable<DateTime>(completedAtUtc.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (updatedByDeviceId.present) {
      map['updated_by_device_id'] = Variable<String>(updatedByDeviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('quadrant: $quadrant, ')
          ..write('status: $status, ')
          ..write('dueAtUtc: $dueAtUtc, ')
          ..write('parentId: $parentId, ')
          ..write('depth: $depth, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('projectId: $projectId, ')
          ..write('checklistGroupId: $checklistGroupId, ')
          ..write('version: $version, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('dirty: $dirty, ')
          ..write('updatedByDeviceId: $updatedByDeviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBlockersTable extends LocalBlockers
    with TableInfo<$LocalBlockersTable, LocalBlocker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBlockersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedMeta = const VerificationMeta(
    'resolved',
  );
  @override
  late final GeneratedColumn<bool> resolved = GeneratedColumn<bool>(
    'resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("resolved" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _resolvedAtUtcMeta = const VerificationMeta(
    'resolvedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAtUtc =
      GeneratedColumn<DateTime>(
        'resolved_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAtUtc = GeneratedColumn<DateTime>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    body,
    resolved,
    resolvedAtUtc,
    version,
    deletedAtUtc,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_blockers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBlocker> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('resolved')) {
      context.handle(
        _resolvedMeta,
        resolved.isAcceptableOrUnknown(data['resolved']!, _resolvedMeta),
      );
    }
    if (data.containsKey('resolved_at_utc')) {
      context.handle(
        _resolvedAtUtcMeta,
        resolvedAtUtc.isAcceptableOrUnknown(
          data['resolved_at_utc']!,
          _resolvedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBlocker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBlocker(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      resolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}resolved'],
      )!,
      resolvedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at_utc'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $LocalBlockersTable createAlias(String alias) {
    return $LocalBlockersTable(attachedDatabase, alias);
  }
}

class LocalBlocker extends DataClass implements Insertable<LocalBlocker> {
  final String id;
  final String taskId;
  final String body;
  final bool resolved;
  final DateTime? resolvedAtUtc;
  final int version;
  final DateTime? deletedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const LocalBlocker({
    required this.id,
    required this.taskId,
    required this.body,
    required this.resolved,
    this.resolvedAtUtc,
    required this.version,
    this.deletedAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['body'] = Variable<String>(body);
    map['resolved'] = Variable<bool>(resolved);
    if (!nullToAbsent || resolvedAtUtc != null) {
      map['resolved_at_utc'] = Variable<DateTime>(resolvedAtUtc);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  LocalBlockersCompanion toCompanion(bool nullToAbsent) {
    return LocalBlockersCompanion(
      id: Value(id),
      taskId: Value(taskId),
      body: Value(body),
      resolved: Value(resolved),
      resolvedAtUtc: resolvedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAtUtc),
      version: Value(version),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory LocalBlocker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBlocker(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      body: serializer.fromJson<String>(json['body']),
      resolved: serializer.fromJson<bool>(json['resolved']),
      resolvedAtUtc: serializer.fromJson<DateTime?>(json['resolvedAtUtc']),
      version: serializer.fromJson<int>(json['version']),
      deletedAtUtc: serializer.fromJson<DateTime?>(json['deletedAtUtc']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'body': serializer.toJson<String>(body),
      'resolved': serializer.toJson<bool>(resolved),
      'resolvedAtUtc': serializer.toJson<DateTime?>(resolvedAtUtc),
      'version': serializer.toJson<int>(version),
      'deletedAtUtc': serializer.toJson<DateTime?>(deletedAtUtc),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  LocalBlocker copyWith({
    String? id,
    String? taskId,
    String? body,
    bool? resolved,
    Value<DateTime?> resolvedAtUtc = const Value.absent(),
    int? version,
    Value<DateTime?> deletedAtUtc = const Value.absent(),
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => LocalBlocker(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    body: body ?? this.body,
    resolved: resolved ?? this.resolved,
    resolvedAtUtc: resolvedAtUtc.present
        ? resolvedAtUtc.value
        : this.resolvedAtUtc,
    version: version ?? this.version,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  LocalBlocker copyWithCompanion(LocalBlockersCompanion data) {
    return LocalBlocker(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      body: data.body.present ? data.body.value : this.body,
      resolved: data.resolved.present ? data.resolved.value : this.resolved,
      resolvedAtUtc: data.resolvedAtUtc.present
          ? data.resolvedAtUtc.value
          : this.resolvedAtUtc,
      version: data.version.present ? data.version.value : this.version,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlocker(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('body: $body, ')
          ..write('resolved: $resolved, ')
          ..write('resolvedAtUtc: $resolvedAtUtc, ')
          ..write('version: $version, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    body,
    resolved,
    resolvedAtUtc,
    version,
    deletedAtUtc,
    createdAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBlocker &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.body == this.body &&
          other.resolved == this.resolved &&
          other.resolvedAtUtc == this.resolvedAtUtc &&
          other.version == this.version &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class LocalBlockersCompanion extends UpdateCompanion<LocalBlocker> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> body;
  final Value<bool> resolved;
  final Value<DateTime?> resolvedAtUtc;
  final Value<int> version;
  final Value<DateTime?> deletedAtUtc;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const LocalBlockersCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.body = const Value.absent(),
    this.resolved = const Value.absent(),
    this.resolvedAtUtc = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBlockersCompanion.insert({
    required String id,
    required String taskId,
    required String body,
    this.resolved = const Value.absent(),
    this.resolvedAtUtc = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       body = Value(body),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<LocalBlocker> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? body,
    Expression<bool>? resolved,
    Expression<DateTime>? resolvedAtUtc,
    Expression<int>? version,
    Expression<DateTime>? deletedAtUtc,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (body != null) 'body': body,
      if (resolved != null) 'resolved': resolved,
      if (resolvedAtUtc != null) 'resolved_at_utc': resolvedAtUtc,
      if (version != null) 'version': version,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBlockersCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? body,
    Value<bool>? resolved,
    Value<DateTime?>? resolvedAtUtc,
    Value<int>? version,
    Value<DateTime?>? deletedAtUtc,
    Value<DateTime>? createdAtUtc,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return LocalBlockersCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      body: body ?? this.body,
      resolved: resolved ?? this.resolved,
      resolvedAtUtc: resolvedAtUtc ?? this.resolvedAtUtc,
      version: version ?? this.version,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (resolved.present) {
      map['resolved'] = Variable<bool>(resolved.value);
    }
    if (resolvedAtUtc.present) {
      map['resolved_at_utc'] = Variable<DateTime>(resolvedAtUtc.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlockersCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('body: $body, ')
          ..write('resolved: $resolved, ')
          ..write('resolvedAtUtc: $resolvedAtUtc, ')
          ..write('version: $version, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTagsTable extends LocalTags
    with TableInfo<$LocalTagsTable, LocalTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTagsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _colorTokenMeta = const VerificationMeta(
    'colorToken',
  );
  @override
  late final GeneratedColumn<String> colorToken = GeneratedColumn<String>(
    'color_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorToken,
    archived,
    version,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTag> instance, {
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
    if (data.containsKey('color_token')) {
      context.handle(
        _colorTokenMeta,
        colorToken.isAcceptableOrUnknown(data['color_token']!, _colorTokenMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  LocalTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_token'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $LocalTagsTable createAlias(String alias) {
    return $LocalTagsTable(attachedDatabase, alias);
  }
}

class LocalTag extends DataClass implements Insertable<LocalTag> {
  final String id;
  final String name;
  final String? colorToken;
  final bool archived;
  final int version;
  final DateTime updatedAtUtc;
  const LocalTag({
    required this.id,
    required this.name,
    this.colorToken,
    required this.archived,
    required this.version,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || colorToken != null) {
      map['color_token'] = Variable<String>(colorToken);
    }
    map['archived'] = Variable<bool>(archived);
    map['version'] = Variable<int>(version);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  LocalTagsCompanion toCompanion(bool nullToAbsent) {
    return LocalTagsCompanion(
      id: Value(id),
      name: Value(name),
      colorToken: colorToken == null && nullToAbsent
          ? const Value.absent()
          : Value(colorToken),
      archived: Value(archived),
      version: Value(version),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory LocalTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorToken: serializer.fromJson<String?>(json['colorToken']),
      archived: serializer.fromJson<bool>(json['archived']),
      version: serializer.fromJson<int>(json['version']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorToken': serializer.toJson<String?>(colorToken),
      'archived': serializer.toJson<bool>(archived),
      'version': serializer.toJson<int>(version),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  LocalTag copyWith({
    String? id,
    String? name,
    Value<String?> colorToken = const Value.absent(),
    bool? archived,
    int? version,
    DateTime? updatedAtUtc,
  }) => LocalTag(
    id: id ?? this.id,
    name: name ?? this.name,
    colorToken: colorToken.present ? colorToken.value : this.colorToken,
    archived: archived ?? this.archived,
    version: version ?? this.version,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  LocalTag copyWithCompanion(LocalTagsCompanion data) {
    return LocalTag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorToken: data.colorToken.present
          ? data.colorToken.value
          : this.colorToken,
      archived: data.archived.present ? data.archived.value : this.archived,
      version: data.version.present ? data.version.value : this.version,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorToken: $colorToken, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, colorToken, archived, version, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTag &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorToken == this.colorToken &&
          other.archived == this.archived &&
          other.version == this.version &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class LocalTagsCompanion extends UpdateCompanion<LocalTag> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> colorToken;
  final Value<bool> archived;
  final Value<int> version;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const LocalTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorToken = const Value.absent(),
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTagsCompanion.insert({
    required String id,
    required String name,
    this.colorToken = const Value.absent(),
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<LocalTag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? colorToken,
    Expression<bool>? archived,
    Expression<int>? version,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorToken != null) 'color_token': colorToken,
      if (archived != null) 'archived': archived,
      if (version != null) 'version': version,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? colorToken,
    Value<bool>? archived,
    Value<int>? version,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return LocalTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorToken: colorToken ?? this.colorToken,
      archived: archived ?? this.archived,
      version: version ?? this.version,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
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
    if (colorToken.present) {
      map['color_token'] = Variable<String>(colorToken.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorToken: $colorToken, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProjectsTable extends LocalProjects
    with TableInfo<$LocalProjectsTable, LocalProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProjectsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    archived,
    version,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProject> instance, {
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
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $LocalProjectsTable createAlias(String alias) {
    return $LocalProjectsTable(attachedDatabase, alias);
  }
}

class LocalProject extends DataClass implements Insertable<LocalProject> {
  final String id;
  final String name;
  final bool archived;
  final int version;
  final DateTime updatedAtUtc;
  const LocalProject({
    required this.id,
    required this.name,
    required this.archived,
    required this.version,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['archived'] = Variable<bool>(archived);
    map['version'] = Variable<int>(version);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  LocalProjectsCompanion toCompanion(bool nullToAbsent) {
    return LocalProjectsCompanion(
      id: Value(id),
      name: Value(name),
      archived: Value(archived),
      version: Value(version),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory LocalProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProject(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      archived: serializer.fromJson<bool>(json['archived']),
      version: serializer.fromJson<int>(json['version']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'archived': serializer.toJson<bool>(archived),
      'version': serializer.toJson<int>(version),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  LocalProject copyWith({
    String? id,
    String? name,
    bool? archived,
    int? version,
    DateTime? updatedAtUtc,
  }) => LocalProject(
    id: id ?? this.id,
    name: name ?? this.name,
    archived: archived ?? this.archived,
    version: version ?? this.version,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  LocalProject copyWithCompanion(LocalProjectsCompanion data) {
    return LocalProject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      archived: data.archived.present ? data.archived.value : this.archived,
      version: data.version.present ? data.version.value : this.version,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, archived, version, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProject &&
          other.id == this.id &&
          other.name == this.name &&
          other.archived == this.archived &&
          other.version == this.version &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class LocalProjectsCompanion extends UpdateCompanion<LocalProject> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> archived;
  final Value<int> version;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const LocalProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProjectsCompanion.insert({
    required String id,
    required String name,
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<LocalProject> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? archived,
    Expression<int>? version,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (archived != null) 'archived': archived,
      if (version != null) 'version': version,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? archived,
    Value<int>? version,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return LocalProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      archived: archived ?? this.archived,
      version: version ?? this.version,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
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
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalChecklistGroupsTable extends LocalChecklistGroups
    with TableInfo<$LocalChecklistGroupsTable, LocalChecklistGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalChecklistGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    archived,
    version,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_checklist_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalChecklistGroup> instance, {
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
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalChecklistGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChecklistGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $LocalChecklistGroupsTable createAlias(String alias) {
    return $LocalChecklistGroupsTable(attachedDatabase, alias);
  }
}

class LocalChecklistGroup extends DataClass
    implements Insertable<LocalChecklistGroup> {
  final String id;
  final String name;
  final bool archived;
  final int version;
  final DateTime updatedAtUtc;
  const LocalChecklistGroup({
    required this.id,
    required this.name,
    required this.archived,
    required this.version,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['archived'] = Variable<bool>(archived);
    map['version'] = Variable<int>(version);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  LocalChecklistGroupsCompanion toCompanion(bool nullToAbsent) {
    return LocalChecklistGroupsCompanion(
      id: Value(id),
      name: Value(name),
      archived: Value(archived),
      version: Value(version),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory LocalChecklistGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChecklistGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      archived: serializer.fromJson<bool>(json['archived']),
      version: serializer.fromJson<int>(json['version']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'archived': serializer.toJson<bool>(archived),
      'version': serializer.toJson<int>(version),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  LocalChecklistGroup copyWith({
    String? id,
    String? name,
    bool? archived,
    int? version,
    DateTime? updatedAtUtc,
  }) => LocalChecklistGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    archived: archived ?? this.archived,
    version: version ?? this.version,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  LocalChecklistGroup copyWithCompanion(LocalChecklistGroupsCompanion data) {
    return LocalChecklistGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      archived: data.archived.present ? data.archived.value : this.archived,
      version: data.version.present ? data.version.value : this.version,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChecklistGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, archived, version, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChecklistGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.archived == this.archived &&
          other.version == this.version &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class LocalChecklistGroupsCompanion
    extends UpdateCompanion<LocalChecklistGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> archived;
  final Value<int> version;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const LocalChecklistGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalChecklistGroupsCompanion.insert({
    required String id,
    required String name,
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<LocalChecklistGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? archived,
    Expression<int>? version,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (archived != null) 'archived': archived,
      if (version != null) 'version': version,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalChecklistGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? archived,
    Value<int>? version,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return LocalChecklistGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      archived: archived ?? this.archived,
      version: version ?? this.version,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
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
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalChecklistGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskTagsTable extends TaskTags with TableInfo<$TaskTagsTable, TaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, tagId};
  @override
  TaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTag(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TaskTagsTable createAlias(String alias) {
    return $TaskTagsTable(attachedDatabase, alias);
  }
}

class TaskTag extends DataClass implements Insertable<TaskTag> {
  final String taskId;
  final String tagId;
  const TaskTag({required this.taskId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TaskTagsCompanion(taskId: Value(taskId), tagId: Value(tagId));
  }

  factory TaskTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTag(
      taskId: serializer.fromJson<String>(json['taskId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TaskTag copyWith({String? taskId, String? tagId}) =>
      TaskTag(taskId: taskId ?? this.taskId, tagId: tagId ?? this.tagId);
  TaskTag copyWithCompanion(TaskTagsCompanion data) {
    return TaskTag(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTag(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTag &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId);
}

class TaskTagsCompanion extends UpdateCompanion<TaskTag> {
  final Value<String> taskId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TaskTagsCompanion({
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTagsCompanion.insert({
    required String taskId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       tagId = Value(tagId);
  static Insertable<TaskTag> custom({
    Expression<String>? taskId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTagsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TaskTagsCompanion(
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxOperationsTable extends OutboxOperations
    with TableInfo<$OutboxOperationsTable, OutboxOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _nextAttemptAtUtcMeta = const VerificationMeta(
    'nextAttemptAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAtUtc =
      GeneratedColumn<DateTime>(
        'next_attempt_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    entityType,
    entityId,
    baseVersion,
    payload,
    createdAtUtc,
    attemptCount,
    nextAttemptAtUtc,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseVersionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at_utc')) {
      context.handle(
        _nextAttemptAtUtcMeta,
        nextAttemptAtUtc.isAcceptableOrUnknown(
          data['next_attempt_at_utc']!,
          _nextAttemptAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtUtcMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  OutboxOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxOperation(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at_utc'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxOperationsTable createAlias(String alias) {
    return $OutboxOperationsTable(attachedDatabase, alias);
  }
}

class OutboxOperation extends DataClass implements Insertable<OutboxOperation> {
  final String operationId;
  final String entityType;
  final String entityId;
  final int baseVersion;
  final String payload;
  final DateTime createdAtUtc;
  final int attemptCount;
  final DateTime nextAttemptAtUtc;
  final String? lastError;
  const OutboxOperation({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.baseVersion,
    required this.payload,
    required this.createdAtUtc,
    required this.attemptCount,
    required this.nextAttemptAtUtc,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['base_version'] = Variable<int>(baseVersion);
    map['payload'] = Variable<String>(payload);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['next_attempt_at_utc'] = Variable<DateTime>(nextAttemptAtUtc);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxOperationsCompanion toCompanion(bool nullToAbsent) {
    return OutboxOperationsCompanion(
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      baseVersion: Value(baseVersion),
      payload: Value(payload),
      createdAtUtc: Value(createdAtUtc),
      attemptCount: Value(attemptCount),
      nextAttemptAtUtc: Value(nextAttemptAtUtc),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxOperation(
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAtUtc: serializer.fromJson<DateTime>(json['nextAttemptAtUtc']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'payload': serializer.toJson<String>(payload),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAtUtc': serializer.toJson<DateTime>(nextAttemptAtUtc),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxOperation copyWith({
    String? operationId,
    String? entityType,
    String? entityId,
    int? baseVersion,
    String? payload,
    DateTime? createdAtUtc,
    int? attemptCount,
    DateTime? nextAttemptAtUtc,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxOperation(
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    baseVersion: baseVersion ?? this.baseVersion,
    payload: payload ?? this.payload,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAtUtc: nextAttemptAtUtc ?? this.nextAttemptAtUtc,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxOperation copyWithCompanion(OutboxOperationsCompanion data) {
    return OutboxOperation(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAtUtc: data.nextAttemptAtUtc.present
          ? data.nextAttemptAtUtc.value
          : this.nextAttemptAtUtc,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOperation(')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payload: $payload, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAtUtc: $nextAttemptAtUtc, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    entityType,
    entityId,
    baseVersion,
    payload,
    createdAtUtc,
    attemptCount,
    nextAttemptAtUtc,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxOperation &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.baseVersion == this.baseVersion &&
          other.payload == this.payload &&
          other.createdAtUtc == this.createdAtUtc &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAtUtc == this.nextAttemptAtUtc &&
          other.lastError == this.lastError);
}

class OutboxOperationsCompanion extends UpdateCompanion<OutboxOperation> {
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> baseVersion;
  final Value<String> payload;
  final Value<DateTime> createdAtUtc;
  final Value<int> attemptCount;
  final Value<DateTime> nextAttemptAtUtc;
  final Value<String?> lastError;
  final Value<int> rowid;
  const OutboxOperationsCompanion({
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAtUtc = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxOperationsCompanion.insert({
    required String operationId,
    required String entityType,
    required String entityId,
    required int baseVersion,
    required String payload,
    required DateTime createdAtUtc,
    this.attemptCount = const Value.absent(),
    required DateTime nextAttemptAtUtc,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       baseVersion = Value(baseVersion),
       payload = Value(payload),
       createdAtUtc = Value(createdAtUtc),
       nextAttemptAtUtc = Value(nextAttemptAtUtc);
  static Insertable<OutboxOperation> custom({
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? baseVersion,
    Expression<String>? payload,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAtUtc,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (baseVersion != null) 'base_version': baseVersion,
      if (payload != null) 'payload': payload,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAtUtc != null) 'next_attempt_at_utc': nextAttemptAtUtc,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxOperationsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? baseVersion,
    Value<String>? payload,
    Value<DateTime>? createdAtUtc,
    Value<int>? attemptCount,
    Value<DateTime>? nextAttemptAtUtc,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return OutboxOperationsCompanion(
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      baseVersion: baseVersion ?? this.baseVersion,
      payload: payload ?? this.payload,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAtUtc: nextAttemptAtUtc ?? this.nextAttemptAtUtc,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAtUtc.present) {
      map['next_attempt_at_utc'] = Variable<DateTime>(nextAttemptAtUtc.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOperationsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payload: $payload, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAtUtc: $nextAttemptAtUtc, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(1),
  );
  static const VerificationMeta _serverCursorMeta = const VerificationMeta(
    'serverCursor',
  );
  @override
  late final GeneratedColumn<int> serverCursor = GeneratedColumn<int>(
    'server_cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _lastPullAtUtcMeta = const VerificationMeta(
    'lastPullAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastPullAtUtc =
      GeneratedColumn<DateTime>(
        'last_pull_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastPushAtUtcMeta = const VerificationMeta(
    'lastPushAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastPushAtUtc =
      GeneratedColumn<DateTime>(
        'last_push_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pendingCountMeta = const VerificationMeta(
    'pendingCount',
  );
  @override
  late final GeneratedColumn<int> pendingCount = GeneratedColumn<int>(
    'pending_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverCursor,
    lastPullAtUtc,
    lastPushAtUtc,
    pendingCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_cursor')) {
      context.handle(
        _serverCursorMeta,
        serverCursor.isAcceptableOrUnknown(
          data['server_cursor']!,
          _serverCursorMeta,
        ),
      );
    }
    if (data.containsKey('last_pull_at_utc')) {
      context.handle(
        _lastPullAtUtcMeta,
        lastPullAtUtc.isAcceptableOrUnknown(
          data['last_pull_at_utc']!,
          _lastPullAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_push_at_utc')) {
      context.handle(
        _lastPushAtUtcMeta,
        lastPushAtUtc.isAcceptableOrUnknown(
          data['last_push_at_utc']!,
          _lastPushAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('pending_count')) {
      context.handle(
        _pendingCountMeta,
        pendingCount.isAcceptableOrUnknown(
          data['pending_count']!,
          _pendingCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_cursor'],
      )!,
      lastPullAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pull_at_utc'],
      ),
      lastPushAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_push_at_utc'],
      ),
      pendingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_count'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final int id;
  final int serverCursor;
  final DateTime? lastPullAtUtc;
  final DateTime? lastPushAtUtc;
  final int pendingCount;
  const SyncState({
    required this.id,
    required this.serverCursor,
    this.lastPullAtUtc,
    this.lastPushAtUtc,
    required this.pendingCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_cursor'] = Variable<int>(serverCursor);
    if (!nullToAbsent || lastPullAtUtc != null) {
      map['last_pull_at_utc'] = Variable<DateTime>(lastPullAtUtc);
    }
    if (!nullToAbsent || lastPushAtUtc != null) {
      map['last_push_at_utc'] = Variable<DateTime>(lastPushAtUtc);
    }
    map['pending_count'] = Variable<int>(pendingCount);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      id: Value(id),
      serverCursor: Value(serverCursor),
      lastPullAtUtc: lastPullAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPullAtUtc),
      lastPushAtUtc: lastPushAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushAtUtc),
      pendingCount: Value(pendingCount),
    );
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      id: serializer.fromJson<int>(json['id']),
      serverCursor: serializer.fromJson<int>(json['serverCursor']),
      lastPullAtUtc: serializer.fromJson<DateTime?>(json['lastPullAtUtc']),
      lastPushAtUtc: serializer.fromJson<DateTime?>(json['lastPushAtUtc']),
      pendingCount: serializer.fromJson<int>(json['pendingCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverCursor': serializer.toJson<int>(serverCursor),
      'lastPullAtUtc': serializer.toJson<DateTime?>(lastPullAtUtc),
      'lastPushAtUtc': serializer.toJson<DateTime?>(lastPushAtUtc),
      'pendingCount': serializer.toJson<int>(pendingCount),
    };
  }

  SyncState copyWith({
    int? id,
    int? serverCursor,
    Value<DateTime?> lastPullAtUtc = const Value.absent(),
    Value<DateTime?> lastPushAtUtc = const Value.absent(),
    int? pendingCount,
  }) => SyncState(
    id: id ?? this.id,
    serverCursor: serverCursor ?? this.serverCursor,
    lastPullAtUtc: lastPullAtUtc.present
        ? lastPullAtUtc.value
        : this.lastPullAtUtc,
    lastPushAtUtc: lastPushAtUtc.present
        ? lastPushAtUtc.value
        : this.lastPushAtUtc,
    pendingCount: pendingCount ?? this.pendingCount,
  );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      id: data.id.present ? data.id.value : this.id,
      serverCursor: data.serverCursor.present
          ? data.serverCursor.value
          : this.serverCursor,
      lastPullAtUtc: data.lastPullAtUtc.present
          ? data.lastPullAtUtc.value
          : this.lastPullAtUtc,
      lastPushAtUtc: data.lastPushAtUtc.present
          ? data.lastPushAtUtc.value
          : this.lastPushAtUtc,
      pendingCount: data.pendingCount.present
          ? data.pendingCount.value
          : this.pendingCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('id: $id, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPullAtUtc: $lastPullAtUtc, ')
          ..write('lastPushAtUtc: $lastPushAtUtc, ')
          ..write('pendingCount: $pendingCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverCursor, lastPullAtUtc, lastPushAtUtc, pendingCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.id == this.id &&
          other.serverCursor == this.serverCursor &&
          other.lastPullAtUtc == this.lastPullAtUtc &&
          other.lastPushAtUtc == this.lastPushAtUtc &&
          other.pendingCount == this.pendingCount);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<int> id;
  final Value<int> serverCursor;
  final Value<DateTime?> lastPullAtUtc;
  final Value<DateTime?> lastPushAtUtc;
  final Value<int> pendingCount;
  const SyncStatesCompanion({
    this.id = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPullAtUtc = const Value.absent(),
    this.lastPushAtUtc = const Value.absent(),
    this.pendingCount = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    this.id = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPullAtUtc = const Value.absent(),
    this.lastPushAtUtc = const Value.absent(),
    this.pendingCount = const Value.absent(),
  });
  static Insertable<SyncState> custom({
    Expression<int>? id,
    Expression<int>? serverCursor,
    Expression<DateTime>? lastPullAtUtc,
    Expression<DateTime>? lastPushAtUtc,
    Expression<int>? pendingCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverCursor != null) 'server_cursor': serverCursor,
      if (lastPullAtUtc != null) 'last_pull_at_utc': lastPullAtUtc,
      if (lastPushAtUtc != null) 'last_push_at_utc': lastPushAtUtc,
      if (pendingCount != null) 'pending_count': pendingCount,
    });
  }

  SyncStatesCompanion copyWith({
    Value<int>? id,
    Value<int>? serverCursor,
    Value<DateTime?>? lastPullAtUtc,
    Value<DateTime?>? lastPushAtUtc,
    Value<int>? pendingCount,
  }) {
    return SyncStatesCompanion(
      id: id ?? this.id,
      serverCursor: serverCursor ?? this.serverCursor,
      lastPullAtUtc: lastPullAtUtc ?? this.lastPullAtUtc,
      lastPushAtUtc: lastPushAtUtc ?? this.lastPushAtUtc,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverCursor.present) {
      map['server_cursor'] = Variable<int>(serverCursor.value);
    }
    if (lastPullAtUtc.present) {
      map['last_pull_at_utc'] = Variable<DateTime>(lastPullAtUtc.value);
    }
    if (lastPushAtUtc.present) {
      map['last_push_at_utc'] = Variable<DateTime>(lastPushAtUtc.value);
    }
    if (pendingCount.present) {
      map['pending_count'] = Variable<int>(pendingCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('id: $id, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPullAtUtc: $lastPullAtUtc, ')
          ..write('lastPushAtUtc: $lastPushAtUtc, ')
          ..write('pendingCount: $pendingCount')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPayloadMeta = const VerificationMeta(
    'localPayload',
  );
  @override
  late final GeneratedColumn<String> localPayload = GeneratedColumn<String>(
    'local_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverPayloadMeta = const VerificationMeta(
    'serverPayload',
  );
  @override
  late final GeneratedColumn<String> serverPayload = GeneratedColumn<String>(
    'server_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conflictingFieldsMeta = const VerificationMeta(
    'conflictingFields',
  );
  @override
  late final GeneratedColumn<String> conflictingFields =
      GeneratedColumn<String>(
        'conflicting_fields',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtUtcMeta = const VerificationMeta(
    'resolvedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAtUtc =
      GeneratedColumn<DateTime>(
        'resolved_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    localPayload,
    serverPayload,
    conflictingFields,
    createdAtUtc,
    resolvedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('local_payload')) {
      context.handle(
        _localPayloadMeta,
        localPayload.isAcceptableOrUnknown(
          data['local_payload']!,
          _localPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localPayloadMeta);
    }
    if (data.containsKey('server_payload')) {
      context.handle(
        _serverPayloadMeta,
        serverPayload.isAcceptableOrUnknown(
          data['server_payload']!,
          _serverPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverPayloadMeta);
    }
    if (data.containsKey('conflicting_fields')) {
      context.handle(
        _conflictingFieldsMeta,
        conflictingFields.isAcceptableOrUnknown(
          data['conflicting_fields']!,
          _conflictingFieldsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conflictingFieldsMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('resolved_at_utc')) {
      context.handle(
        _resolvedAtUtcMeta,
        resolvedAtUtc.isAcceptableOrUnknown(
          data['resolved_at_utc']!,
          _resolvedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      localPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_payload'],
      )!,
      serverPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_payload'],
      )!,
      conflictingFields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflicting_fields'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      resolvedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at_utc'],
      ),
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final String id;
  final String entityType;
  final String entityId;
  final String localPayload;
  final String serverPayload;
  final String conflictingFields;
  final DateTime createdAtUtc;
  final DateTime? resolvedAtUtc;
  const SyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localPayload,
    required this.serverPayload,
    required this.conflictingFields,
    required this.createdAtUtc,
    this.resolvedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['local_payload'] = Variable<String>(localPayload);
    map['server_payload'] = Variable<String>(serverPayload);
    map['conflicting_fields'] = Variable<String>(conflictingFields);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    if (!nullToAbsent || resolvedAtUtc != null) {
      map['resolved_at_utc'] = Variable<DateTime>(resolvedAtUtc);
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      localPayload: Value(localPayload),
      serverPayload: Value(serverPayload),
      conflictingFields: Value(conflictingFields),
      createdAtUtc: Value(createdAtUtc),
      resolvedAtUtc: resolvedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAtUtc),
    );
  }

  factory SyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      localPayload: serializer.fromJson<String>(json['localPayload']),
      serverPayload: serializer.fromJson<String>(json['serverPayload']),
      conflictingFields: serializer.fromJson<String>(json['conflictingFields']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      resolvedAtUtc: serializer.fromJson<DateTime?>(json['resolvedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'localPayload': serializer.toJson<String>(localPayload),
      'serverPayload': serializer.toJson<String>(serverPayload),
      'conflictingFields': serializer.toJson<String>(conflictingFields),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'resolvedAtUtc': serializer.toJson<DateTime?>(resolvedAtUtc),
    };
  }

  SyncConflict copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? localPayload,
    String? serverPayload,
    String? conflictingFields,
    DateTime? createdAtUtc,
    Value<DateTime?> resolvedAtUtc = const Value.absent(),
  }) => SyncConflict(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    localPayload: localPayload ?? this.localPayload,
    serverPayload: serverPayload ?? this.serverPayload,
    conflictingFields: conflictingFields ?? this.conflictingFields,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    resolvedAtUtc: resolvedAtUtc.present
        ? resolvedAtUtc.value
        : this.resolvedAtUtc,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      localPayload: data.localPayload.present
          ? data.localPayload.value
          : this.localPayload,
      serverPayload: data.serverPayload.present
          ? data.serverPayload.value
          : this.serverPayload,
      conflictingFields: data.conflictingFields.present
          ? data.conflictingFields.value
          : this.conflictingFields,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      resolvedAtUtc: data.resolvedAtUtc.present
          ? data.resolvedAtUtc.value
          : this.resolvedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localPayload: $localPayload, ')
          ..write('serverPayload: $serverPayload, ')
          ..write('conflictingFields: $conflictingFields, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('resolvedAtUtc: $resolvedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    localPayload,
    serverPayload,
    conflictingFields,
    createdAtUtc,
    resolvedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.localPayload == this.localPayload &&
          other.serverPayload == this.serverPayload &&
          other.conflictingFields == this.conflictingFields &&
          other.createdAtUtc == this.createdAtUtc &&
          other.resolvedAtUtc == this.resolvedAtUtc);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> localPayload;
  final Value<String> serverPayload;
  final Value<String> conflictingFields;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime?> resolvedAtUtc;
  final Value<int> rowid;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.localPayload = const Value.absent(),
    this.serverPayload = const Value.absent(),
    this.conflictingFields = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.resolvedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String localPayload,
    required String serverPayload,
    required String conflictingFields,
    required DateTime createdAtUtc,
    this.resolvedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       localPayload = Value(localPayload),
       serverPayload = Value(serverPayload),
       conflictingFields = Value(conflictingFields),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<SyncConflict> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? localPayload,
    Expression<String>? serverPayload,
    Expression<String>? conflictingFields,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? resolvedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (localPayload != null) 'local_payload': localPayload,
      if (serverPayload != null) 'server_payload': serverPayload,
      if (conflictingFields != null) 'conflicting_fields': conflictingFields,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (resolvedAtUtc != null) 'resolved_at_utc': resolvedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? localPayload,
    Value<String>? serverPayload,
    Value<String>? conflictingFields,
    Value<DateTime>? createdAtUtc,
    Value<DateTime?>? resolvedAtUtc,
    Value<int>? rowid,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      localPayload: localPayload ?? this.localPayload,
      serverPayload: serverPayload ?? this.serverPayload,
      conflictingFields: conflictingFields ?? this.conflictingFields,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      resolvedAtUtc: resolvedAtUtc ?? this.resolvedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (localPayload.present) {
      map['local_payload'] = Variable<String>(localPayload.value);
    }
    if (serverPayload.present) {
      map['server_payload'] = Variable<String>(serverPayload.value);
    }
    if (conflictingFields.present) {
      map['conflicting_fields'] = Variable<String>(conflictingFields.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (resolvedAtUtc.present) {
      map['resolved_at_utc'] = Variable<DateTime>(resolvedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localPayload: $localPayload, ')
          ..write('serverPayload: $serverPayload, ')
          ..write('conflictingFields: $conflictingFields, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('resolvedAtUtc: $resolvedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthEventsTable extends HealthEvents
    with TableInfo<$HealthEventsTable, HealthEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtUtcMeta = const VerificationMeta(
    'occurredAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAtUtc =
      GeneratedColumn<DateTime>(
        'occurred_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventType,
    stage,
    occurredAtUtc,
    latencyMs,
    errorCode,
    details,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('occurred_at_utc')) {
      context.handle(
        _occurredAtUtcMeta,
        occurredAtUtc.isAcceptableOrUnknown(
          data['occurred_at_utc']!,
          _occurredAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredAtUtcMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      occurredAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at_utc'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
    );
  }

  @override
  $HealthEventsTable createAlias(String alias) {
    return $HealthEventsTable(attachedDatabase, alias);
  }
}

class HealthEvent extends DataClass implements Insertable<HealthEvent> {
  final int id;
  final String eventType;
  final String stage;
  final DateTime occurredAtUtc;
  final int? latencyMs;
  final String? errorCode;
  final String? details;
  const HealthEvent({
    required this.id,
    required this.eventType,
    required this.stage,
    required this.occurredAtUtc,
    this.latencyMs,
    this.errorCode,
    this.details,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_type'] = Variable<String>(eventType);
    map['stage'] = Variable<String>(stage);
    map['occurred_at_utc'] = Variable<DateTime>(occurredAtUtc);
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    return map;
  }

  HealthEventsCompanion toCompanion(bool nullToAbsent) {
    return HealthEventsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      stage: Value(stage),
      occurredAtUtc: Value(occurredAtUtc),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
    );
  }

  factory HealthEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthEvent(
      id: serializer.fromJson<int>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      stage: serializer.fromJson<String>(json['stage']),
      occurredAtUtc: serializer.fromJson<DateTime>(json['occurredAtUtc']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      details: serializer.fromJson<String?>(json['details']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventType': serializer.toJson<String>(eventType),
      'stage': serializer.toJson<String>(stage),
      'occurredAtUtc': serializer.toJson<DateTime>(occurredAtUtc),
      'latencyMs': serializer.toJson<int?>(latencyMs),
      'errorCode': serializer.toJson<String?>(errorCode),
      'details': serializer.toJson<String?>(details),
    };
  }

  HealthEvent copyWith({
    int? id,
    String? eventType,
    String? stage,
    DateTime? occurredAtUtc,
    Value<int?> latencyMs = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> details = const Value.absent(),
  }) => HealthEvent(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    stage: stage ?? this.stage,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    details: details.present ? details.value : this.details,
  );
  HealthEvent copyWithCompanion(HealthEventsCompanion data) {
    return HealthEvent(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      stage: data.stage.present ? data.stage.value : this.stage,
      occurredAtUtc: data.occurredAtUtc.present
          ? data.occurredAtUtc.value
          : this.occurredAtUtc,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      details: data.details.present ? data.details.value : this.details,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthEvent(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('stage: $stage, ')
          ..write('occurredAtUtc: $occurredAtUtc, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('errorCode: $errorCode, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventType,
    stage,
    occurredAtUtc,
    latencyMs,
    errorCode,
    details,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthEvent &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.stage == this.stage &&
          other.occurredAtUtc == this.occurredAtUtc &&
          other.latencyMs == this.latencyMs &&
          other.errorCode == this.errorCode &&
          other.details == this.details);
}

class HealthEventsCompanion extends UpdateCompanion<HealthEvent> {
  final Value<int> id;
  final Value<String> eventType;
  final Value<String> stage;
  final Value<DateTime> occurredAtUtc;
  final Value<int?> latencyMs;
  final Value<String?> errorCode;
  final Value<String?> details;
  const HealthEventsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.stage = const Value.absent(),
    this.occurredAtUtc = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.details = const Value.absent(),
  });
  HealthEventsCompanion.insert({
    this.id = const Value.absent(),
    required String eventType,
    required String stage,
    required DateTime occurredAtUtc,
    this.latencyMs = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.details = const Value.absent(),
  }) : eventType = Value(eventType),
       stage = Value(stage),
       occurredAtUtc = Value(occurredAtUtc);
  static Insertable<HealthEvent> custom({
    Expression<int>? id,
    Expression<String>? eventType,
    Expression<String>? stage,
    Expression<DateTime>? occurredAtUtc,
    Expression<int>? latencyMs,
    Expression<String>? errorCode,
    Expression<String>? details,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (stage != null) 'stage': stage,
      if (occurredAtUtc != null) 'occurred_at_utc': occurredAtUtc,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (errorCode != null) 'error_code': errorCode,
      if (details != null) 'details': details,
    });
  }

  HealthEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? eventType,
    Value<String>? stage,
    Value<DateTime>? occurredAtUtc,
    Value<int?>? latencyMs,
    Value<String?>? errorCode,
    Value<String?>? details,
  }) {
    return HealthEventsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      stage: stage ?? this.stage,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      latencyMs: latencyMs ?? this.latencyMs,
      errorCode: errorCode ?? this.errorCode,
      details: details ?? this.details,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (occurredAtUtc.present) {
      map['occurred_at_utc'] = Variable<DateTime>(occurredAtUtc.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('stage: $stage, ')
          ..write('occurredAtUtc: $occurredAtUtc, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('errorCode: $errorCode, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }
}

class $LocalPreferencesTable extends LocalPreferences
    with TableInfo<$LocalPreferencesTable, LocalPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LocalPreferencesTable createAlias(String alias) {
    return $LocalPreferencesTable(attachedDatabase, alias);
  }
}

class LocalPreference extends DataClass implements Insertable<LocalPreference> {
  final String key;
  final String value;
  const LocalPreference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalPreferencesCompanion toCompanion(bool nullToAbsent) {
    return LocalPreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory LocalPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPreference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalPreference copyWith({String? key, String? value}) =>
      LocalPreference(key: key ?? this.key, value: value ?? this.value);
  LocalPreference copyWithCompanion(LocalPreferencesCompanion data) {
    return LocalPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPreference(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPreference &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalPreferencesCompanion extends UpdateCompanion<LocalPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalPreference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return LocalPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalTasksTable localTasks = $LocalTasksTable(this);
  late final $LocalBlockersTable localBlockers = $LocalBlockersTable(this);
  late final $LocalTagsTable localTags = $LocalTagsTable(this);
  late final $LocalProjectsTable localProjects = $LocalProjectsTable(this);
  late final $LocalChecklistGroupsTable localChecklistGroups =
      $LocalChecklistGroupsTable(this);
  late final $TaskTagsTable taskTags = $TaskTagsTable(this);
  late final $OutboxOperationsTable outboxOperations = $OutboxOperationsTable(
    this,
  );
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $HealthEventsTable healthEvents = $HealthEventsTable(this);
  late final $LocalPreferencesTable localPreferences = $LocalPreferencesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTasks,
    localBlockers,
    localTags,
    localProjects,
    localChecklistGroups,
    taskTags,
    outboxOperations,
    syncStates,
    syncConflicts,
    healthEvents,
    localPreferences,
  ];
}

typedef $$LocalTasksTableCreateCompanionBuilder =
    LocalTasksCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      required int quadrant,
      required int status,
      Value<DateTime?> dueAtUtc,
      Value<String?> parentId,
      required int depth,
      required int sortOrder,
      Value<String?> projectId,
      Value<String?> checklistGroupId,
      Value<int> version,
      Value<DateTime?> deletedAtUtc,
      required DateTime createdAtUtc,
      required DateTime updatedAtUtc,
      Value<DateTime?> completedAtUtc,
      Value<bool> dirty,
      required String updatedByDeviceId,
      Value<int> rowid,
    });
typedef $$LocalTasksTableUpdateCompanionBuilder =
    LocalTasksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<int> quadrant,
      Value<int> status,
      Value<DateTime?> dueAtUtc,
      Value<String?> parentId,
      Value<int> depth,
      Value<int> sortOrder,
      Value<String?> projectId,
      Value<String?> checklistGroupId,
      Value<int> version,
      Value<DateTime?> deletedAtUtc,
      Value<DateTime> createdAtUtc,
      Value<DateTime> updatedAtUtc,
      Value<DateTime?> completedAtUtc,
      Value<bool> dirty,
      Value<String> updatedByDeviceId,
      Value<int> rowid,
    });

class $$LocalTasksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quadrant => $composableBuilder(
    column: $table.quadrant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAtUtc => $composableBuilder(
    column: $table.dueAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checklistGroupId => $composableBuilder(
    column: $table.checklistGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quadrant => $composableBuilder(
    column: $table.quadrant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAtUtc => $composableBuilder(
    column: $table.dueAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checklistGroupId => $composableBuilder(
    column: $table.checklistGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quadrant =>
      $composableBuilder(column: $table.quadrant, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAtUtc =>
      $composableBuilder(column: $table.dueAtUtc, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get depth =>
      $composableBuilder(column: $table.depth, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get checklistGroupId => $composableBuilder(
    column: $table.checklistGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => column,
  );
}

class $$LocalTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTasksTable,
          LocalTask,
          $$LocalTasksTableFilterComposer,
          $$LocalTasksTableOrderingComposer,
          $$LocalTasksTableAnnotationComposer,
          $$LocalTasksTableCreateCompanionBuilder,
          $$LocalTasksTableUpdateCompanionBuilder,
          (
            LocalTask,
            BaseReferences<_$AppDatabase, $LocalTasksTable, LocalTask>,
          ),
          LocalTask,
          PrefetchHooks Function()
        > {
  $$LocalTasksTableTableManager(_$AppDatabase db, $LocalTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> quadrant = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime?> dueAtUtc = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> depth = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String?> checklistGroupId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<DateTime?> completedAtUtc = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> updatedByDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTasksCompanion(
                id: id,
                title: title,
                description: description,
                quadrant: quadrant,
                status: status,
                dueAtUtc: dueAtUtc,
                parentId: parentId,
                depth: depth,
                sortOrder: sortOrder,
                projectId: projectId,
                checklistGroupId: checklistGroupId,
                version: version,
                deletedAtUtc: deletedAtUtc,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                completedAtUtc: completedAtUtc,
                dirty: dirty,
                updatedByDeviceId: updatedByDeviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                required int quadrant,
                required int status,
                Value<DateTime?> dueAtUtc = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                required int depth,
                required int sortOrder,
                Value<String?> projectId = const Value.absent(),
                Value<String?> checklistGroupId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                required DateTime createdAtUtc,
                required DateTime updatedAtUtc,
                Value<DateTime?> completedAtUtc = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String updatedByDeviceId,
                Value<int> rowid = const Value.absent(),
              }) => LocalTasksCompanion.insert(
                id: id,
                title: title,
                description: description,
                quadrant: quadrant,
                status: status,
                dueAtUtc: dueAtUtc,
                parentId: parentId,
                depth: depth,
                sortOrder: sortOrder,
                projectId: projectId,
                checklistGroupId: checklistGroupId,
                version: version,
                deletedAtUtc: deletedAtUtc,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                completedAtUtc: completedAtUtc,
                dirty: dirty,
                updatedByDeviceId: updatedByDeviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTasksTable,
      LocalTask,
      $$LocalTasksTableFilterComposer,
      $$LocalTasksTableOrderingComposer,
      $$LocalTasksTableAnnotationComposer,
      $$LocalTasksTableCreateCompanionBuilder,
      $$LocalTasksTableUpdateCompanionBuilder,
      (LocalTask, BaseReferences<_$AppDatabase, $LocalTasksTable, LocalTask>),
      LocalTask,
      PrefetchHooks Function()
    >;
typedef $$LocalBlockersTableCreateCompanionBuilder =
    LocalBlockersCompanion Function({
      required String id,
      required String taskId,
      required String body,
      Value<bool> resolved,
      Value<DateTime?> resolvedAtUtc,
      Value<int> version,
      Value<DateTime?> deletedAtUtc,
      required DateTime createdAtUtc,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$LocalBlockersTableUpdateCompanionBuilder =
    LocalBlockersCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> body,
      Value<bool> resolved,
      Value<DateTime?> resolvedAtUtc,
      Value<int> version,
      Value<DateTime?> deletedAtUtc,
      Value<DateTime> createdAtUtc,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$LocalBlockersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBlockersTable> {
  $$LocalBlockersTableFilterComposer({
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

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAtUtc => $composableBuilder(
    column: $table.resolvedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBlockersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBlockersTable> {
  $$LocalBlockersTableOrderingComposer({
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

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAtUtc => $composableBuilder(
    column: $table.resolvedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBlockersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBlockersTable> {
  $$LocalBlockersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get resolved =>
      $composableBuilder(column: $table.resolved, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAtUtc => $composableBuilder(
    column: $table.resolvedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$LocalBlockersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBlockersTable,
          LocalBlocker,
          $$LocalBlockersTableFilterComposer,
          $$LocalBlockersTableOrderingComposer,
          $$LocalBlockersTableAnnotationComposer,
          $$LocalBlockersTableCreateCompanionBuilder,
          $$LocalBlockersTableUpdateCompanionBuilder,
          (
            LocalBlocker,
            BaseReferences<_$AppDatabase, $LocalBlockersTable, LocalBlocker>,
          ),
          LocalBlocker,
          PrefetchHooks Function()
        > {
  $$LocalBlockersTableTableManager(_$AppDatabase db, $LocalBlockersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBlockersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBlockersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBlockersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> resolved = const Value.absent(),
                Value<DateTime?> resolvedAtUtc = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBlockersCompanion(
                id: id,
                taskId: taskId,
                body: body,
                resolved: resolved,
                resolvedAtUtc: resolvedAtUtc,
                version: version,
                deletedAtUtc: deletedAtUtc,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String body,
                Value<bool> resolved = const Value.absent(),
                Value<DateTime?> resolvedAtUtc = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                required DateTime createdAtUtc,
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => LocalBlockersCompanion.insert(
                id: id,
                taskId: taskId,
                body: body,
                resolved: resolved,
                resolvedAtUtc: resolvedAtUtc,
                version: version,
                deletedAtUtc: deletedAtUtc,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBlockersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBlockersTable,
      LocalBlocker,
      $$LocalBlockersTableFilterComposer,
      $$LocalBlockersTableOrderingComposer,
      $$LocalBlockersTableAnnotationComposer,
      $$LocalBlockersTableCreateCompanionBuilder,
      $$LocalBlockersTableUpdateCompanionBuilder,
      (
        LocalBlocker,
        BaseReferences<_$AppDatabase, $LocalBlockersTable, LocalBlocker>,
      ),
      LocalBlocker,
      PrefetchHooks Function()
    >;
typedef $$LocalTagsTableCreateCompanionBuilder =
    LocalTagsCompanion Function({
      required String id,
      required String name,
      Value<String?> colorToken,
      Value<bool> archived,
      Value<int> version,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$LocalTagsTableUpdateCompanionBuilder =
    LocalTagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> colorToken,
      Value<bool> archived,
      Value<int> version,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$LocalTagsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTagsTable> {
  $$LocalTagsTableFilterComposer({
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

  ColumnFilters<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTagsTable> {
  $$LocalTagsTableOrderingComposer({
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

  ColumnOrderings<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTagsTable> {
  $$LocalTagsTableAnnotationComposer({
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

  GeneratedColumn<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$LocalTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTagsTable,
          LocalTag,
          $$LocalTagsTableFilterComposer,
          $$LocalTagsTableOrderingComposer,
          $$LocalTagsTableAnnotationComposer,
          $$LocalTagsTableCreateCompanionBuilder,
          $$LocalTagsTableUpdateCompanionBuilder,
          (LocalTag, BaseReferences<_$AppDatabase, $LocalTagsTable, LocalTag>),
          LocalTag,
          PrefetchHooks Function()
        > {
  $$LocalTagsTableTableManager(_$AppDatabase db, $LocalTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> colorToken = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTagsCompanion(
                id: id,
                name: name,
                colorToken: colorToken,
                archived: archived,
                version: version,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> colorToken = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => LocalTagsCompanion.insert(
                id: id,
                name: name,
                colorToken: colorToken,
                archived: archived,
                version: version,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTagsTable,
      LocalTag,
      $$LocalTagsTableFilterComposer,
      $$LocalTagsTableOrderingComposer,
      $$LocalTagsTableAnnotationComposer,
      $$LocalTagsTableCreateCompanionBuilder,
      $$LocalTagsTableUpdateCompanionBuilder,
      (LocalTag, BaseReferences<_$AppDatabase, $LocalTagsTable, LocalTag>),
      LocalTag,
      PrefetchHooks Function()
    >;
typedef $$LocalProjectsTableCreateCompanionBuilder =
    LocalProjectsCompanion Function({
      required String id,
      required String name,
      Value<bool> archived,
      Value<int> version,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$LocalProjectsTableUpdateCompanionBuilder =
    LocalProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<bool> archived,
      Value<int> version,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$LocalProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableFilterComposer({
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

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableOrderingComposer({
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

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableAnnotationComposer({
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

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$LocalProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProjectsTable,
          LocalProject,
          $$LocalProjectsTableFilterComposer,
          $$LocalProjectsTableOrderingComposer,
          $$LocalProjectsTableAnnotationComposer,
          $$LocalProjectsTableCreateCompanionBuilder,
          $$LocalProjectsTableUpdateCompanionBuilder,
          (
            LocalProject,
            BaseReferences<_$AppDatabase, $LocalProjectsTable, LocalProject>,
          ),
          LocalProject,
          PrefetchHooks Function()
        > {
  $$LocalProjectsTableTableManager(_$AppDatabase db, $LocalProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProjectsCompanion(
                id: id,
                name: name,
                archived: archived,
                version: version,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => LocalProjectsCompanion.insert(
                id: id,
                name: name,
                archived: archived,
                version: version,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProjectsTable,
      LocalProject,
      $$LocalProjectsTableFilterComposer,
      $$LocalProjectsTableOrderingComposer,
      $$LocalProjectsTableAnnotationComposer,
      $$LocalProjectsTableCreateCompanionBuilder,
      $$LocalProjectsTableUpdateCompanionBuilder,
      (
        LocalProject,
        BaseReferences<_$AppDatabase, $LocalProjectsTable, LocalProject>,
      ),
      LocalProject,
      PrefetchHooks Function()
    >;
typedef $$LocalChecklistGroupsTableCreateCompanionBuilder =
    LocalChecklistGroupsCompanion Function({
      required String id,
      required String name,
      Value<bool> archived,
      Value<int> version,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$LocalChecklistGroupsTableUpdateCompanionBuilder =
    LocalChecklistGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<bool> archived,
      Value<int> version,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$LocalChecklistGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalChecklistGroupsTable> {
  $$LocalChecklistGroupsTableFilterComposer({
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

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalChecklistGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalChecklistGroupsTable> {
  $$LocalChecklistGroupsTableOrderingComposer({
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

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalChecklistGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalChecklistGroupsTable> {
  $$LocalChecklistGroupsTableAnnotationComposer({
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

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$LocalChecklistGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalChecklistGroupsTable,
          LocalChecklistGroup,
          $$LocalChecklistGroupsTableFilterComposer,
          $$LocalChecklistGroupsTableOrderingComposer,
          $$LocalChecklistGroupsTableAnnotationComposer,
          $$LocalChecklistGroupsTableCreateCompanionBuilder,
          $$LocalChecklistGroupsTableUpdateCompanionBuilder,
          (
            LocalChecklistGroup,
            BaseReferences<
              _$AppDatabase,
              $LocalChecklistGroupsTable,
              LocalChecklistGroup
            >,
          ),
          LocalChecklistGroup,
          PrefetchHooks Function()
        > {
  $$LocalChecklistGroupsTableTableManager(
    _$AppDatabase db,
    $LocalChecklistGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalChecklistGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalChecklistGroupsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalChecklistGroupsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalChecklistGroupsCompanion(
                id: id,
                name: name,
                archived: archived,
                version: version,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => LocalChecklistGroupsCompanion.insert(
                id: id,
                name: name,
                archived: archived,
                version: version,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalChecklistGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalChecklistGroupsTable,
      LocalChecklistGroup,
      $$LocalChecklistGroupsTableFilterComposer,
      $$LocalChecklistGroupsTableOrderingComposer,
      $$LocalChecklistGroupsTableAnnotationComposer,
      $$LocalChecklistGroupsTableCreateCompanionBuilder,
      $$LocalChecklistGroupsTableUpdateCompanionBuilder,
      (
        LocalChecklistGroup,
        BaseReferences<
          _$AppDatabase,
          $LocalChecklistGroupsTable,
          LocalChecklistGroup
        >,
      ),
      LocalChecklistGroup,
      PrefetchHooks Function()
    >;
typedef $$TaskTagsTableCreateCompanionBuilder =
    TaskTagsCompanion Function({
      required String taskId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$TaskTagsTableUpdateCompanionBuilder =
    TaskTagsCompanion Function({
      Value<String> taskId,
      Value<String> tagId,
      Value<int> rowid,
    });

class $$TaskTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$TaskTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskTagsTable,
          TaskTag,
          $$TaskTagsTableFilterComposer,
          $$TaskTagsTableOrderingComposer,
          $$TaskTagsTableAnnotationComposer,
          $$TaskTagsTableCreateCompanionBuilder,
          $$TaskTagsTableUpdateCompanionBuilder,
          (TaskTag, BaseReferences<_$AppDatabase, $TaskTagsTable, TaskTag>),
          TaskTag,
          PrefetchHooks Function()
        > {
  $$TaskTagsTableTableManager(_$AppDatabase db, $TaskTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  TaskTagsCompanion(taskId: taskId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String taskId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion.insert(
                taskId: taskId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskTagsTable,
      TaskTag,
      $$TaskTagsTableFilterComposer,
      $$TaskTagsTableOrderingComposer,
      $$TaskTagsTableAnnotationComposer,
      $$TaskTagsTableCreateCompanionBuilder,
      $$TaskTagsTableUpdateCompanionBuilder,
      (TaskTag, BaseReferences<_$AppDatabase, $TaskTagsTable, TaskTag>),
      TaskTag,
      PrefetchHooks Function()
    >;
typedef $$OutboxOperationsTableCreateCompanionBuilder =
    OutboxOperationsCompanion Function({
      required String operationId,
      required String entityType,
      required String entityId,
      required int baseVersion,
      required String payload,
      required DateTime createdAtUtc,
      Value<int> attemptCount,
      required DateTime nextAttemptAtUtc,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$OutboxOperationsTableUpdateCompanionBuilder =
    OutboxOperationsCompanion Function({
      Value<String> operationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> baseVersion,
      Value<String> payload,
      Value<DateTime> createdAtUtc,
      Value<int> attemptCount,
      Value<DateTime> nextAttemptAtUtc,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$OutboxOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxOperationsTable> {
  $$OutboxOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxOperationsTable> {
  $$OutboxOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxOperationsTable> {
  $$OutboxOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxOperationsTable,
          OutboxOperation,
          $$OutboxOperationsTableFilterComposer,
          $$OutboxOperationsTableOrderingComposer,
          $$OutboxOperationsTableAnnotationComposer,
          $$OutboxOperationsTableCreateCompanionBuilder,
          $$OutboxOperationsTableUpdateCompanionBuilder,
          (
            OutboxOperation,
            BaseReferences<
              _$AppDatabase,
              $OutboxOperationsTable,
              OutboxOperation
            >,
          ),
          OutboxOperation,
          PrefetchHooks Function()
        > {
  $$OutboxOperationsTableTableManager(
    _$AppDatabase db,
    $OutboxOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime> nextAttemptAtUtc = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxOperationsCompanion(
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                baseVersion: baseVersion,
                payload: payload,
                createdAtUtc: createdAtUtc,
                attemptCount: attemptCount,
                nextAttemptAtUtc: nextAttemptAtUtc,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String entityType,
                required String entityId,
                required int baseVersion,
                required String payload,
                required DateTime createdAtUtc,
                Value<int> attemptCount = const Value.absent(),
                required DateTime nextAttemptAtUtc,
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxOperationsCompanion.insert(
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                baseVersion: baseVersion,
                payload: payload,
                createdAtUtc: createdAtUtc,
                attemptCount: attemptCount,
                nextAttemptAtUtc: nextAttemptAtUtc,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxOperationsTable,
      OutboxOperation,
      $$OutboxOperationsTableFilterComposer,
      $$OutboxOperationsTableOrderingComposer,
      $$OutboxOperationsTableAnnotationComposer,
      $$OutboxOperationsTableCreateCompanionBuilder,
      $$OutboxOperationsTableUpdateCompanionBuilder,
      (
        OutboxOperation,
        BaseReferences<_$AppDatabase, $OutboxOperationsTable, OutboxOperation>,
      ),
      OutboxOperation,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<int> id,
      Value<int> serverCursor,
      Value<DateTime?> lastPullAtUtc,
      Value<DateTime?> lastPushAtUtc,
      Value<int> pendingCount,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<int> id,
      Value<int> serverCursor,
      Value<DateTime?> lastPullAtUtc,
      Value<DateTime?> lastPushAtUtc,
      Value<int> pendingCount,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
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

  ColumnFilters<int> get serverCursor => $composableBuilder(
    column: $table.serverCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPullAtUtc => $composableBuilder(
    column: $table.lastPullAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPushAtUtc => $composableBuilder(
    column: $table.lastPushAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingCount => $composableBuilder(
    column: $table.pendingCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
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

  ColumnOrderings<int> get serverCursor => $composableBuilder(
    column: $table.serverCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPullAtUtc => $composableBuilder(
    column: $table.lastPullAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPushAtUtc => $composableBuilder(
    column: $table.lastPushAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingCount => $composableBuilder(
    column: $table.pendingCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverCursor => $composableBuilder(
    column: $table.serverCursor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPullAtUtc => $composableBuilder(
    column: $table.lastPullAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPushAtUtc => $composableBuilder(
    column: $table.lastPushAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pendingCount => $composableBuilder(
    column: $table.pendingCount,
    builder: (column) => column,
  );
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncState,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>,
          ),
          SyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> serverCursor = const Value.absent(),
                Value<DateTime?> lastPullAtUtc = const Value.absent(),
                Value<DateTime?> lastPushAtUtc = const Value.absent(),
                Value<int> pendingCount = const Value.absent(),
              }) => SyncStatesCompanion(
                id: id,
                serverCursor: serverCursor,
                lastPullAtUtc: lastPullAtUtc,
                lastPushAtUtc: lastPushAtUtc,
                pendingCount: pendingCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> serverCursor = const Value.absent(),
                Value<DateTime?> lastPullAtUtc = const Value.absent(),
                Value<DateTime?> lastPushAtUtc = const Value.absent(),
                Value<int> pendingCount = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                id: id,
                serverCursor: serverCursor,
                lastPullAtUtc: lastPullAtUtc,
                lastPushAtUtc: lastPushAtUtc,
                pendingCount: pendingCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
      SyncState,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      required String id,
      required String entityType,
      required String entityId,
      required String localPayload,
      required String serverPayload,
      required String conflictingFields,
      required DateTime createdAtUtc,
      Value<DateTime?> resolvedAtUtc,
      Value<int> rowid,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<String> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> localPayload,
      Value<String> serverPayload,
      Value<String> conflictingFields,
      Value<DateTime> createdAtUtc,
      Value<DateTime?> resolvedAtUtc,
      Value<int> rowid,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
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

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPayload => $composableBuilder(
    column: $table.localPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverPayload => $composableBuilder(
    column: $table.serverPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictingFields => $composableBuilder(
    column: $table.conflictingFields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAtUtc => $composableBuilder(
    column: $table.resolvedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPayload => $composableBuilder(
    column: $table.localPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverPayload => $composableBuilder(
    column: $table.serverPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictingFields => $composableBuilder(
    column: $table.conflictingFields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAtUtc => $composableBuilder(
    column: $table.resolvedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get localPayload => $composableBuilder(
    column: $table.localPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverPayload => $composableBuilder(
    column: $table.serverPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictingFields => $composableBuilder(
    column: $table.conflictingFields,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAtUtc => $composableBuilder(
    column: $table.resolvedAtUtc,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflict,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
          ),
          SyncConflict,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> localPayload = const Value.absent(),
                Value<String> serverPayload = const Value.absent(),
                Value<String> conflictingFields = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime?> resolvedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                localPayload: localPayload,
                serverPayload: serverPayload,
                conflictingFields: conflictingFields,
                createdAtUtc: createdAtUtc,
                resolvedAtUtc: resolvedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String entityId,
                required String localPayload,
                required String serverPayload,
                required String conflictingFields,
                required DateTime createdAtUtc,
                Value<DateTime?> resolvedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                localPayload: localPayload,
                serverPayload: serverPayload,
                conflictingFields: conflictingFields,
                createdAtUtc: createdAtUtc,
                resolvedAtUtc: resolvedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflict,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
      ),
      SyncConflict,
      PrefetchHooks Function()
    >;
typedef $$HealthEventsTableCreateCompanionBuilder =
    HealthEventsCompanion Function({
      Value<int> id,
      required String eventType,
      required String stage,
      required DateTime occurredAtUtc,
      Value<int?> latencyMs,
      Value<String?> errorCode,
      Value<String?> details,
    });
typedef $$HealthEventsTableUpdateCompanionBuilder =
    HealthEventsCompanion Function({
      Value<int> id,
      Value<String> eventType,
      Value<String> stage,
      Value<DateTime> occurredAtUtc,
      Value<int?> latencyMs,
      Value<String?> errorCode,
      Value<String?> details,
    });

class $$HealthEventsTableFilterComposer
    extends Composer<_$AppDatabase, $HealthEventsTable> {
  $$HealthEventsTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HealthEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthEventsTable> {
  $$HealthEventsTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HealthEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthEventsTable> {
  $$HealthEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);
}

class $$HealthEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthEventsTable,
          HealthEvent,
          $$HealthEventsTableFilterComposer,
          $$HealthEventsTableOrderingComposer,
          $$HealthEventsTableAnnotationComposer,
          $$HealthEventsTableCreateCompanionBuilder,
          $$HealthEventsTableUpdateCompanionBuilder,
          (
            HealthEvent,
            BaseReferences<_$AppDatabase, $HealthEventsTable, HealthEvent>,
          ),
          HealthEvent,
          PrefetchHooks Function()
        > {
  $$HealthEventsTableTableManager(_$AppDatabase db, $HealthEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<DateTime> occurredAtUtc = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> details = const Value.absent(),
              }) => HealthEventsCompanion(
                id: id,
                eventType: eventType,
                stage: stage,
                occurredAtUtc: occurredAtUtc,
                latencyMs: latencyMs,
                errorCode: errorCode,
                details: details,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String eventType,
                required String stage,
                required DateTime occurredAtUtc,
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> details = const Value.absent(),
              }) => HealthEventsCompanion.insert(
                id: id,
                eventType: eventType,
                stage: stage,
                occurredAtUtc: occurredAtUtc,
                latencyMs: latencyMs,
                errorCode: errorCode,
                details: details,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HealthEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthEventsTable,
      HealthEvent,
      $$HealthEventsTableFilterComposer,
      $$HealthEventsTableOrderingComposer,
      $$HealthEventsTableAnnotationComposer,
      $$HealthEventsTableCreateCompanionBuilder,
      $$HealthEventsTableUpdateCompanionBuilder,
      (
        HealthEvent,
        BaseReferences<_$AppDatabase, $HealthEventsTable, HealthEvent>,
      ),
      HealthEvent,
      PrefetchHooks Function()
    >;
typedef $$LocalPreferencesTableCreateCompanionBuilder =
    LocalPreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$LocalPreferencesTableUpdateCompanionBuilder =
    LocalPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$LocalPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPreferencesTable> {
  $$LocalPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPreferencesTable> {
  $$LocalPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPreferencesTable> {
  $$LocalPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPreferencesTable,
          LocalPreference,
          $$LocalPreferencesTableFilterComposer,
          $$LocalPreferencesTableOrderingComposer,
          $$LocalPreferencesTableAnnotationComposer,
          $$LocalPreferencesTableCreateCompanionBuilder,
          $$LocalPreferencesTableUpdateCompanionBuilder,
          (
            LocalPreference,
            BaseReferences<
              _$AppDatabase,
              $LocalPreferencesTable,
              LocalPreference
            >,
          ),
          LocalPreference,
          PrefetchHooks Function()
        > {
  $$LocalPreferencesTableTableManager(
    _$AppDatabase db,
    $LocalPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPreferencesCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => LocalPreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPreferencesTable,
      LocalPreference,
      $$LocalPreferencesTableFilterComposer,
      $$LocalPreferencesTableOrderingComposer,
      $$LocalPreferencesTableAnnotationComposer,
      $$LocalPreferencesTableCreateCompanionBuilder,
      $$LocalPreferencesTableUpdateCompanionBuilder,
      (
        LocalPreference,
        BaseReferences<_$AppDatabase, $LocalPreferencesTable, LocalPreference>,
      ),
      LocalPreference,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalTasksTableTableManager get localTasks =>
      $$LocalTasksTableTableManager(_db, _db.localTasks);
  $$LocalBlockersTableTableManager get localBlockers =>
      $$LocalBlockersTableTableManager(_db, _db.localBlockers);
  $$LocalTagsTableTableManager get localTags =>
      $$LocalTagsTableTableManager(_db, _db.localTags);
  $$LocalProjectsTableTableManager get localProjects =>
      $$LocalProjectsTableTableManager(_db, _db.localProjects);
  $$LocalChecklistGroupsTableTableManager get localChecklistGroups =>
      $$LocalChecklistGroupsTableTableManager(_db, _db.localChecklistGroups);
  $$TaskTagsTableTableManager get taskTags =>
      $$TaskTagsTableTableManager(_db, _db.taskTags);
  $$OutboxOperationsTableTableManager get outboxOperations =>
      $$OutboxOperationsTableTableManager(_db, _db.outboxOperations);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$HealthEventsTableTableManager get healthEvents =>
      $$HealthEventsTableTableManager(_db, _db.healthEvents);
  $$LocalPreferencesTableTableManager get localPreferences =>
      $$LocalPreferencesTableTableManager(_db, _db.localPreferences);
}
