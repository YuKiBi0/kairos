import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/local/database.dart';
import 'package:kairos/data/repositories/local_settings_repository.dart';
import 'package:kairos/domain/entities/app_preferences.dart';
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
      );

      await repository.savePreferences(expected);
      final actual = await repository.loadPreferences();

      expect(actual.viewMode, expected.viewMode);
      expect(actual.sortMode, expected.sortMode);
      expect(actual.scope, expected.scope);
      expect(actual.searchText, expected.searchText);
      expect(actual.alwaysOnTop, isTrue);
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
      await repository.saveServiceEndpoint(null);
      expect(await repository.readServiceEndpoint(), isNull);
    },
  );
}
