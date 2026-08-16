import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/export/json_export_service.dart';
import 'package:kairos/data/local/database.dart';
import 'package:kairos/data/repositories/local_metadata_repository.dart';
import 'package:kairos/data/repositories/local_task_repository.dart';

void main() {
  late AppDatabase database;
  late Directory exportDirectory;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    exportDirectory = await Directory.systemTemp.createTemp(
      'kairos-export-test-',
    );
  });

  tearDown(() async {
    await database.close();
    if (await exportDirectory.exists()) {
      await exportDirectory.delete(recursive: true);
    }
  });

  test(
    'exports business entities without credentials or sync internals',
    () async {
      final metadata = LocalMetadataRepository(database);
      final tasks = LocalTaskRepository(database);
      final tag = await metadata.createTag('工作');
      final project = await metadata.createProject('发布');
      final group = await metadata.createChecklistGroup('本周');
      final task = await tasks.createTask(
        title: '导出任务',
        description: '只包含业务数据',
        deviceId: 'device-a',
        tagIds: <String>{tag.id},
        projectId: project.id,
        checklistGroupId: group.id,
      );
      await metadata.addBlocker(task.id, '等待确认');
      final service = JsonExportService(
        database: database,
        directoryProvider: () async => exportDirectory,
        now: () => DateTime.utc(2026, 8, 16, 9, 30),
      );

      final result = await service.export();
      final exported =
          jsonDecode(await File(result.filePath).readAsString())
              as Map<String, dynamic>;

      expect(result.taskCount, 1);
      expect(result.blockerCount, 1);
      expect(exported['format'], 'kairos-export');
      expect(exported['tasks'], hasLength(1));
      expect(exported['blockers'], hasLength(1));
      expect(exported['tags'], hasLength(1));
      expect(exported['projects'], hasLength(1));
      expect(exported['checklist_groups'], hasLength(1));
      expect(
        ((exported['tasks'] as List<dynamic>).single
            as Map<String, dynamic>)['tag_ids'],
        <String>[tag.id],
      );
      expect(exported, isNot(contains('credentials')));
      expect(exported, isNot(contains('outbox_operations')));
      expect(exported, isNot(contains('sync_conflicts')));
      expect(exported, isNot(contains('local_preferences')));
    },
  );
}
