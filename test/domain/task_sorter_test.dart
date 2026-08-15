import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/domain/entities/task.dart';
import 'package:kairos/domain/entities/task_filter.dart';
import 'package:kairos/domain/services/task_sorter.dart';

void main() {
  final now = DateTime.utc(2026, 8, 16, 8);

  TaskListItem item(
    String id, {
    DateTime? dueAtUtc,
    TaskQuadrant quadrant = TaskQuadrant.importantNotUrgent,
    TaskStatus status = TaskStatus.notStarted,
    DateTime? updatedAtUtc,
    Set<String> tagIds = const <String>{},
    String? description,
    int unresolvedBlockerCount = 0,
  }) => TaskListItem(
    task: Task(
      id: id,
      title: 'Task $id',
      description: description,
      quadrant: quadrant,
      status: status,
      dueAtUtc: dueAtUtc,
      depth: 1,
      sortOrder: 0,
      tagIds: tagIds,
      createdAtUtc: now,
      updatedAtUtc: updatedAtUtc ?? now,
      updatedByDeviceId: 'device-a',
    ),
    unresolvedBlockerCount: unresolvedBlockerCount,
  );

  group('TaskSorter', () {
    test('sorts by due bucket, quadrant, and keeps completed tasks last', () {
      final source = <TaskListItem>[
        item('none'),
        item('today-q2', dueAtUtc: now.add(const Duration(hours: 4))),
        item(
          'overdue-q4',
          dueAtUtc: now.subtract(const Duration(minutes: 1)),
          quadrant: TaskQuadrant.notImportantNotUrgent,
        ),
        item(
          'overdue-q1',
          dueAtUtc: now.subtract(const Duration(days: 1)),
          quadrant: TaskQuadrant.importantUrgent,
        ),
        item(
          'completed-overdue',
          dueAtUtc: now.subtract(const Duration(days: 2)),
          status: TaskStatus.completed,
        ),
      ];

      final sorted = const TaskSorter().sort(
        source,
        mode: TaskSortMode.executionPriority,
        now: now,
      );

      expect(sorted.map((entry) => entry.task.id), <String>[
        'overdue-q1',
        'overdue-q4',
        'today-q2',
        'none',
        'completed-overdue',
      ]);
    });

    test('puts null deadlines last in deadline sorting', () {
      final sorted = const TaskSorter().sort(
        <TaskListItem>[
          item('none'),
          item('later', dueAtUtc: now.add(const Duration(days: 2))),
          item('sooner', dueAtUtc: now.add(const Duration(days: 1))),
        ],
        mode: TaskSortMode.dueDate,
        now: now,
      );

      expect(sorted.map((entry) => entry.task.id), <String>[
        'sooner',
        'later',
        'none',
      ]);
    });
  });

  group('TaskFilter', () {
    test('combines search, quadrant, tag, due date and blocker filters', () {
      final filter = TaskFilter(
        searchText: '报告',
        quadrants: <TaskQuadrant>{TaskQuadrant.importantUrgent},
        dueDate: DueDateFilter.withDueDate,
        hasUnresolvedBlockers: true,
        tagIds: <String>{'work'},
      );
      final matching = item(
        'match',
        description: '完成年度报告',
        quadrant: TaskQuadrant.importantUrgent,
        dueAtUtc: now.add(const Duration(days: 1)),
        tagIds: <String>{'work'},
        unresolvedBlockerCount: 1,
      );
      final noBlocker = item(
        'no-blocker',
        description: '完成年度报告',
        quadrant: TaskQuadrant.importantUrgent,
        dueAtUtc: now.add(const Duration(days: 1)),
        tagIds: <String>{'work'},
      );

      expect(filter.matches(matching), isTrue);
      expect(filter.matches(noBlocker), isFalse);
    });
  });

  test('task title is trimmed and constrained to 200 Unicode scalars', () {
    final created = Task.create(
      id: 'one',
      title: '  完成报告  ',
      updatedByDeviceId: 'device-a',
      nowUtc: now,
    );

    expect(created.title, '完成报告');
    expect(
      () => Task.create(
        id: 'empty',
        title: '   ',
        updatedByDeviceId: 'device-a',
        nowUtc: now,
      ),
      throwsFormatException,
    );
    expect(
      () => Task.create(
        id: 'long',
        title: List<String>.filled(201, '任').join(),
        updatedByDeviceId: 'device-a',
        nowUtc: now,
      ),
      throwsFormatException,
    );
  });
}
