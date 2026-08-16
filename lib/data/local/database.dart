import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class LocalTasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get quadrant => integer()();
  IntColumn get status => integer()();
  DateTimeColumn get dueAtUtc => dateTime().nullable()();
  TextColumn get parentId => text().nullable()();
  IntColumn get depth => integer()();
  IntColumn get sortOrder => integer()();
  TextColumn get projectId => text().nullable()();
  TextColumn get checklistGroupId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();
  DateTimeColumn get completedAtUtc => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant<bool>(true))();
  TextColumn get updatedByDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class LocalBlockers extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get body => text()();
  BoolColumn get resolved =>
      boolean().withDefault(const Constant<bool>(false))();
  DateTimeColumn get resolvedAtUtc => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class LocalTags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorToken => text().nullable()();
  BoolColumn get archived =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get version => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{name},
  ];
}

class LocalProjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get archived =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get version => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class LocalChecklistGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get archived =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get version => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class TaskTags extends Table {
  TextColumn get taskId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{taskId, tagId};
}

class OutboxOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get baseVersion => integer()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get nextAttemptAtUtc => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{operationId};
}

class SyncStates extends Table {
  IntColumn get id => integer().withDefault(const Constant<int>(1))();
  IntColumn get serverCursor => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get lastPullAtUtc => dateTime().nullable()();
  DateTimeColumn get lastPushAtUtc => dateTime().nullable()();
  IntColumn get pendingCount => integer().withDefault(const Constant<int>(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get localPayload => text()();
  TextColumn get serverPayload => text()();
  TextColumn get conflictingFields => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get resolvedAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class HealthEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventType => text()();
  TextColumn get stage => text()();
  DateTimeColumn get occurredAtUtc => dateTime()();
  IntColumn get latencyMs => integer().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get details => text().nullable()();
}

class LocalPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DriftDatabase(
  tables: <Type>[
    LocalTasks,
    LocalBlockers,
    LocalTags,
    LocalProjects,
    LocalChecklistGroups,
    TaskTags,
    OutboxOperations,
    SyncStates,
    SyncConflicts,
    HealthEvents,
    LocalPreferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createIndexes();
      await into(syncStates).insert(
        const SyncStatesCompanion(id: Value<int>(1)),
        mode: InsertMode.insertOrIgnore,
      );
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX idx_tasks_parent_sort '
      'ON local_tasks(parent_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX idx_tasks_status_due '
      'ON local_tasks(status, due_at_utc)',
    );
    await customStatement(
      'CREATE INDEX idx_tasks_quadrant_status '
      'ON local_tasks(quadrant, status)',
    );
    await customStatement(
      'CREATE INDEX idx_tasks_updated ON local_tasks(updated_at_utc)',
    );
    await customStatement(
      'CREATE INDEX idx_tasks_deleted ON local_tasks(deleted_at_utc)',
    );
    await customStatement(
      'CREATE INDEX idx_outbox_ready '
      'ON outbox_operations(next_attempt_at_utc, created_at_utc)',
    );
  }
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final documents = await getApplicationSupportDirectory();
  final file = File(path.join(documents.path, 'kairos.sqlite'));
  return NativeDatabase.createInBackground(file);
});
