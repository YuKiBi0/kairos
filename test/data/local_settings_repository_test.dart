import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/local/database.dart';
import 'package:kairos/data/repositories/local_settings_repository.dart';
import 'package:kairos/domain/entities/app_preferences.dart';
import 'package:kairos/domain/entities/task.dart';
import 'package:kairos/domain/entities/task_filter.dart';
import 'package:kairos/domain/services/task_sorter.dart';

void main() {
  late AppDatabase database;
  late LocalSettingsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LocalSettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'persists view, sort, scope, search and always-on-top preferences',
    () async {
      const expected = AppPreferences(
        viewMode: TaskViewMode.quadrant,
        sortMode: TaskSortMode.dueDate,
        scope: TaskScope.today,
        searchText: 'report',
        alwaysOnTop: true,
        quadrants: <TaskQuadrant>{TaskQuadrant.importantUrgent},
        statuses: <TaskStatus>{TaskStatus.inProgress},
        dueDateFilter: DueDateFilter.withDueDate,
        hasUnresolvedBlockers: true,
        tagIds: <String>{'tag-a', 'tag-b'},
        projectId: 'project-a',
        checklistGroupId: 'group-a',
      );

      await repository.savePreferences(expected);
      final actual = await repository.loadPreferences();

      expect(actual.viewMode, expected.viewMode);
      expect(actual.sortMode, expected.sortMode);
      expect(actual.scope, expected.scope);
      expect(actual.searchText, expected.searchText);
      expect(actual.alwaysOnTop, isTrue);
      expect(actual.quadrants, expected.quadrants);
      expect(actual.statuses, expected.statuses);
      expect(actual.dueDateFilter, expected.dueDateFilter);
      expect(actual.hasUnresolvedBlockers, isTrue);
      expect(actual.tagIds, expected.tagIds);
      expect(actual.projectId, expected.projectId);
      expect(actual.checklistGroupId, expected.checklistGroupId);
    },
  );

  test('creates a stable local device id', () async {
    final first = await repository.getOrCreateDeviceId();
    final second = await repository.getOrCreateDeviceId();

    expect(first, isNotEmpty);
    expect(second, first);
  });

  test(
    'stores only an absolute service endpoint and supports clearing it',
    () async {
      await repository.saveServiceEndpoint('https://kairos.example.com');
      expect(
        await repository.readServiceEndpoint(),
        'https://kairos.example.com',
      );

      await expectLater(
        repository.saveServiceEndpoint('not a url'),
        throwsFormatException,
      );
      await expectLater(
        repository.saveServiceEndpoint(
          'https://owner:secret@kairos.example.com?token=hidden',
        ),
        throwsFormatException,
      );
      await expectLater(
        repository.saveServiceEndpoint('ftp://kairos.example.com'),
        throwsFormatException,
      );
      await repository.saveServiceEndpoint(null);
      expect(await repository.readServiceEndpoint(), isNull);
    },
  );
}
