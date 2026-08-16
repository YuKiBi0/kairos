import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/app/providers.dart';
import 'package:kairos/domain/entities/app_preferences.dart';
import 'package:kairos/domain/entities/task.dart';
import 'package:kairos/domain/entities/taxonomy.dart';
import 'package:kairos/domain/repositories/settings_repository.dart';
import 'package:kairos/features/tasks/presentation/task_workspace_page.dart';

void main() {
  testWidgets(
    'compact workspace hides chrome but keeps the empty-list action',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await _pumpCompactWorkspace(tester, const <Task>[]);

        expect(find.text('现在最该推进什么'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('当前条件下没有任务'), findsOneWidget);
        expect(find.text('新建任务'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('compact workspace retains task card actions', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final task = Task.create(
        id: 'task-1',
        title: '精简模式任务',
        updatedByDeviceId: 'test-device',
        nowUtc: DateTime.utc(2026, 8, 16),
      );

      await _pumpCompactWorkspace(tester, <Task>[task]);

      expect(find.text('精简模式任务'), findsOneWidget);
      expect(find.byTooltip('完成任务'), findsOneWidget);
      expect(find.text('现在最该推进什么'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _pumpCompactWorkspace(
  WidgetTester tester,
  List<Task> tasks,
) async {
  final settings = _MemorySettingsRepository(
    const AppPreferences(compactWorkspace: true),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        tasksProvider.overrideWith((ref) => Stream<List<Task>>.value(tasks)),
        unresolvedBlockerCountsProvider.overrideWith(
          (ref) => Stream<Map<String, int>>.value(const <String, int>{}),
        ),
        tagsProvider.overrideWith(
          (ref) => Stream<List<Tag>>.value(const <Tag>[]),
        ),
        projectsProvider.overrideWith(
          (ref) => Stream<List<Project>>.value(const <Project>[]),
        ),
        checklistGroupsProvider.overrideWith(
          (ref) => Stream<List<ChecklistGroup>>.value(const <ChecklistGroup>[]),
        ),
        workspaceControllerProvider.overrideWith(
          (ref) => WorkspaceController(settings),
        ),
      ],
      child: const MaterialApp(home: TaskWorkspacePage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(this.preferences);

  AppPreferences preferences;

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<AppPreferences> loadPreferences() async => preferences;

  @override
  Future<String?> readServiceEndpoint() async => null;

  @override
  Future<void> savePreferences(AppPreferences preferences) async {
    this.preferences = preferences;
  }

  @override
  Future<void> saveServiceEndpoint(String? endpoint) async {}

  @override
  Stream<AppPreferences> watchPreferences() =>
      Stream<AppPreferences>.value(preferences);
}
