import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/local/database.dart';
import 'package:kairos/data/remote/kairos_api.dart';
import 'package:kairos/data/remote/remote_models.dart';
import 'package:kairos/data/repositories/local_task_repository.dart';
import 'package:kairos/data/sync/sync_engine.dart';
import 'package:kairos/domain/entities/app_preferences.dart';
import 'package:kairos/domain/repositories/settings_repository.dart';
import 'package:kairos/features/sync/application/auth_controller.dart';

void main() {
  late AppDatabase database;
  late _FakeApi api;
  late SyncEngine engine;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    api = _FakeApi();
    engine = SyncEngine(
      database: database,
      api: api,
      auth: const _FakeAccessTokenProvider(),
      settings: _FakeSettingsRepository(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('applies first snapshot and advances cursor atomically', () async {
    api.snapshotResponse = <String, dynamic>{
      'tasks': <Map<String, dynamic>>[_remoteTask(id: 'remote', version: 1)],
      'blockers': <dynamic>[],
      'tags': <dynamic>[],
      'projects': <dynamic>[],
      'checklist_groups': <dynamic>[],
      'cursor': 7,
    };

    final outcome = await engine.synchronize();
    final task = await (database.select(
      database.localTasks,
    )..where((table) => table.id.equals('remote'))).getSingle();
    final syncState = await database.select(database.syncStates).getSingle();

    expect(task.title, 'Remote task');
    expect(task.dirty, isFalse);
    expect(syncState.serverCursor, 7);
    expect(outcome.cursor, 7);
  });

  test('pushes outbox and applies authoritative server entity', () async {
    await _markSnapshotCompleted(database);
    final repository = LocalTaskRepository(
      database,
      entityIdGenerator: () => 'local-task',
      operationIdGenerator: () => 'local-operation',
    );
    await repository.createTask(title: 'Local task', deviceId: 'device-a');
    api.pushResults = <PushResult>[
      PushResult(
        operationId: 'local-operation',
        status: 'applied',
        entityType: 'task',
        entityId: 'local-task',
        version: 1,
        cursor: 1,
        code: null,
        conflictingFields: const <String>[],
        serverEntity: _remoteTask(id: 'local-task', version: 1),
      ),
    ];

    final outcome = await engine.synchronize();
    final task = await repository.getTask('local-task');
    final outbox = await database.select(database.outboxOperations).get();

    expect(api.pushedOperations.single['entity_id'], 'local-task');
    expect(task!.dirty, isFalse);
    expect(task.version, 1);
    expect(outbox, isEmpty);
    expect(outcome.pushed, 1);
  });

  test('does not overwrite dirty task during snapshot', () async {
    final repository = LocalTaskRepository(
      database,
      entityIdGenerator: () => 'shared-task',
      operationIdGenerator: () => 'local-operation',
    );
    await repository.createTask(title: 'Local draft', deviceId: 'device-a');
    api.snapshotResponse = <String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        _remoteTask(id: 'shared-task', version: 2),
      ],
      'blockers': <dynamic>[],
      'tags': <dynamic>[],
      'projects': <dynamic>[],
      'checklist_groups': <dynamic>[],
      'cursor': 2,
    };

    await engine.synchronize();
    final task = await repository.getTask('shared-task');
    final conflicts = await database.select(database.syncConflicts).get();

    expect(task!.title, 'Local draft');
    expect(task.dirty, isTrue);
    expect(conflicts, hasLength(1));
  });

  test('keeps old cursor when a pull batch cannot be applied', () async {
    await _markSnapshotCompleted(database);
    api.changesPages = <RemoteChangesPage>[
      RemoteChangesPage(
        changes: <RemoteChange>[
          RemoteChange(
            cursor: 1,
            entityType: 'task',
            entityId: 'broken',
            entityVersion: 1,
            deleted: false,
            entity: <String, dynamic>{'id': 'broken', 'version': 1},
          ),
        ],
        nextCursor: 1,
        serverCursor: 1,
        hasMore: false,
      ),
    ];

    await expectLater(engine.synchronize(), throwsA(anything));
    final state = await database.select(database.syncStates).getSingle();
    final tasks = await database.select(database.localTasks).get();

    expect(state.serverCursor, 0);
    expect(tasks, isEmpty);
  });

  test('catches a lagging device up to the authoritative cursor', () async {
    await _markSnapshotCompleted(database);
    await (database.update(database.syncStates)
          ..where((table) => table.id.equals(1)))
        .write(const SyncStatesCompanion(serverCursor: Value<int>(1)));
    api.serverCursor = 53;
    api.changesPages = <RemoteChangesPage>[
      RemoteChangesPage(
        changes: <RemoteChange>[
          RemoteChange(
            cursor: 53,
            entityType: 'task',
            entityId: 'remote',
            entityVersion: 1,
            deleted: false,
            entity: _remoteTask(id: 'remote', version: 1),
          ),
        ],
        nextCursor: 53,
        serverCursor: 53,
        hasMore: false,
      ),
    ];

    final outcome = await engine.synchronize();

    expect(outcome.cursor, 53);
    expect(
      (await database.select(database.syncStates).getSingle()).serverCursor,
      53,
    );
    expect(api.requestedAfter, contains(1));
  });

  test(
    'rebuilds from snapshot when the server cursor moved backwards',
    () async {
      await _markSnapshotCompleted(database);
      await (database.update(database.syncStates)
            ..where((table) => table.id.equals(1)))
          .write(const SyncStatesCompanion(serverCursor: Value<int>(53)));
      api.serverCursor = 1;
      api.snapshotResponse = <String, dynamic>{
        'tasks': <Map<String, dynamic>>[_remoteTask(id: 'remote', version: 1)],
        'blockers': <dynamic>[],
        'tags': <dynamic>[],
        'projects': <dynamic>[],
        'checklist_groups': <dynamic>[],
        'cursor': 1,
      };

      final outcome = await engine.synchronize();

      expect(outcome.cursor, 1);
      expect(api.snapshotCalls, 1);
      expect(api.requestedAfter, isNot(contains(53)));
    },
  );

  test('rejects a non-advancing page below the server cursor', () async {
    await _markSnapshotCompleted(database);
    api.serverCursor = 2;
    api.changesPages = <RemoteChangesPage>[
      const RemoteChangesPage(
        changes: <RemoteChange>[],
        nextCursor: 0,
        serverCursor: 2,
        hasMore: false,
      ),
    ];

    await expectLater(engine.synchronize(), throwsA(isA<StateError>()));
    expect(
      (await database.select(database.syncStates).getSingle()).serverCursor,
      0,
    );
  });

  test(
    'rebases conflicted outbox operation when keeping local version',
    () async {
      final repository = LocalTaskRepository(
        database,
        entityIdGenerator: () => 'shared-task',
        operationIdGenerator: () => 'local-operation',
      );
      await repository.createTask(title: 'Local title', deviceId: 'device-a');
      final conflict = await _insertConflict(
        database,
        localTitle: 'Local title',
      );

      await engine.resolveConflict(conflict, SyncConflictResolution.keepLocal);

      final task = await repository.getTask('shared-task');
      final operation = await database
          .select(database.outboxOperations)
          .getSingle();
      final resolved = await database
          .select(database.syncConflicts)
          .getSingle();
      final syncState = await database.select(database.syncStates).getSingle();
      expect(task!.title, 'Local title');
      expect(task.version, 4);
      expect(task.dirty, isTrue);
      expect(operation.baseVersion, 4);
      expect(operation.lastError, equals(null));
      expect(resolved.resolvedAtUtc, isNot(equals(null)));
      expect(syncState.pendingCount, 1);
    },
  );

  test(
    'applies server entity and drops outbox when using server version',
    () async {
      final repository = LocalTaskRepository(
        database,
        entityIdGenerator: () => 'shared-task',
        operationIdGenerator: () => 'local-operation',
      );
      await repository.createTask(title: 'Local title', deviceId: 'device-a');
      final conflict = await _insertConflict(
        database,
        localTitle: 'Local title',
      );

      await engine.resolveConflict(conflict, SyncConflictResolution.useServer);

      final task = await repository.getTask('shared-task');
      final operations = await database.select(database.outboxOperations).get();
      final resolved = await database
          .select(database.syncConflicts)
          .getSingle();
      final syncState = await database.select(database.syncStates).getSingle();
      expect(task!.title, 'Remote task');
      expect(task.version, 4);
      expect(task.dirty, isFalse);
      expect(operations, isEmpty);
      expect(resolved.resolvedAtUtc, isNot(equals(null)));
      expect(syncState.pendingCount, 0);
    },
  );
}

Future<SyncConflict> _insertConflict(
  AppDatabase database, {
  required String localTitle,
}) async {
  await (database.update(
    database.outboxOperations,
  )..where((table) => table.operationId.equals('local-operation'))).write(
    OutboxOperationsCompanion(
      lastError: const Value<String?>('conflict'),
      nextAttemptAtUtc: Value<DateTime>(
        DateTime.now().toUtc().add(const Duration(days: 365)),
      ),
    ),
  );
  await database
      .into(database.syncConflicts)
      .insert(
        SyncConflictsCompanion.insert(
          id: 'conflict-id',
          entityType: 'task',
          entityId: 'shared-task',
          localPayload: jsonEncode(<String, Object?>{
            'changes': <String, Object?>{'title': localTitle},
          }),
          serverPayload: jsonEncode(_remoteTask(id: 'shared-task', version: 4)),
          conflictingFields: jsonEncode(<String>['title']),
          createdAtUtc: DateTime.now().toUtc(),
        ),
      );
  return database.select(database.syncConflicts).getSingle();
}

Map<String, dynamic> _remoteTask({required String id, required int version}) {
  final now = DateTime.utc(2026, 8, 16, 8).toIso8601String();
  return <String, dynamic>{
    'id': id,
    'title': 'Remote task',
    'description': null,
    'quadrant': 2,
    'status': 0,
    'due_at': null,
    'parent_id': null,
    'depth': 1,
    'sort_order': 0,
    'project_id': null,
    'checklist_group_id': null,
    'version': version,
    'deleted_at': null,
    'created_at': now,
    'updated_at': now,
    'completed_at': null,
    'updated_by_device_id': 'device-a',
    'tag_ids': <String>[],
  };
}

Future<void> _markSnapshotCompleted(AppDatabase database) async {
  await database
      .into(database.localPreferences)
      .insert(
        LocalPreferencesCompanion.insert(
          key: 'sync_snapshot_completed',
          value: 'true',
        ),
      );
  await database
      .into(database.syncStates)
      .insert(
        const SyncStatesCompanion(id: Value<int>(1)),
        mode: InsertMode.insertOrIgnore,
      );
}

class _FakeApi extends KairosApi {
  Map<String, dynamic> snapshotResponse = <String, dynamic>{
    'tasks': <dynamic>[],
    'blockers': <dynamic>[],
    'tags': <dynamic>[],
    'projects': <dynamic>[],
    'checklist_groups': <dynamic>[],
    'cursor': 0,
  };
  List<RemoteChangesPage> changesPages = <RemoteChangesPage>[];
  List<PushResult> pushResults = <PushResult>[];
  List<Map<String, Object?>> pushedOperations = <Map<String, Object?>>[];
  final List<int> requestedAfter = <int>[];
  int serverCursor = 0;
  int snapshotCalls = 0;

  @override
  Future<Map<String, dynamic>> snapshot({
    required Uri endpoint,
    required String accessToken,
  }) async {
    snapshotCalls++;
    final cursor = (snapshotResponse['cursor'] as num).toInt();
    if (cursor > serverCursor) {
      serverCursor = cursor;
    }
    return snapshotResponse;
  }

  @override
  Future<RemoteSyncStatus> syncStatus({
    required Uri endpoint,
    required String accessToken,
  }) async {
    for (final page in changesPages) {
      if (page.serverCursor > serverCursor) {
        serverCursor = page.serverCursor;
      }
    }
    final snapshotCursor = (snapshotResponse['cursor'] as num).toInt();
    if (snapshotCursor > serverCursor) {
      serverCursor = snapshotCursor;
    }
    return RemoteSyncStatus(serverCursor: serverCursor, deviceId: 'device-a');
  }

  @override
  Future<RemoteChangesPage> changes({
    required Uri endpoint,
    required String accessToken,
    required int after,
    int limit = 200,
  }) async {
    requestedAfter.add(after);
    if (changesPages.isEmpty) {
      return RemoteChangesPage(
        changes: const <RemoteChange>[],
        nextCursor: after,
        serverCursor: serverCursor,
        hasMore: false,
      );
    }
    final page = changesPages.removeAt(0);
    serverCursor = page.serverCursor;
    return page;
  }

  @override
  Future<List<PushResult>> push({
    required Uri endpoint,
    required String accessToken,
    required List<Map<String, Object?>> operations,
  }) async {
    pushedOperations = operations;
    final pushedChanges = <RemoteChange>[];
    for (final result in pushResults) {
      if (result.cursor > serverCursor) {
        serverCursor = result.cursor;
      }
      if ((result.status == 'applied' || result.status == 'duplicate') &&
          result.cursor > 0) {
        pushedChanges.add(
          RemoteChange(
            cursor: result.cursor,
            entityType: result.entityType,
            entityId: result.entityId,
            entityVersion: result.version,
            deleted: result.serverEntity == null,
            entity: result.serverEntity,
          ),
        );
      }
    }
    if (pushedChanges.isNotEmpty) {
      changesPages.add(
        RemoteChangesPage(
          changes: pushedChanges,
          nextCursor: pushedChanges.last.cursor,
          serverCursor: serverCursor,
          hasMore: false,
        ),
      );
    }
    return pushResults;
  }
}

class _FakeAccessTokenProvider implements AccessTokenProvider {
  const _FakeAccessTokenProvider();

  @override
  Future<String?> accessToken() async => 'access-token';
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<String> getOrCreateDeviceId() async => 'device-a';

  @override
  Future<AppPreferences> loadPreferences() async => const AppPreferences();

  @override
  Future<String?> readServiceEndpoint() async => 'http://127.0.0.1:8080';

  @override
  Future<void> savePreferences(AppPreferences preferences) async {}

  @override
  Future<void> saveServiceEndpoint(String? endpoint) async {}

  @override
  Stream<AppPreferences> watchPreferences() =>
      Stream<AppPreferences>.value(const AppPreferences());
}
