import '../entities/task.dart';
import '../entities/task_filter.dart';

enum TaskSortMode {
  executionPriority,
  dueDate,
  recentlyUpdated,
  createdAt,
  manual,
}

enum DueBucket { overdue, today, nextThreeDays, later, none }

class TaskSorter {
  const TaskSorter();

  List<TaskListItem> sort(
    Iterable<TaskListItem> source, {
    required TaskSortMode mode,
    required DateTime now,
  }) {
    final result = source.toList(growable: false);
    result.sort((left, right) => _compare(left.task, right.task, mode, now));
    return result;
  }

  DueBucket dueBucket(Task task, DateTime now) {
    final due = task.dueAtUtc?.toLocal();
    if (due == null) {
      return DueBucket.none;
    }
    final localNow = now.toLocal();
    if (due.isBefore(localNow)) {
      return DueBucket.overdue;
    }
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final dayDifference = dueDay.difference(today).inDays;
    if (dayDifference == 0) {
      return DueBucket.today;
    }
    if (dayDifference <= 3) {
      return DueBucket.nextThreeDays;
    }
    return DueBucket.later;
  }

  int _compare(Task left, Task right, TaskSortMode mode, DateTime now) {
    final completion = _compareCompleted(left, right);
    if (completion != 0) {
      return completion;
    }

    final primary = switch (mode) {
      TaskSortMode.executionPriority => _compareExecution(left, right, now),
      TaskSortMode.dueDate => _compareNullableDate(
        left.dueAtUtc,
        right.dueAtUtc,
      ),
      TaskSortMode.recentlyUpdated => right.updatedAtUtc.compareTo(
        left.updatedAtUtc,
      ),
      TaskSortMode.createdAt => right.createdAtUtc.compareTo(left.createdAtUtc),
      TaskSortMode.manual => _compareManual(left, right),
    };
    if (primary != 0) {
      return primary;
    }
    return left.id.compareTo(right.id);
  }

  int _compareCompleted(Task left, Task right) {
    final leftCompleted = left.status.isCompleted ? 1 : 0;
    final rightCompleted = right.status.isCompleted ? 1 : 0;
    return leftCompleted.compareTo(rightCompleted);
  }

  int _compareExecution(Task left, Task right, DateTime now) {
    final bucket = dueBucket(
      left,
      now,
    ).index.compareTo(dueBucket(right, now).index);
    if (bucket != 0) {
      return bucket;
    }
    final quadrant = left.quadrant.code.compareTo(right.quadrant.code);
    if (quadrant != 0) {
      return quadrant;
    }
    final status = left.status.code.compareTo(right.status.code);
    if (status != 0) {
      return status;
    }
    final due = _compareNullableDate(left.dueAtUtc, right.dueAtUtc);
    if (due != 0) {
      return due;
    }
    return right.updatedAtUtc.compareTo(left.updatedAtUtc);
  }

  int _compareManual(Task left, Task right) {
    final parent = (left.parentId ?? '').compareTo(right.parentId ?? '');
    if (parent != 0) {
      return parent;
    }
    return left.sortOrder.compareTo(right.sortOrder);
  }

  int _compareNullableDate(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left.compareTo(right);
  }
}
