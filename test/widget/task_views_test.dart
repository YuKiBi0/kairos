import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/app/theme/organic_theme.dart';
import 'package:kairos/domain/entities/task.dart';
import 'package:kairos/domain/entities/task_filter.dart';
import 'package:kairos/features/tasks/presentation/widgets/task_card.dart';
import 'package:kairos/features/tasks/presentation/widgets/task_views.dart';

void main() {
  final now = DateTime.utc(2026, 8, 16, 8);

  TaskListItem item(
    String id,
    TaskQuadrant quadrant, {
    int blockers = 0,
    int descendants = 0,
  }) => TaskListItem(
    task: Task(
      id: id,
      title: '任务 $id',
      quadrant: quadrant,
      status: TaskStatus.inProgress,
      dueAtUtc: now.add(const Duration(hours: 2)),
      depth: 1,
      sortOrder: quadrant.code,
      createdAtUtc: now,
      updatedAtUtc: now,
      updatedByDeviceId: 'test-device',
    ),
    completedDescendantCount: descendants == 0 ? 0 : 1,
    totalDescendantCount: descendants,
    unresolvedBlockerCount: blockers,
    tagNames: const <String>['工作'],
    projectName: '发布',
    checklistGroupName: '本周',
  );

  testWidgets('task card shows required summary and handles completion', (
    tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: OrganicTheme.light,
        home: Scaffold(
          body: TaskCard(
            item: item(
              'sync',
              TaskQuadrant.importantUrgent,
              blockers: 2,
              descendants: 4,
            ),
            onToggleCompleted: () => toggled = true,
            onOpen: () {},
            onMenuRequested: () {},
          ),
        ),
      ),
    );

    expect(find.text('任务 sync'), findsOneWidget);
    expect(find.text('Q1 重要且紧急'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('困难点 2'), findsOneWidget);
    expect(find.text('待同步'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('发布'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);

    await tester.tap(find.byTooltip('完成任务'));
    expect(toggled, isTrue);
  });

  testWidgets('quadrant view keeps all four named sections on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OrganicTheme.light,
        home: Scaffold(
          body: QuadrantTaskView(
            items: <TaskListItem>[
              for (final quadrant in TaskQuadrant.values)
                item('${quadrant.code}', quadrant),
            ],
            onToggle: (_) {},
            onOpen: (_) {},
            onMenu: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('quadrant-section-1')), findsOne);
    expect(find.text('Q1 重要且紧急'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(0, -720));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('quadrant-section-4')), findsOne);
    expect(find.text('Q4 不重要不紧急'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
