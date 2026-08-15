import '../services/task_sorter.dart';

enum TaskViewMode { list, tree, quadrant }

enum TaskScope { all, today, overdue, completed }

class AppPreferences {
  const AppPreferences({
    this.viewMode = TaskViewMode.list,
    this.sortMode = TaskSortMode.executionPriority,
    this.scope = TaskScope.all,
    this.searchText = '',
    this.alwaysOnTop = false,
  });

  final TaskViewMode viewMode;
  final TaskSortMode sortMode;
  final TaskScope scope;
  final String searchText;
  final bool alwaysOnTop;

  AppPreferences copyWith({
    TaskViewMode? viewMode,
    TaskSortMode? sortMode,
    TaskScope? scope,
    String? searchText,
    bool? alwaysOnTop,
  }) => AppPreferences(
    viewMode: viewMode ?? this.viewMode,
    sortMode: sortMode ?? this.sortMode,
    scope: scope ?? this.scope,
    searchText: searchText ?? this.searchText,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
  );
}
