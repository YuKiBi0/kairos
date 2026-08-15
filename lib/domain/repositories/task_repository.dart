import '../entities/task.dart';

abstract interface class TaskRepository {
  Stream<List<Task>> watchTasks();

  Future<List<Task>> getTasks();

  Future<Task?> getTask(String id);

  Future<Task> createTask({
    required String title,
    required String deviceId,
    String? description,
    TaskQuadrant quadrant,
    DateTime? dueAtUtc,
    String? parentId,
    Set<String> tagIds,
    String? projectId,
    String? checklistGroupId,
  });

  Future<Task> saveTask(Task task, {required Set<String> changedFields});

  Future<void> moveTask({
    required String taskId,
    required String? targetParentId,
    required int targetSortOrder,
    required DateTime nowUtc,
  });

  Future<void> softDeleteTask(String taskId, DateTime nowUtc);

  Future<void> restoreTask(String taskId, DateTime nowUtc);
}
