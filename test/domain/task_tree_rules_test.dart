import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/domain/entities/task.dart';
import 'package:kairos/domain/services/task_tree_rules.dart';

void main() {
  final now = DateTime.utc(2026, 8, 16, 8);

  Task task(
    String id, {
    String? parentId,
    int depth = 1,
    int sortOrder = 0,
    TaskStatus status = TaskStatus.notStarted,
  }) => Task(
    id: id,
    title: 'Task $id',
    quadrant: TaskQuadrant.importantNotUrgent,
    status: status,
    parentId: parentId,
    depth: depth,
    sortOrder: sortOrder,
    createdAtUtc: now,
    updatedAtUtc: now,
    updatedByDeviceId: 'device-a',
  );

  group('TaskTreeRules', () {
    test('calculates child depth and rejects a sixth level', () {
      final tasks = <Task>[
        task('1'),
        task('2', parentId: '1', depth: 2),
        task('3', parentId: '2', depth: 3),
        task('4', parentId: '3', depth: 4),
        task('5', parentId: '4', depth: 5),
      ];
      final rules = TaskTreeRules(tasks);

      expect(rules.depthForNewChild('4'), 5);
      expect(
        () => rules.depthForNewChild('5'),
        throwsA(
          isA<TaskTreeViolation>().having(
            (error) => error.code,
            'code',
            TaskTreeViolationCode.depthLimit,
          ),
        ),
      );
    });

    test('rejects moving a task below its descendant', () {
      final rules = TaskTreeRules(<Task>[
        task('root'),
        task('child', parentId: 'root', depth: 2),
      ]);

      expect(
        () => rules.moveSubtree(
          taskId: 'root',
          targetParentId: 'child',
          targetSortOrder: 0,
          nowUtc: now.add(const Duration(minutes: 1)),
        ),
        throwsA(
          isA<TaskTreeViolation>().having(
            (error) => error.code,
            'code',
            TaskTreeViolationCode.cycle,
          ),
        ),
      );
    });

    test('rejects a move when the subtree would exceed five levels', () {
      final rules = TaskTreeRules(<Task>[
        task('destination'),
        task('d2', parentId: 'destination', depth: 2),
        task('d3', parentId: 'd2', depth: 3),
        task('source'),
        task('s2', parentId: 'source', depth: 2),
        task('s3', parentId: 's2', depth: 3),
        task('s4', parentId: 's3', depth: 4),
      ]);

      expect(
        () => rules.moveSubtree(
          taskId: 'source',
          targetParentId: 'd3',
          targetSortOrder: 0,
          nowUtc: now.add(const Duration(minutes: 1)),
        ),
        throwsA(
          isA<TaskTreeViolation>().having(
            (error) => error.code,
            'code',
            TaskTreeViolationCode.depthLimit,
          ),
        ),
      );
    });

    test('moves an entire subtree and updates descendant depths', () {
      final movedAt = now.add(const Duration(minutes: 1));
      final rules = TaskTreeRules(<Task>[
        task('root-a'),
        task('root-b'),
        task('child', parentId: 'root-a', depth: 2),
        task('grandchild', parentId: 'child', depth: 3),
      ]);

      final moved = rules.moveSubtree(
        taskId: 'child',
        targetParentId: null,
        targetSortOrder: 1,
        nowUtc: movedAt,
      );
      final byId = <String, Task>{for (final item in moved) item.id: item};

      expect(byId['child']!.parentId, isNull);
      expect(byId['child']!.depth, 1);
      expect(byId['grandchild']!.depth, 2);
      expect(byId['child']!.updatedAtUtc, movedAt);
      expect(byId['grandchild']!.dirty, isTrue);
    });

    test('inserts a moved sibling at the requested normalized index', () {
      final moved =
          TaskTreeRules(<Task>[
            task('a', sortOrder: 0),
            task('b', sortOrder: 1),
            task('c', sortOrder: 2),
          ]).moveSubtree(
            taskId: 'c',
            targetParentId: null,
            targetSortOrder: 0,
            nowUtc: now.add(const Duration(minutes: 1)),
          );
      final ordered = moved.where((item) => item.parentId == null).toList()
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

      expect(ordered.map((item) => item.id), <String>['c', 'a', 'b']);
      expect(ordered.map((item) => item.sortOrder), <int>[0, 1, 2]);
    });

    test(
      'calculates recursive descendant progress without completing parent',
      () {
        final rules = TaskTreeRules(<Task>[
          task('root'),
          task('a', parentId: 'root', depth: 2, status: TaskStatus.completed),
          task('b', parentId: 'root', depth: 2),
          task('c', parentId: 'b', depth: 3, status: TaskStatus.completed),
        ]);

        final progress = rules.progressFor('root');

        expect(progress.completed, 2);
        expect(progress.total, 3);
        expect(progress.ratio, closeTo(2 / 3, 0.0001));
      },
    );
  });
}
