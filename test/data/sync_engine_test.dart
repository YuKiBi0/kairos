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
        hasMore: false,
      ),
    ];

    await expectLater(engine.synchronize(), throwsA(anything));
    final state = await database.select(database.syncStates).getSingle();
    final tasks = await database.select(database.localTasks).get();

    expect(state.serverCursor, 0);
    expect(tasks, isEmpty);
  });
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

  @override
  Future<Map<String, dynamic>> snapshot({
    required Uri endpoint,
    required String accessToken,
  }) async => snapshotResponse;

  @override
  Future<RemoteChangesPage> changes({
    required Uri endpoint,
    required String accessToken,
    required int after,
    int limit = 200,
  }) async {
    if (changesPages.isEmpty) {
      return RemoteChangesPage(
        changes: const <RemoteChange>[],
        nextCursor: after,
        hasMore: false,
      );
    }
    return changesPages.removeAt(0);
  }

  @override
  Future<List<PushResult>> push({
    required Uri endpoint,
    required String accessToken,
    required List<Map<String, Object?>> operations,
  }) async {
    pushedOperations = operations;
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
