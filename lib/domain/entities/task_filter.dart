import 'task.dart';

enum DueDateFilter { any, withDueDate, withoutDueDate }

class TaskFilter {
  TaskFilter({
    String searchText = '',
    Set<TaskQuadrant> quadrants = const <TaskQuadrant>{},
    Set<TaskStatus> statuses = const <TaskStatus>{},
    this.dueDate = DueDateFilter.any,
    this.hasUnresolvedBlockers,
    Set<String> tagIds = const <String>{},
    this.projectId,
    this.checklistGroupId,
    this.includeDeleted = false,
  }) : searchText = searchText.trim().toLowerCase(),
       quadrants = Set<TaskQuadrant>.unmodifiable(quadrants),
       statuses = Set<TaskStatus>.unmodifiable(statuses),
       tagIds = Set<String>.unmodifiable(tagIds);

  final String searchText;
  final Set<TaskQuadrant> quadrants;
  final Set<TaskStatus> statuses;
  final DueDateFilter dueDate;
  final bool? hasUnresolvedBlockers;
  final Set<String> tagIds;
  final String? projectId;
  final String? checklistGroupId;
  final bool includeDeleted;

  bool matches(TaskListItem item) {
    final task = item.task;
    if (!includeDeleted && task.isDeleted) {
      return false;
    }
    if (searchText.isNotEmpty &&
        !task.title.toLowerCase().contains(searchText) &&
        !(task.description?.toLowerCase().contains(searchText) ?? false)) {
      return false;
    }
    if (quadrants.isNotEmpty && !quadrants.contains(task.quadrant)) {
      return false;
    }
    if (statuses.isNotEmpty && !statuses.contains(task.status)) {
      return false;
    }
    if (dueDate == DueDateFilter.withDueDate && task.dueAtUtc == null) {
      return false;
    }
    if (dueDate == DueDateFilter.withoutDueDate && task.dueAtUtc != null) {
      return false;
    }
    if (hasUnresolvedBlockers != null &&
        (item.unresolvedBlockerCount > 0) != hasUnresolvedBlockers) {
      return false;
    }
    if (tagIds.isNotEmpty && !task.tagIds.any(tagIds.contains)) {
      return false;
    }
    if (projectId != null && task.projectId != projectId) {
      return false;
    }
    if (checklistGroupId != null && task.checklistGroupId != checklistGroupId) {
      return false;
    }
    return true;
  }
}

class TaskListItem {
  const TaskListItem({
    required this.task,
    this.completedDescendantCount = 0,
    this.totalDescendantCount = 0,
    this.unresolvedBlockerCount = 0,
    this.parentPath = const <String>[],
  });

  final Task task;
  final int completedDescendantCount;
  final int totalDescendantCount;
  final int unresolvedBlockerCount;
  final List<String> parentPath;

  bool get hasDescendants => totalDescendantCount > 0;
}
