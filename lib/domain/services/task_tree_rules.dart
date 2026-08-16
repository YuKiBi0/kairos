import '../entities/task.dart';

enum TaskTreeViolationCode { missingTask, missingParent, cycle, depthLimit }

class TaskTreeViolation implements Exception {
  const TaskTreeViolation(this.code, this.message);

  final TaskTreeViolationCode code;
  final String message;

  @override
  String toString() => 'TaskTreeViolation(${code.name}): $message';
}

class TaskProgress {
  const TaskProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  double get ratio => total == 0 ? 0 : completed / total;
}

class TaskTreeRules {
  TaskTreeRules(Iterable<Task> tasks)
    : _tasks = <String, Task>{for (final task in tasks) task.id: task};

  static const int maximumDepth = 5;

  final Map<String, Task> _tasks;

  int depthForNewChild(String? parentId) {
    if (parentId == null) {
      return 1;
    }
    final parent = _tasks[parentId];
    if (parent == null || parent.isDeleted) {
      throw const TaskTreeViolation(
        TaskTreeViolationCode.missingParent,
        'The selected parent task does not exist.',
      );
    }
    final depth = parent.depth + 1;
    if (depth > maximumDepth) {
      throw const TaskTreeViolation(
        TaskTreeViolationCode.depthLimit,
        'Tasks can contain at most five levels.',
      );
    }
    return depth;
  }

  List<Task> moveSubtree({
    required String taskId,
    required String? targetParentId,
    required int targetSortOrder,
    required DateTime nowUtc,
  }) {
    final task = _tasks[taskId];
    if (task == null || task.isDeleted) {
      throw const TaskTreeViolation(
        TaskTreeViolationCode.missingTask,
        'The task to move does not exist.',
      );
    }
    if (targetParentId == taskId ||
        (targetParentId != null &&
            _descendantIds(taskId).contains(targetParentId))) {
      throw const TaskTreeViolation(
        TaskTreeViolationCode.cycle,
        'A task cannot be moved below itself or one of its descendants.',
      );
    }

    final targetDepth = depthForNewChild(targetParentId);
    final subtreeHeight = _subtreeHeight(taskId);
    if (targetDepth + subtreeHeight - 1 > maximumDepth) {
      throw const TaskTreeViolation(
        TaskTreeViolationCode.depthLimit,
        'Moving this subtree would exceed the five-level limit.',
      );
    }

    final depthDelta = targetDepth - task.depth;
    final descendants = _descendantIds(taskId);
    final movedIds = <String>{taskId, ...descendants};
    final updated = <Task>[];
    for (final current in _tasks.values) {
      if (!movedIds.contains(current.id)) {
        updated.add(current);
        continue;
      }
      updated.add(
        current.copyWith(
          parentId: current.id == taskId ? targetParentId : current.parentId,
          depth: current.depth + depthDelta,
          sortOrder: current.id == taskId ? targetSortOrder : current.sortOrder,
          updatedAtUtc: nowUtc,
          dirty: true,
        ),
      );
    }
    final targetSiblings =
        updated
            .where(
              (current) =>
                  current.parentId == targetParentId && current.id != taskId,
            )
            .toList()
          ..sort((left, right) {
            final order = left.sortOrder.compareTo(right.sortOrder);
            return order != 0 ? order : left.id.compareTo(right.id);
          });
    final movedRootIndex = updated.indexWhere(
      (current) => current.id == taskId,
    );
    final movedRoot = updated.removeAt(movedRootIndex);
    targetSiblings.insert(
      targetSortOrder.clamp(0, targetSiblings.length),
      movedRoot,
    );
    final orderedTargets = <String, Task>{
      for (var index = 0; index < targetSiblings.length; index++)
        targetSiblings[index].id: targetSiblings[index].copyWith(
          sortOrder: index,
          updatedAtUtc: nowUtc,
          dirty: true,
        ),
    };
    updated.addAll(
      orderedTargets.values.where((current) => current.id == taskId),
    );
    for (var index = 0; index < updated.length; index++) {
      final ordered = orderedTargets[updated[index].id];
      if (ordered != null) {
        updated[index] = ordered;
      }
    }
    return _normalizeSiblings(updated, nowUtc);
  }

  TaskProgress progressFor(String taskId) {
    if (!_tasks.containsKey(taskId)) {
      throw const TaskTreeViolation(
        TaskTreeViolationCode.missingTask,
        'The task does not exist.',
      );
    }
    final descendants = _descendantIds(taskId)
        .map((id) => _tasks[id]!)
        .where((task) => !task.isDeleted)
        .toList(growable: false);
    return TaskProgress(
      completed: descendants.where((task) => task.status.isCompleted).length,
      total: descendants.length,
    );
  }

  Set<String> _descendantIds(String taskId) {
    final result = <String>{};
    final pending = <String>[taskId];
    while (pending.isNotEmpty) {
      final parentId = pending.removeLast();
      for (final task in _tasks.values) {
        if (task.parentId == parentId && result.add(task.id)) {
          pending.add(task.id);
        }
      }
    }
    return result;
  }

  int _subtreeHeight(String taskId) {
    final rootDepth = _tasks[taskId]!.depth;
    var deepest = rootDepth;
    for (final id in _descendantIds(taskId)) {
      final depth = _tasks[id]!.depth;
      if (depth > deepest) {
        deepest = depth;
      }
    }
    return deepest - rootDepth + 1;
  }

  List<Task> _normalizeSiblings(List<Task> tasks, DateTime nowUtc) {
    final grouped = <String?, List<Task>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.parentId, () => <Task>[]).add(task);
    }
    final normalized = <Task>[];
    for (final siblings in grouped.values) {
      siblings.sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0 ? order : left.id.compareTo(right.id);
      });
      for (var index = 0; index < siblings.length; index++) {
        final task = siblings[index];
        normalized.add(
          task.sortOrder == index
              ? task
              : task.copyWith(
                  sortOrder: index,
                  updatedAtUtc: nowUtc,
                  dirty: true,
                ),
        );
      }
    }
    return normalized;
  }
}
