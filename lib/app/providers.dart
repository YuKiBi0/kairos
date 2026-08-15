import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/windows_window_service.dart';
import '../core/security/secure_credential_store.dart';
import '../data/local/database.dart' hide HealthEvent;
import '../data/repositories/local_metadata_repository.dart';
import '../data/repositories/local_settings_repository.dart';
import '../data/repositories/local_task_repository.dart';
import '../domain/entities/app_preferences.dart';
import '../domain/entities/blocker.dart';
import '../domain/entities/realtime_status.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_filter.dart';
import '../domain/entities/taxonomy.dart';
import '../domain/repositories/metadata_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/services/task_sorter.dart';
import '../domain/services/task_tree_rules.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => LocalTaskRepository(ref.watch(databaseProvider)),
);

final metadataRepositoryProvider = Provider<MetadataRepository>(
  (ref) => LocalMetadataRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => LocalSettingsRepository(ref.watch(databaseProvider)),
);

final windowsWindowServiceProvider = Provider<WindowsWindowService>(
  (ref) => const WindowsWindowService(),
);

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => const SecureCredentialStore(),
);

final workspaceControllerProvider =
    StateNotifierProvider<WorkspaceController, AppPreferences>(
      (ref) => WorkspaceController(ref.watch(settingsRepositoryProvider)),
    );

final tasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

final unresolvedBlockerCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchUnresolvedBlockerCounts(),
);

final blockersProvider = StreamProvider.family<List<Blocker>, String>(
  (ref, taskId) => ref.watch(metadataRepositoryProvider).watchBlockers(taskId),
);

final tagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchTags(),
);

final projectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchProjects(),
);

final checklistGroupsProvider = StreamProvider<List<ChecklistGroup>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchChecklistGroups(),
);

final deviceIdProvider = FutureProvider<String>(
  (ref) => ref.watch(settingsRepositoryProvider).getOrCreateDeviceId(),
);

final realtimeStatusProvider = StateProvider<RealtimeStatus>(
  (ref) => const RealtimeStatus.unconfigured(),
);

final healthEventsProvider = StateProvider<List<HealthEvent>>(
  (ref) => const <HealthEvent>[],
);

final visibleTaskItemsProvider = Provider<AsyncValue<List<TaskListItem>>>((
  ref,
) {
  final tasks = ref.watch(tasksProvider);
  final blockerCounts = ref.watch(unresolvedBlockerCountsProvider);
  final preferences = ref.watch(workspaceControllerProvider);

  return tasks.when(
    data: (taskValues) => blockerCounts.when(
      data: (counts) => AsyncValue<List<TaskListItem>>.data(
        _projectTasks(taskValues, counts, preferences),
      ),
      error: AsyncValue<List<TaskListItem>>.error,
      loading: AsyncValue<List<TaskListItem>>.loading,
    ),
    error: AsyncValue<List<TaskListItem>>.error,
    loading: AsyncValue<List<TaskListItem>>.loading,
  );
});

class WorkspaceController extends StateNotifier<AppPreferences> {
  WorkspaceController(this._settings) : super(const AppPreferences()) {
    unawaited(_hydrate());
  }

  final SettingsRepository _settings;
  Timer? _searchSaveTimer;

  Future<void> _hydrate() async {
    state = await _settings.loadPreferences();
  }

  void setViewMode(TaskViewMode value) =>
      _update(state.copyWith(viewMode: value));

  void setSortMode(TaskSortMode value) =>
      _update(state.copyWith(sortMode: value));

  void setScope(TaskScope value) => _update(state.copyWith(scope: value));

  void setSearchText(String value) {
    state = state.copyWith(searchText: value);
    _searchSaveTimer?.cancel();
    _searchSaveTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_settings.savePreferences(state)),
    );
  }

  void toggleQuadrant(TaskQuadrant quadrant) {
    final selected = <TaskQuadrant>{...state.quadrants};
    selected.contains(quadrant)
        ? selected.remove(quadrant)
        : selected.add(quadrant);
    _update(
      state.copyWith(quadrants: Set<TaskQuadrant>.unmodifiable(selected)),
    );
  }

  void setDueDateFilter(DueDateFilter value) =>
      _update(state.copyWith(dueDateFilter: value));

  void setBlockerFilter(bool? value) =>
      _update(state.copyWith(hasUnresolvedBlockers: value));

  void setAlwaysOnTop(bool value) =>
      _update(state.copyWith(alwaysOnTop: value));

  void clearFilters() => _update(
    state.copyWith(
      quadrants: const <TaskQuadrant>{},
      dueDateFilter: DueDateFilter.any,
      hasUnresolvedBlockers: null,
    ),
  );

  void _update(AppPreferences value) {
    state = value;
    unawaited(_settings.savePreferences(value));
  }

  @override
  void dispose() {
    _searchSaveTimer?.cancel();
    super.dispose();
  }
}

class TaskActions {
  const TaskActions(this._tasks, this._settings);

  final TaskRepository _tasks;
  final SettingsRepository _settings;

  Future<Task> create({
    required String title,
    String? description,
    TaskQuadrant quadrant = TaskQuadrant.importantNotUrgent,
    DateTime? dueAtUtc,
    String? parentId,
  }) async {
    final deviceId = await _settings.getOrCreateDeviceId();
    return _tasks.createTask(
      title: title,
      description: description,
      quadrant: quadrant,
      dueAtUtc: dueAtUtc,
      parentId: parentId,
      deviceId: deviceId,
    );
  }

  Future<Task> save(Task task, Set<String> changedFields) =>
      _tasks.saveTask(task, changedFields: changedFields);

  Future<void> toggleCompleted(Task task) async {
    final next = task.status.isCompleted
        ? TaskStatus.inProgress
        : TaskStatus.completed;
    await _tasks.saveTask(
      task.copyWith(status: next),
      changedFields: const <String>{'status'},
    );
  }

  Future<void> delete(Task task) =>
      _tasks.softDeleteTask(task.id, DateTime.now().toUtc());
}

final taskActionsProvider = Provider<TaskActions>(
  (ref) => TaskActions(
    ref.watch(taskRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

List<TaskListItem> _projectTasks(
  List<Task> tasks,
  Map<String, int> blockerCounts,
  AppPreferences preferences,
) {
  final active = tasks.where((task) => !task.isDeleted).toList(growable: false);
  final byId = <String, Task>{for (final task in active) task.id: task};
  final tree = TaskTreeRules(active);
  final filter = TaskFilter(
    searchText: preferences.searchText,
    quadrants: preferences.quadrants,
    dueDate: preferences.dueDateFilter,
    hasUnresolvedBlockers: preferences.hasUnresolvedBlockers,
  );
  final now = DateTime.now();
  final items = <TaskListItem>[];
  for (final task in active) {
    if (task.status == TaskStatus.archived ||
        !_matchesScope(task, preferences.scope, now)) {
      continue;
    }
    final progress = tree.progressFor(task.id);
    final item = TaskListItem(
      task: task,
      completedDescendantCount: progress.completed,
      totalDescendantCount: progress.total,
      unresolvedBlockerCount: blockerCounts[task.id] ?? 0,
      parentPath: _parentPath(task, byId),
    );
    if (filter.matches(item)) {
      items.add(item);
    }
  }
  return const TaskSorter().sort(items, mode: preferences.sortMode, now: now);
}

bool _matchesScope(Task task, TaskScope scope, DateTime now) {
  final due = task.dueAtUtc?.toLocal();
  return switch (scope) {
    TaskScope.all => true,
    TaskScope.completed => task.status.isCompleted,
    TaskScope.overdue =>
      !task.status.isCompleted && due != null && due.isBefore(now.toLocal()),
    TaskScope.today =>
      !task.status.isCompleted && due != null && _sameDay(due, now.toLocal()),
  };
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

List<String> _parentPath(Task task, Map<String, Task> byId) {
  final path = <String>[];
  final visited = <String>{task.id};
  var parentId = task.parentId;
  while (parentId != null && visited.add(parentId)) {
    final parent = byId[parentId];
    if (parent == null) {
      break;
    }
    path.insert(0, parent.title);
    parentId = parent.parentId;
  }
  return List<String>.unmodifiable(path);
}
