import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/settings_repository.dart';
import '../../features/sync/application/auth_controller.dart';
import '../local/database.dart';
import '../remote/kairos_api.dart';
import '../remote/remote_models.dart';

class SyncOutcome {
  const SyncOutcome({
    required this.pulled,
    required this.pushed,
    required this.conflicts,
    required this.pending,
    required this.cursor,
    required this.completedAtUtc,
  });

  final int pulled;
  final int pushed;
  final int conflicts;
  final int pending;
  final int cursor;
  final DateTime completedAtUtc;
}

enum SyncConflictResolution { keepLocal, useServer }

class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required KairosApi api,
    required AccessTokenProvider auth,
    required SettingsRepository settings,
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _api = api,
       _auth = auth,
       _settings = settings,
       _uuid = uuid;

  static const String _snapshotPreference = 'sync_snapshot_completed';

  final AppDatabase _database;
  final KairosApi _api;
  final AccessTokenProvider _auth;
  final SettingsRepository _settings;
  final Uuid _uuid;
  bool _running = false;

  Future<SyncOutcome> synchronize() async {
    if (_running) {
      throw StateError('A sync run is already active.');
    }
    _running = true;
    try {
      final endpointRaw = await _settings.readServiceEndpoint();
      final accessToken = await _auth.accessToken();
      if (endpointRaw == null || accessToken == null) {
        throw StateError('Sync service is not authenticated.');
      }
      final endpoint = Uri.parse(endpointRaw);
      await _ensureSyncState();
      var status = await _api.syncStatus(
        endpoint: endpoint,
        accessToken: accessToken,
      );
      final initialState = await _syncState();
      if (initialState.serverCursor > status.serverCursor ||
          !await _snapshotCompleted()) {
        await _refreshSnapshot(endpoint, accessToken);
      }
      var pulled = await _pullToCursor(
        endpoint,
        accessToken,
        status.serverCursor,
      );
      final push = await _push(endpoint, accessToken);
      status = await _api.syncStatus(
        endpoint: endpoint,
        accessToken: accessToken,
      );
      pulled += await _pullToCursor(endpoint, accessToken, status.serverCursor);
      final state = await _syncState();
      if (state.serverCursor < status.serverCursor) {
        throw StateError(
          'Sync stopped at cursor ${state.serverCursor} before '
          'server cursor ${status.serverCursor}.',
        );
      }
      return SyncOutcome(
        pulled: pulled,
        pushed: push.applied,
        conflicts: push.conflicts,
        pending: state.pendingCount,
        cursor: state.serverCursor,
        completedAtUtc: DateTime.now().toUtc(),
      );
    } finally {
      _running = false;
    }
  }

  Future<void> resolveConflict(
    SyncConflict conflict,
    SyncConflictResolution resolution,
  ) async {
    final serverEntity = jsonDecode(conflict.serverPayload);
    if (serverEntity is! Map<String, dynamic> || serverEntity.isEmpty) {
      throw const FormatException(
        'Conflict does not contain a server version.',
      );
    }
    final serverVersion = (serverEntity['version'] as num?)?.toInt();
    if (serverVersion == null) {
      throw const FormatException('Conflict server version is invalid.');
    }
    await _database.transaction(() async {
      switch (resolution) {
        case SyncConflictResolution.keepLocal:
          await _setLocalEntityVersion(
            conflict.entityType,
            conflict.entityId,
            serverVersion,
          );
          await (_database.update(_database.outboxOperations)..where(
                (table) =>
                    table.entityType.equals(conflict.entityType) &
                    table.entityId.equals(conflict.entityId),
              ))
              .write(
                OutboxOperationsCompanion(
                  baseVersion: Value<int>(serverVersion),
                  nextAttemptAtUtc: Value<DateTime>(DateTime.now().toUtc()),
                  lastError: const Value<String?>(null),
                ),
              );
        case SyncConflictResolution.useServer:
          await _applyEntity(
            conflict.entityType,
            serverEntity,
            deleted: false,
            force: true,
          );
          await (_database.delete(_database.outboxOperations)..where(
                (table) =>
                    table.entityType.equals(conflict.entityType) &
                    table.entityId.equals(conflict.entityId),
              ))
              .go();
      }
      await (_database.update(
        _database.syncConflicts,
      )..where((table) => table.id.equals(conflict.id))).write(
        SyncConflictsCompanion(
          resolvedAtUtc: Value<DateTime>(DateTime.now().toUtc()),
        ),
      );
      final pending = await _database.select(_database.outboxOperations).get();
      await (_database.update(_database.syncStates)
            ..where((table) => table.id.equals(1)))
          .write(SyncStatesCompanion(pendingCount: Value<int>(pending.length)));
    });
  }

  Future<void> _ensureSyncState() => _database
      .into(_database.syncStates)
      .insert(
        const SyncStatesCompanion(id: Value<int>(1)),
        mode: InsertMode.insertOrIgnore,
      );

  Future<SyncState> _syncState() => (_database.select(
    _database.syncStates,
  )..where((table) => table.id.equals(1))).getSingle();

  Future<bool> _snapshotCompleted() async {
    final row =
        await (_database.select(_database.localPreferences)
              ..where((table) => table.key.equals(_snapshotPreference)))
            .getSingleOrNull();
    return row?.value == 'true';
  }

  Future<void> _refreshSnapshot(Uri endpoint, String accessToken) async {
    final snapshot = await _api.snapshot(
      endpoint: endpoint,
      accessToken: accessToken,
    );
    await _applySnapshot(snapshot);
  }

  Future<void> _applySnapshot(Map<String, dynamic> snapshot) =>
      _database.transaction(() async {
        final tags = _entityList(snapshot, 'tags');
        final projects = _entityList(snapshot, 'projects');
        final checklistGroups = _entityList(snapshot, 'checklist_groups');
        final tasks = _entityList(snapshot, 'tasks');
        final blockers = _entityList(snapshot, 'blockers');
        for (final entity in tags) {
          await _applyEntity('tag', entity, deleted: false);
        }
        for (final entity in projects) {
          await _applyEntity('project', entity, deleted: false);
        }
        for (final entity in checklistGroups) {
          await _applyEntity('checklist_group', entity, deleted: false);
        }
        for (final entity in tasks) {
          await _applyEntity('task', entity, deleted: false);
        }
        for (final entity in blockers) {
          await _applyEntity('blocker', entity, deleted: false);
        }
        await _removeSnapshotOrphans(
          taskIds: _entityIds(tasks),
          blockerIds: _entityIds(blockers),
          tagIds: _entityIds(tags),
          projectIds: _entityIds(projects),
          checklistGroupIds: _entityIds(checklistGroups),
        );
        final cursor = (snapshot['cursor'] as num).toInt();
        await (_database.update(
          _database.syncStates,
        )..where((table) => table.id.equals(1))).write(
          SyncStatesCompanion(
            serverCursor: Value<int>(cursor),
            lastPullAtUtc: Value<DateTime>(DateTime.now().toUtc()),
          ),
        );
        await _database
            .into(_database.localPreferences)
            .insertOnConflictUpdate(
              LocalPreferencesCompanion.insert(
                key: _snapshotPreference,
                value: 'true',
              ),
            );
      });

  Future<void> _removeSnapshotOrphans({
    required Set<String> taskIds,
    required Set<String> blockerIds,
    required Set<String> tagIds,
    required Set<String> projectIds,
    required Set<String> checklistGroupIds,
  }) async {
    final outbox = await _database.select(_database.outboxOperations).get();
    final protected = <String>{
      for (final operation in outbox)
        '${operation.entityType}:${operation.entityId}',
    };

    final tasks = await _database.select(_database.localTasks).get();
    for (final task in tasks) {
      if (taskIds.contains(task.id) ||
          task.dirty ||
          protected.contains('task:${task.id}')) {
        continue;
      }
      await (_database.delete(
        _database.taskTags,
      )..where((table) => table.taskId.equals(task.id))).go();
      await (_database.delete(
        _database.localTasks,
      )..where((table) => table.id.equals(task.id))).go();
    }

    final blockers = await _database.select(_database.localBlockers).get();
    for (final blocker in blockers) {
      if (!blockerIds.contains(blocker.id) &&
          !protected.contains('blocker:${blocker.id}')) {
        await (_database.delete(
          _database.localBlockers,
        )..where((table) => table.id.equals(blocker.id))).go();
      }
    }

    final tags = await _database.select(_database.localTags).get();
    for (final tag in tags) {
      if (!tagIds.contains(tag.id) && !protected.contains('tag:${tag.id}')) {
        await (_database.delete(
          _database.taskTags,
        )..where((table) => table.tagId.equals(tag.id))).go();
        await (_database.delete(
          _database.localTags,
        )..where((table) => table.id.equals(tag.id))).go();
      }
    }

    final projects = await _database.select(_database.localProjects).get();
    for (final project in projects) {
      if (!projectIds.contains(project.id) &&
          !protected.contains('project:${project.id}')) {
        await (_database.delete(
          _database.localProjects,
        )..where((table) => table.id.equals(project.id))).go();
      }
    }

    final groups = await _database.select(_database.localChecklistGroups).get();
    for (final group in groups) {
      if (!checklistGroupIds.contains(group.id) &&
          !protected.contains('checklist_group:${group.id}')) {
        await (_database.delete(
          _database.localChecklistGroups,
        )..where((table) => table.id.equals(group.id))).go();
      }
    }
  }

  Future<int> _pullToCursor(
    Uri endpoint,
    String accessToken,
    int minimumCursor,
  ) async {
    try {
      return await _pull(endpoint, accessToken, minimumCursor);
    } on ApiFailure catch (error) {
      if (error.code != 'CURSOR_AHEAD') {
        rethrow;
      }
      await _refreshSnapshot(endpoint, accessToken);
      final status = await _api.syncStatus(
        endpoint: endpoint,
        accessToken: accessToken,
      );
      return _pull(endpoint, accessToken, status.serverCursor);
    }
  }

  Future<int> _pull(Uri endpoint, String accessToken, int minimumCursor) async {
    var cursor = (await _syncState()).serverCursor;
    var targetCursor = minimumCursor;
    var count = 0;
    while (true) {
      final page = await _api.changes(
        endpoint: endpoint,
        accessToken: accessToken,
        after: cursor,
      );
      _validateChangesPage(page, after: cursor);
      if (page.serverCursor > targetCursor) {
        targetCursor = page.serverCursor;
      }
      await _database.transaction(() async {
        for (final change in page.changes) {
          if (change.deleted) {
            await _applyTombstone(change);
          } else if (change.entity != null) {
            await _applyEntity(
              change.entityType,
              change.entity!,
              deleted: false,
            );
          }
        }
        await (_database.update(
          _database.syncStates,
        )..where((table) => table.id.equals(1))).write(
          SyncStatesCompanion(
            serverCursor: Value<int>(page.nextCursor),
            lastPullAtUtc: Value<DateTime>(DateTime.now().toUtc()),
          ),
        );
      });
      count += page.changes.length;
      cursor = page.nextCursor;
      if (!page.hasMore) {
        if (cursor < targetCursor) {
          throw StateError(
            'Sync cursor gap: page stopped at $cursor before '
            'server cursor $targetCursor.',
          );
        }
        return count;
      }
    }
  }

  void _validateChangesPage(RemoteChangesPage page, {required int after}) {
    if (page.serverCursor < after ||
        page.nextCursor < after ||
        page.nextCursor > page.serverCursor) {
      throw StateError(
        'Invalid sync cursor range: after=$after, '
        'next=${page.nextCursor}, server=${page.serverCursor}.',
      );
    }
    var previous = after;
    for (final change in page.changes) {
      if (change.cursor <= previous || change.cursor > page.nextCursor) {
        throw StateError(
          'Sync changes are not strictly ordered at cursor ${change.cursor}.',
        );
      }
      previous = change.cursor;
    }
    if (page.changes.isEmpty && page.nextCursor != after) {
      throw StateError('An empty sync page advanced the cursor.');
    }
    if (page.changes.isNotEmpty && previous != page.nextCursor) {
      throw StateError('Sync page cursor does not match its last change.');
    }
    if (page.hasMore && page.changes.isEmpty) {
      throw StateError('A paged sync response did not make progress.');
    }
  }

  Future<({int applied, int conflicts})> _push(
    Uri endpoint,
    String accessToken,
  ) async {
    var applied = 0;
    var conflicts = 0;
    while (true) {
      final now = DateTime.now().toUtc();
      final rows =
          await (_database.select(_database.outboxOperations)
                ..where(
                  (table) => table.nextAttemptAtUtc.isSmallerOrEqualValue(now),
                )
                ..orderBy(<OrderingTerm Function(OutboxOperations)>[
                  (table) => OrderingTerm.asc(table.createdAtUtc),
                ])
                ..limit(50))
              .get();
      if (rows.isEmpty) {
        break;
      }
      final operations = <Map<String, Object?>>[
        for (final row in rows) _operationPayload(row),
      ];
      final results = await _api.push(
        endpoint: endpoint,
        accessToken: accessToken,
        operations: operations,
      );
      await _database.transaction(() async {
        for (final result in results) {
          final row = rows.where(
            (candidate) => candidate.operationId == result.operationId,
          );
          if (row.isEmpty) {
            continue;
          }
          final operation = row.single;
          switch (result.status) {
            case 'applied' || 'duplicate':
              if (result.serverEntity != null) {
                await _applyEntity(
                  result.entityType,
                  result.serverEntity!,
                  deleted: false,
                  force: true,
                );
              }
              await (_database.delete(_database.outboxOperations)..where(
                    (table) => table.operationId.equals(result.operationId),
                  ))
                  .go();
              applied++;
            case 'conflict':
              await _recordConflict(operation, result);
              await _deferOperation(
                operation,
                'conflict',
                const Duration(days: 365),
              );
              conflicts++;
            default:
              await _deferOperation(
                operation,
                result.code ?? 'rejected',
                const Duration(days: 1),
              );
          }
        }
        final pending = await _database
            .select(_database.outboxOperations)
            .get();
        await (_database.update(
          _database.syncStates,
        )..where((table) => table.id.equals(1))).write(
          SyncStatesCompanion(
            pendingCount: Value<int>(pending.length),
            lastPushAtUtc: Value<DateTime>(DateTime.now().toUtc()),
          ),
        );
      });
      if (rows.length < 50) {
        break;
      }
    }
    return (applied: applied, conflicts: conflicts);
  }

  Map<String, Object?> _operationPayload(OutboxOperation row) {
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    return <String, Object?>{
      'operation_id': row.operationId,
      'entity_type': row.entityType,
      'entity_id': row.entityId,
      'base_version': row.baseVersion,
      if (payload['action'] != null) 'action': payload['action'],
      'changes': payload['changes'] ?? const <String, Object?>{},
      'changed_fields':
          payload['changed_fields'] ??
          ((payload['changes'] as Map<String, dynamic>?)?.keys.toList() ??
              const <String>[]),
    };
  }

  Future<void> _recordConflict(OutboxOperation operation, PushResult result) =>
      _database
          .into(_database.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: _uuid.v4(),
              entityType: operation.entityType,
              entityId: operation.entityId,
              localPayload: operation.payload,
              serverPayload: jsonEncode(
                result.serverEntity ?? const <String, Object?>{},
              ),
              conflictingFields: jsonEncode(result.conflictingFields),
              createdAtUtc: DateTime.now().toUtc(),
            ),
          );

  Future<void> _deferOperation(
    OutboxOperation operation,
    String error,
    Duration delay,
  ) =>
      (_database.update(_database.outboxOperations)
            ..where((table) => table.operationId.equals(operation.operationId)))
          .write(
            OutboxOperationsCompanion(
              attemptCount: Value<int>(operation.attemptCount + 1),
              nextAttemptAtUtc: Value<DateTime>(
                DateTime.now().toUtc().add(delay),
              ),
              lastError: Value<String>(error),
            ),
          );

  Future<void> _applyTombstone(RemoteChange change) async {
    final deletedAt = DateTime.now().toUtc();
    switch (change.entityType) {
      case 'task':
        await (_database.update(
          _database.localTasks,
        )..where((table) => table.id.equals(change.entityId))).write(
          LocalTasksCompanion(
            version: Value<int>(change.entityVersion),
            deletedAtUtc: Value<DateTime>(deletedAt),
            dirty: const Value<bool>(false),
          ),
        );
      case 'blocker':
        await (_database.update(
          _database.localBlockers,
        )..where((table) => table.id.equals(change.entityId))).write(
          LocalBlockersCompanion(
            version: Value<int>(change.entityVersion),
            deletedAtUtc: Value<DateTime>(deletedAt),
          ),
        );
      case 'tag':
        await (_database.update(
          _database.localTags,
        )..where((table) => table.id.equals(change.entityId))).write(
          LocalTagsCompanion(
            version: Value<int>(change.entityVersion),
            archived: const Value<bool>(true),
          ),
        );
        await (_database.delete(
          _database.taskTags,
        )..where((table) => table.tagId.equals(change.entityId))).go();
      case 'project':
        await (_database.update(
          _database.localProjects,
        )..where((table) => table.id.equals(change.entityId))).write(
          LocalProjectsCompanion(
            version: Value<int>(change.entityVersion),
            archived: const Value<bool>(true),
          ),
        );
      case 'checklist_group':
        await (_database.update(
          _database.localChecklistGroups,
        )..where((table) => table.id.equals(change.entityId))).write(
          LocalChecklistGroupsCompanion(
            version: Value<int>(change.entityVersion),
            archived: const Value<bool>(true),
          ),
        );
    }
  }

  Future<void> _setLocalEntityVersion(
    String entityType,
    String entityId,
    int version,
  ) => switch (entityType) {
    'task' =>
      (_database.update(_database.localTasks)
            ..where((table) => table.id.equals(entityId)))
          .write(LocalTasksCompanion(version: Value<int>(version))),
    'blocker' =>
      (_database.update(_database.localBlockers)
            ..where((table) => table.id.equals(entityId)))
          .write(LocalBlockersCompanion(version: Value<int>(version))),
    'tag' =>
      (_database.update(_database.localTags)
            ..where((table) => table.id.equals(entityId)))
          .write(LocalTagsCompanion(version: Value<int>(version))),
    'project' =>
      (_database.update(_database.localProjects)
            ..where((table) => table.id.equals(entityId)))
          .write(LocalProjectsCompanion(version: Value<int>(version))),
    'checklist_group' =>
      (_database.update(_database.localChecklistGroups)
            ..where((table) => table.id.equals(entityId)))
          .write(LocalChecklistGroupsCompanion(version: Value<int>(version))),
    _ => throw FormatException('Unsupported conflict entity: $entityType'),
  };

  Future<void> _applyEntity(
    String entityType,
    Map<String, dynamic> entity, {
    required bool deleted,
    bool force = false,
  }) => switch (entityType) {
    'task' => _applyTask(entity, force: force),
    'blocker' => _applyBlocker(entity),
    'tag' => _applyTag(entity),
    'project' => _applyProject(entity),
    'checklist_group' => _applyChecklistGroup(entity),
    _ => Future<void>.value(),
  };

  Future<void> _applyTask(
    Map<String, dynamic> entity, {
    required bool force,
  }) async {
    final id = entity['id'] as String;
    final current = await (_database.select(
      _database.localTasks,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    final version = (entity['version'] as num).toInt();
    if (!force && current?.dirty == true && current!.version != version) {
      await _database
          .into(_database.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: _uuid.v4(),
              entityType: 'task',
              entityId: id,
              localPayload: jsonEncode(current.toJson()),
              serverPayload: jsonEncode(entity),
              conflictingFields: jsonEncode(<String>['remote_entity']),
              createdAtUtc: DateTime.now().toUtc(),
            ),
          );
      return;
    }
    await _database
        .into(_database.localTasks)
        .insertOnConflictUpdate(
          LocalTasksCompanion.insert(
            id: id,
            title: entity['title'] as String,
            description: Value<String?>(entity['description'] as String?),
            quadrant: (entity['quadrant'] as num).toInt(),
            status: (entity['status'] as num).toInt(),
            dueAtUtc: Value<DateTime?>(_time(entity['due_at'])),
            parentId: Value<String?>(entity['parent_id'] as String?),
            depth: (entity['depth'] as num).toInt(),
            sortOrder: (entity['sort_order'] as num).toInt(),
            projectId: Value<String?>(entity['project_id'] as String?),
            checklistGroupId: Value<String?>(
              entity['checklist_group_id'] as String?,
            ),
            version: Value<int>(version),
            deletedAtUtc: Value<DateTime?>(_time(entity['deleted_at'])),
            createdAtUtc: _time(entity['created_at'])!,
            updatedAtUtc: _time(entity['updated_at'])!,
            completedAtUtc: Value<DateTime?>(_time(entity['completed_at'])),
            dirty: const Value<bool>(false),
            updatedByDeviceId: entity['updated_by_device_id'] as String,
          ),
        );
    await (_database.delete(
      _database.taskTags,
    )..where((table) => table.taskId.equals(id))).go();
    final tagIds = (entity['tag_ids'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>();
    await _database.batch((batch) {
      batch.insertAll(_database.taskTags, <TaskTagsCompanion>[
        for (final tagId in tagIds)
          TaskTagsCompanion.insert(taskId: id, tagId: tagId),
      ]);
    });
  }

  Future<void> _applyBlocker(Map<String, dynamic> entity) => _database
      .into(_database.localBlockers)
      .insertOnConflictUpdate(
        LocalBlockersCompanion.insert(
          id: entity['id'] as String,
          taskId: entity['task_id'] as String,
          body: entity['body'] as String,
          resolved: Value<bool>(entity['resolved'] as bool),
          resolvedAtUtc: Value<DateTime?>(_time(entity['resolved_at'])),
          version: Value<int>((entity['version'] as num).toInt()),
          deletedAtUtc: Value<DateTime?>(_time(entity['deleted_at'])),
          createdAtUtc: _time(entity['created_at'])!,
          updatedAtUtc: _time(entity['updated_at'])!,
        ),
      );

  Future<void> _applyTag(Map<String, dynamic> entity) => _database
      .into(_database.localTags)
      .insertOnConflictUpdate(
        LocalTagsCompanion.insert(
          id: entity['id'] as String,
          name: entity['name'] as String,
          colorToken: Value<String?>(entity['color_token'] as String?),
          archived: Value<bool>(entity['archived'] as bool),
          version: Value<int>((entity['version'] as num).toInt()),
          updatedAtUtc: _time(entity['updated_at'])!,
        ),
      );

  Future<void> _applyProject(Map<String, dynamic> entity) => _database
      .into(_database.localProjects)
      .insertOnConflictUpdate(
        LocalProjectsCompanion.insert(
          id: entity['id'] as String,
          name: entity['name'] as String,
          archived: Value<bool>(entity['archived'] as bool),
          version: Value<int>((entity['version'] as num).toInt()),
          updatedAtUtc: _time(entity['updated_at'])!,
        ),
      );

  Future<void> _applyChecklistGroup(Map<String, dynamic> entity) => _database
      .into(_database.localChecklistGroups)
      .insertOnConflictUpdate(
        LocalChecklistGroupsCompanion.insert(
          id: entity['id'] as String,
          name: entity['name'] as String,
          archived: Value<bool>(entity['archived'] as bool),
          version: Value<int>((entity['version'] as num).toInt()),
          updatedAtUtc: _time(entity['updated_at'])!,
        ),
      );

  List<Map<String, dynamic>> _entityList(
    Map<String, dynamic> source,
    String key,
  ) => (source[key] as List<dynamic>? ?? const <dynamic>[])
      .cast<Map<String, dynamic>>();

  Set<String> _entityIds(List<Map<String, dynamic>> entities) => <String>{
    for (final entity in entities) entity['id'] as String,
  };

  DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}
