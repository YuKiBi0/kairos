import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/local/database.dart';
import 'package:kairos/data/repositories/local_metadata_repository.dart';
import 'package:kairos/data/repositories/local_task_repository.dart';

void main() {
  late AppDatabase database;
  late LocalTaskRepository tasks;
  late LocalMetadataRepository metadata;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tasks = LocalTaskRepository(database);
    metadata = LocalMetadataRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'adds, resolves, restores and deletes blockers through outbox',
    () async {
      final task = await tasks.createTask(title: 'Task', deviceId: 'device-a');
      final blocker = await metadata.addBlocker(task.id, 'Waiting for review');
      final resolved = await metadata.setBlockerResolved(
        blocker.id,
        resolved: true,
      );
      final restored = await metadata.setBlockerResolved(
        blocker.id,
        resolved: false,
      );
      await metadata.deleteBlocker(blocker.id);

      expect(resolved.resolvedAtUtc, isNotNull);
      expect(restored.resolvedAtUtc, isNull);
      expect(await metadata.watchBlockers(task.id).first, isEmpty);
      expect(
        await database.select(database.outboxOperations).get(),
        hasLength(5),
      );
    },
  );

  test('creates, renames and deletes tag without deleting its task', () async {
    final tag = await metadata.createTag('Work', colorToken: 'moss');
    final task = await tasks.createTask(
      title: 'Tagged task',
      deviceId: 'device-a',
      tagIds: <String>{tag.id},
    );

    final renamed = await metadata.renameTag(tag.id, 'Deep work');
    await metadata.deleteTag(tag.id);

    expect(renamed.name, 'Deep work');
    expect(await tasks.getTask(task.id), isNotNull);
    expect((await tasks.getTask(task.id))!.tagIds, isEmpty);
    expect((await metadata.watchTags().first).single.archived, isTrue);
  });

  test('creates, renames and archives projects and checklist groups', () async {
    final project = await metadata.createProject('Kairos');
    final renamedProject = await metadata.renameProject(
      project.id,
      'Kairos MVP',
    );
    final archivedProject = await metadata.setProjectArchived(
      project.id,
      archived: true,
    );
    final group = await metadata.createChecklistGroup('Release');
    final renamedGroup = await metadata.renameChecklistGroup(
      group.id,
      'Launch',
    );
    final archivedGroup = await metadata.setChecklistGroupArchived(
      group.id,
      archived: true,
    );

    expect(renamedProject.name, 'Kairos MVP');
    expect(archivedProject.archived, isTrue);
    expect(renamedGroup.name, 'Launch');
    expect(archivedGroup.archived, isTrue);
    expect((await metadata.watchProjects().first).single.name, 'Kairos MVP');
    expect((await metadata.watchChecklistGroups().first).single.name, 'Launch');
  });
}
