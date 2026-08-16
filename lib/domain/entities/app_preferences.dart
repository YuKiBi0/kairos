import '../services/task_sorter.dart';
import 'task.dart';
import 'task_filter.dart';

enum TaskViewMode { list, tree, quadrant }

enum TaskScope { all, today, overdue, completed }

class AppPreferences {
  const AppPreferences({
    this.viewMode = TaskViewMode.list,
    this.sortMode = TaskSortMode.executionPriority,
    this.scope = TaskScope.all,
    this.searchText = '',
    this.alwaysOnTop = false,
    this.quadrants = const <TaskQuadrant>{},
    this.statuses = const <TaskStatus>{},
    this.dueDateFilter = DueDateFilter.any,
    this.hasUnresolvedBlockers,
    this.tagIds = const <String>{},
    this.projectId,
    this.checklistGroupId,
  });

  final TaskViewMode viewMode;
  final TaskSortMode sortMode;
  final TaskScope scope;
  final String searchText;
  final bool alwaysOnTop;
  final Set<TaskQuadrant> quadrants;
  final Set<TaskStatus> statuses;
  final DueDateFilter dueDateFilter;
  final bool? hasUnresolvedBlockers;
  final Set<String> tagIds;
  final String? projectId;
  final String? checklistGroupId;

  AppPreferences copyWith({
    TaskViewMode? viewMode,
    TaskSortMode? sortMode,
    TaskScope? scope,
    String? searchText,
    bool? alwaysOnTop,
    Set<TaskQuadrant>? quadrants,
    Set<TaskStatus>? statuses,
    DueDateFilter? dueDateFilter,
    Object? hasUnresolvedBlockers = _unsetPreference,
    Set<String>? tagIds,
    Object? projectId = _unsetPreference,
    Object? checklistGroupId = _unsetPreference,
  }) => AppPreferences(
    viewMode: viewMode ?? this.viewMode,
    sortMode: sortMode ?? this.sortMode,
    scope: scope ?? this.scope,
    searchText: searchText ?? this.searchText,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    quadrants: quadrants ?? this.quadrants,
    statuses: statuses ?? this.statuses,
    dueDateFilter: dueDateFilter ?? this.dueDateFilter,
    hasUnresolvedBlockers: identical(hasUnresolvedBlockers, _unsetPreference)
        ? this.hasUnresolvedBlockers
        : hasUnresolvedBlockers as bool?,
    tagIds: tagIds ?? this.tagIds,
    projectId: identical(projectId, _unsetPreference)
        ? this.projectId
        : projectId as String?,
    checklistGroupId: identical(checklistGroupId, _unsetPreference)
        ? this.checklistGroupId
        : checklistGroupId as String?,
  );
}

const Object _unsetPreference = Object();
