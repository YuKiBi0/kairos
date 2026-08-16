import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/app/providers.dart';
import 'package:kairos/domain/entities/task.dart';
import 'package:kairos/domain/entities/taxonomy.dart';
import 'package:kairos/features/tasks/presentation/task_editor_dialog.dart';

void main() {
  testWidgets('saves status and taxonomy selections on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 16, 8);
    final tag = Tag(id: 'tag-a', name: '工作', updatedAtUtc: now);
    final project = Project(id: 'project-a', name: '发布', updatedAtUtc: now);
    final group = ChecklistGroup(id: 'group-a', name: '本周', updatedAtUtc: now);
    TaskDraft? saved;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[tag])),
          projectsProvider.overrideWith(
            (ref) => Stream.value(<Project>[project]),
          ),
          checklistGroupsProvider.overrideWith(
            (ref) => Stream.value(<ChecklistGroup>[group]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  saved = await showDialog<TaskDraft>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const TaskEditorDialog(),
                  );
                },
                child: const Text('打开编辑器'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '标题'), '准备发布');

    await tester.tap(find.text('工作'));
    await tester.tap(find.text(TaskStatus.notStarted.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TaskStatus.inProgress.label).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('无项目'));
    await tester.pump();
    await tester.tap(find.text('无项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('无清单分组'));
    await tester.pump();
    await tester.tap(find.text('无清单分组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本周').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, '准备发布');
    expect(saved!.status, TaskStatus.inProgress);
    expect(saved!.tagIds, <String>{tag.id});
    expect(saved!.projectId, project.id);
    expect(saved!.checklistGroupId, group.id);
    expect(tester.takeException(), isNull);
  });
}
