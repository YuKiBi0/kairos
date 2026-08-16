import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/local/database.dart';
import 'package:kairos/data/repositories/local_task_repository.dart';
import 'package:kairos/domain/entities/task.dart';

void main() {
  late AppDatabase database;
  late LocalTaskRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LocalTaskRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates task and outbox operation in one transaction', () async {
    final task = await repository.createTask(
      title: '完成 MVP',
      deviceId: 'windows-dev',
      tagIds: <String>{'important'},
    );

    final stored = await repository.getTask(task.id);
    final outbox = await database.select(database.outboxOperations).get();
    final syncState = await database.select(database.syncStates).getSingle();
    final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;

    expect(stored, isNotNull);
    expect(stored!.title, '完成 MVP');
    expect(stored.tagIds, <String>{'important'});
    expect(outbox, hasLength(1));
    expect(payload['changed_fields'], contains('title'));
    expect(syncState.pendingCount, 1);
  });

  test('rolls back entity when outbox insertion fails', () async {
    var entitySequence = 0;
    repository = LocalTaskRepository(
      database,
      entityIdGenerator: () => 'task-${entitySequence++}',
      operationIdGenerator: () => 'duplicate-operation',
    );

    await repository.createTask(title: 'First', deviceId: 'test-device');

    await expectLater(
      repository.createTask(title: 'Second', deviceId: 'test-device'),
      throwsA(anything),
    );
    final tasks = await repository.getTasks();
    final outbox = await database.select(database.outboxOperations).get();

    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'First');
    expect(outbox, hasLength(1));
  });

  test('moves subtree, completes, soft deletes and restores task', () async {
    final root = await repository.createTask(
      title: 'Root',
      deviceId: 'test-device',
    );
    final child = await repository.createTask(
      title: 'Child',
      deviceId: 'test-device',
      parentId: root.id,
    );
    final grandchild = await repository.createTask(
      title: 'Grandchild',
      deviceId: 'test-device',
      parentId: child.id,
    );

    await repository.moveTask(
      taskId: child.id,
      targetParentId: null,
      targetSortOrder: 1,
      nowUtc: DateTime.utc(2026, 8, 16, 9),
    );
    final movedGrandchild = await repository.getTask(grandchild.id);
    expect(movedGrandchild!.depth, 2);

    final completed = await repository.saveTask(
      child.copyWith(status: TaskStatus.completed),
      changedFields: const <String>{'status'},
    );
    expect(completed.completedAtUtc, isNotNull);

    final deletedAt = DateTime.utc(2026, 8, 16, 10);
    await repository.softDeleteTask(child.id, deletedAt);
    expect((await repository.getTask(child.id))!.deletedAtUtc, deletedAt);

    await repository.restoreTask(
      child.id,
      deletedAt.add(const Duration(minutes: 1)),
    );
    expect((await repository.getTask(child.id))!.deletedAtUtc, isNull);
  });

  test('queues normalized sibling order changes when reordering', () async {
    final first = await repository.createTask(
      title: 'First',
      deviceId: 'test-device',
    );
    final second = await repository.createTask(
      title: 'Second',
      deviceId: 'test-device',
    );
    final third = await repository.createTask(
      title: 'Third',
      deviceId: 'test-device',
    );
    await database.delete(database.outboxOperations).go();
    await (database.update(database.syncStates)
          ..where((table) => table.id.equals(1)))
        .write(const SyncStatesCompanion(pendingCount: Value<int>(0)));

    await repository.moveTask(
      taskId: third.id,
      targetParentId: null,
      targetSortOrder: 0,
      nowUtc: DateTime.utc(2026, 8, 16, 9),
    );

    final tasks = await repository.getTasks()
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    final outbox = await database.select(database.outboxOperations).get();
    expect(tasks.map((task) => task.id), <String>[
      third.id,
      first.id,
      second.id,
    ]);
    expect(outbox.map((operation) => operation.entityId).toSet(), <String>{
      first.id,
      second.id,
      third.id,
    });
    expect(outbox, hasLength(3));
  });
}
