import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/task.dart' as domain;
import '../../domain/repositories/task_repository.dart';
import '../../domain/services/task_tree_rules.dart';
import '../local/database.dart';
import '../local/outbox_writer.dart';
import '../mappers/task_mapper.dart';

class LocalTaskRepository implements TaskRepository {
  LocalTaskRepository(
    this._database, {
    Uuid uuid = const Uuid(),
    String Function()? entityIdGenerator,
    String Function()? operationIdGenerator,
    TaskMapper mapper = const TaskMapper(),
  }) : _entityIdGenerator = entityIdGenerator ?? uuid.v4,
       _mapper = mapper,
       _outbox = OutboxWriter(_database, operationIdGenerator ?? uuid.v4);

  final AppDatabase _database;
  final String Function() _entityIdGenerator;
  final TaskMapper _mapper;
  final OutboxWriter _outbox;

  @override
  Stream<List<domain.Task>> watchTasks() =>
      (_database.select(_database.localTasks)
            ..orderBy(<OrderingTerm Function(LocalTasks)>[
              (table) => OrderingTerm.asc(table.parentId),
              (table) => OrderingTerm.asc(table.sortOrder),
            ]))
          .watch()
          .asyncMap(_mapRows);

  @override
  Future<List<domain.Task>> getTasks() async {
    final rows = await _database.select(_database.localTasks).get();
    return _mapRows(rows);
  }

  @override
  Future<domain.Task?> getTask(String id) async {
    final row = await (_database.select(
      _database.localTasks,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.fromLocal(row, await _tagIdsFor(id));
  }

  @override
  Future<domain.Task> createTask({
    required String title,
    required String deviceId,
    String? description,
    domain.TaskQuadrant quadrant = domain.TaskQuadrant.importantNotUrgent,
    DateTime? dueAtUtc,
    String? parentId,
    Set<String> tagIds = const <String>{},
    String? projectId,
    String? checklistGroupId,
  }) => _database.transaction(() async {
    final nowUtc = DateTime.now().toUtc();
    final tasks = await getTasks();
    final depth = TaskTreeRules(tasks).depthForNewChild(parentId);
    final siblingOrders = tasks
        .where((task) => task.parentId == parentId && !task.isDeleted)
        .map((task) => task.sortOrder);
    final sortOrder = siblingOrders.isEmpty
        ? 0
        : siblingOrders.reduce((left, right) => left > right ? left : right) +
              1;
    final task = domain.Task.create(
      id: _entityIdGenerator(),
      title: title,
      description: description,
      quadrant: quadrant,
      dueAtUtc: dueAtUtc?.toUtc(),
      parentId: parentId,
      depth: depth,
      sortOrder: sortOrder,
      tagIds: tagIds,
      projectId: projectId,
      checklistGroupId: checklistGroupId,
      updatedByDeviceId: deviceId,
      nowUtc: nowUtc,
    );
    await _database.into(_database.localTasks).insert(_mapper.toLocal(task));
    await _replaceTagIds(task.id, task.tagIds);
    await _enqueue(
      task,
      changedFields: const <String>{
        'id',
        'title',
        'description',
        'quadrant',
        'status',
        'due_at',
        'parent_id',
        'depth',
        'sort_order',
        'tag_ids',
        'project_id',
        'checklist_group_id',
        'created_at',
        'updated_at',
        'completed_at',
        'updated_by_device_id',
      },
    );
    return task;
  });

  @override
  Future<domain.Task> saveTask(
    domain.Task task, {
    required Set<String> changedFields,
  }) => _database.transaction(() async {
    final existing = await getTask(task.id);
    if (existing == null) {
      throw StateError('Cannot update a task that does not exist.');
    }
    final nowUtc = DateTime.now().toUtc();
    var normalized = task.copyWith(updatedAtUtc: nowUtc, dirty: true);
    if (normalized.status.isCompleted && normalized.completedAtUtc == null) {
      normalized = normalized.copyWith(completedAtUtc: nowUtc);
    } else if (!normalized.status.isCompleted &&
        normalized.completedAtUtc != null) {
      normalized = normalized.copyWith(completedAtUtc: null);
    }
    final allFields = <String>{...changedFields, 'updated_at'};
    if (existing.status != normalized.status) {
      allFields.addAll(<String>{'status', 'completed_at'});
    }
    await (_database.update(_database.localTasks)
          ..where((table) => table.id.equals(normalized.id)))
        .write(_mapper.toLocal(normalized));
    if (changedFields.contains('tag_ids')) {
      await _replaceTagIds(normalized.id, normalized.tagIds);
    }
    await _enqueue(normalized, changedFields: allFields);
    return normalized;
  });

  @override
  Future<void> moveTask({
    required String taskId,
    required String? targetParentId,
    required int targetSortOrder,
    required DateTime nowUtc,
  }) => _database.transaction(() async {
    final original = await getTasks();
    final moved = TaskTreeRules(original).moveSubtree(
      taskId: taskId,
      targetParentId: targetParentId,
      targetSortOrder: targetSortOrder,
      nowUtc: nowUtc.toUtc(),
    );
    final before = <String, domain.Task>{
      for (final task in original) task.id: task,
    };
    for (final task in moved) {
      final previous = before[task.id]!;
      if (previous.parentId != task.parentId ||
          previous.depth != task.depth ||
          previous.sortOrder != task.sortOrder) {
        await (_database.update(_database.localTasks)
              ..where((table) => table.id.equals(task.id)))
            .write(_mapper.toLocal(task));
      }
    }
    final root = moved.singleWhere((task) => task.id == taskId);
    await _enqueue(
      root,
      changedFields: const <String>{
        'parent_id',
        'depth',
        'sort_order',
        'updated_at',
      },
    );
  });

  @override
  Future<void> softDeleteTask(String taskId, DateTime nowUtc) =>
      _setDeletedAt(taskId, nowUtc.toUtc());

  @override
  Future<void> restoreTask(String taskId, DateTime nowUtc) =>
      _setDeletedAt(taskId, null, updatedAtUtc: nowUtc.toUtc());

  Future<void> _setDeletedAt(
    String taskId,
    DateTime? deletedAtUtc, {
    DateTime? updatedAtUtc,
  }) => _database.transaction(() async {
    final task = await getTask(taskId);
    if (task == null) {
      throw StateError('Cannot delete or restore a task that does not exist.');
    }
    final changedAt = updatedAtUtc ?? deletedAtUtc ?? DateTime.now().toUtc();
    final updated = task.copyWith(
      deletedAtUtc: deletedAtUtc,
      updatedAtUtc: changedAt,
      dirty: true,
    );
    await (_database.update(_database.localTasks)
          ..where((table) => table.id.equals(updated.id)))
        .write(_mapper.toLocal(updated));
    await _enqueue(
      updated,
      changedFields: const <String>{'deleted_at', 'updated_at'},
    );
  });

  Future<List<domain.Task>> _mapRows(List<LocalTask> rows) async {
    final links = await _database.select(_database.taskTags).get();
    final tagsByTask = <String, Set<String>>{};
    for (final link in links) {
      tagsByTask.putIfAbsent(link.taskId, () => <String>{}).add(link.tagId);
    }
    return <domain.Task>[
      for (final row in rows)
        _mapper.fromLocal(row, tagsByTask[row.id] ?? const <String>{}),
    ];
  }

  Future<Set<String>> _tagIdsFor(String taskId) async {
    final rows = await (_database.select(
      _database.taskTags,
    )..where((table) => table.taskId.equals(taskId))).get();
    return rows.map((row) => row.tagId).toSet();
  }

  Future<void> _replaceTagIds(String taskId, Set<String> tagIds) async {
    await (_database.delete(
      _database.taskTags,
    )..where((table) => table.taskId.equals(taskId))).go();
    await _database.batch((batch) {
      batch.insertAll(_database.taskTags, <TaskTagsCompanion>[
        for (final tagId in tagIds)
          TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
      ]);
    });
  }

  Future<void> _enqueue(
    domain.Task task, {
    required Set<String> changedFields,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    await _outbox.enqueue(
      entityType: 'task',
      entityId: task.id,
      baseVersion: task.version,
      payload: <String, Object?>{
        'changes': _mapper.toWire(task, fields: changedFields),
        'changed_fields': changedFields.toList(growable: false)..sort(),
      },
      createdAtUtc: nowUtc,
    );
  }
}
