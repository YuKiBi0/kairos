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
    this.dueDateFilter = DueDateFilter.any,
    this.hasUnresolvedBlockers,
  });

  final TaskViewMode viewMode;
  final TaskSortMode sortMode;
  final TaskScope scope;
  final String searchText;
  final bool alwaysOnTop;
  final Set<TaskQuadrant> quadrants;
  final DueDateFilter dueDateFilter;
  final bool? hasUnresolvedBlockers;

  AppPreferences copyWith({
    TaskViewMode? viewMode,
    TaskSortMode? sortMode,
    TaskScope? scope,
    String? searchText,
    bool? alwaysOnTop,
    Set<TaskQuadrant>? quadrants,
    DueDateFilter? dueDateFilter,
    Object? hasUnresolvedBlockers = _unsetPreference,
  }) => AppPreferences(
    viewMode: viewMode ?? this.viewMode,
    sortMode: sortMode ?? this.sortMode,
    scope: scope ?? this.scope,
    searchText: searchText ?? this.searchText,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    quadrants: quadrants ?? this.quadrants,
    dueDateFilter: dueDateFilter ?? this.dueDateFilter,
    hasUnresolvedBlockers: identical(hasUnresolvedBlockers, _unsetPreference)
        ? this.hasUnresolvedBlockers
        : hasUnresolvedBlockers as bool?,
  );
}

const Object _unsetPreference = Object();
