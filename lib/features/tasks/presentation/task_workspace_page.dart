import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/organic_theme.dart';
import '../../../domain/entities/app_preferences.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_filter.dart';
import '../../../domain/entities/taxonomy.dart';
import '../../../domain/services/task_sorter.dart';
import 'task_editor_dialog.dart';
import 'widgets/task_views.dart';

class TaskWorkspacePage extends ConsumerStatefulWidget {
  const TaskWorkspacePage({super.key});

  @override
  ConsumerState<TaskWorkspacePage> createState() => _TaskWorkspacePageState();
}

class _TaskWorkspacePageState extends ConsumerState<TaskWorkspacePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(workspaceControllerProvider).searchText,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(workspaceControllerProvider);
    final items = ref.watch(visibleTaskItemsProvider);
    final compactWorkspace =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        preferences.compactWorkspace;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _createTask,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!compactWorkspace)
                  _WorkspaceHeader(
                    searchController: _searchController,
                    preferences: preferences,
                    onSearchChanged: ref
                        .read(workspaceControllerProvider.notifier)
                        .setSearchText,
                    onCreate: _createTask,
                    onShowFilters: _showFilters,
                  ),
                Expanded(
                  child: items.when(
                    data: (values) => RefreshIndicator(
                      onRefresh: () =>
                          ref.read(realtimeActionsProvider).synchronizeNow(),
                      child: values.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: <Widget>[
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height -
                                      (compactWorkspace ? 64 : 220),
                                  child: _EmptyWorkspace(onCreate: _createTask),
                                ),
                              ],
                            )
                          : _buildView(preferences.viewMode, values),
                    ),
                    error: (error, _) => _WorkspaceError(error: error),
                    loading: () => const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: compactWorkspace
              ? null
              : FloatingActionButton(
                  tooltip: '新建任务',
                  onPressed: _createTask,
                  child: const Icon(Icons.add),
                ),
        ),
      ),
    );
  }

  Widget _buildView(TaskViewMode mode, List<TaskListItem> items) =>
      switch (mode) {
        TaskViewMode.list => TaskListView(
          items: items,
          onToggle: _toggle,
          onOpen: _open,
          onMenu: _showTaskMenu,
        ),
        TaskViewMode.tree => TaskTreeView(
          items: items,
          onToggle: _toggle,
          onOpen: _open,
          onMenu: _showTaskMenu,
          onAddChild: _createChild,
          onReorder: _reorder,
        ),
        TaskViewMode.quadrant => QuadrantTaskView(
          items: items,
          onToggle: _toggle,
          onOpen: _open,
          onMenu: _showTaskMenu,
        ),
      };

  Future<void> _createTask() => _openCreateDialog();

  Future<void> _createChild(TaskListItem item) =>
      _openCreateDialog(parent: item.task);

  Future<void> _openCreateDialog({Task? parent}) async {
    final draft = await showDialog<TaskDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TaskEditorDialog(
        parentTitle: parent?.title,
        parentDueAtUtc: parent?.dueAtUtc,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(taskActionsProvider)
          .create(
            title: draft.title,
            description: draft.description.isEmpty ? null : draft.description,
            quadrant: draft.quadrant,
            status: draft.status,
            dueAtUtc: draft.dueAtUtc,
            parentId: parent?.id,
            tagIds: draft.tagIds,
            projectId: draft.projectId,
            checklistGroupId: draft.checklistGroupId,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('任务未保存：$error')));
      }
    }
  }

  Future<void> _toggle(TaskListItem item) async {
    try {
      await ref.read(taskActionsProvider).toggleCompleted(item.task);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('状态未更新：$error')));
      }
    }
  }

  void _open(TaskListItem item) => context.push('/tasks/${item.task.id}');

  Future<void> _showTaskMenu(TaskListItem item) async {
    final allTasks = await ref.read(taskRepositoryProvider).getTasks();
    if (!mounted) {
      return;
    }
    final siblings =
        allTasks
            .where(
              (task) => !task.isDeleted && task.parentId == item.task.parentId,
            )
            .toList()
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    final siblingIndex = siblings.indexWhere((task) => task.id == item.task.id);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('打开详情'),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移动任务'),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            ListTile(
              enabled: siblingIndex > 0,
              leading: const Icon(Icons.arrow_upward),
              title: const Text('同级上移'),
              onTap: siblingIndex > 0
                  ? () => Navigator.pop(context, 'up')
                  : null,
            ),
            ListTile(
              enabled: siblingIndex >= 0 && siblingIndex < siblings.length - 1,
              leading: const Icon(Icons.arrow_downward),
              title: const Text('同级下移'),
              onTap: siblingIndex >= 0 && siblingIndex < siblings.length - 1
                  ? () => Navigator.pop(context, 'down')
                  : null,
            ),
            ListTile(
              enabled: item.task.depth < 5,
              leading: const Icon(Icons.add_circle_outline),
              title: Text(item.task.depth < 5 ? '添加子任务' : '已达到 5 层上限'),
              onTap: item.task.depth < 5
                  ? () => Navigator.pop(context, 'child')
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除任务'),
              textColor: KairosColors.clay,
              iconColor: KairosColors.clay,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'open':
        _open(item);
      case 'child':
        await _createChild(item);
      case 'move':
        await _showMoveDialog(item.task, allTasks);
      case 'up':
        await _moveTask(
          item.task,
          targetParentId: item.task.parentId,
          targetSortOrder: siblingIndex - 1,
        );
      case 'down':
        await _moveTask(
          item.task,
          targetParentId: item.task.parentId,
          targetSortOrder: siblingIndex + 1,
        );
      case 'delete':
        await ref.read(taskActionsProvider).delete(item.task);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('任务已删除'),
              action: SnackBarAction(
                label: '撤销',
                onPressed: () =>
                    ref.read(taskActionsProvider).restore(item.task),
              ),
            ),
          );
        }
    }
  }

  Future<void> _showMoveDialog(Task task, List<Task> allTasks) async {
    final descendants = _descendantIds(task.id, allTasks);
    final targets =
        allTasks
            .where(
              (candidate) =>
                  !candidate.isDeleted &&
                  candidate.id != task.id &&
                  !descendants.contains(candidate.id) &&
                  candidate.depth < 5,
            )
            .toList()
          ..sort((left, right) => left.title.compareTo(right.title));
    final selection = await showDialog<_MoveSelection>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动任务'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, const _MoveSelection(null)),
            child: const ListTile(
              leading: Icon(Icons.home_outlined),
              title: Text('移动到根级'),
            ),
          ),
          for (final target in targets)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, _MoveSelection(target.id)),
              child: ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right),
                title: Text(target.title),
                subtitle: Text('第 ${target.depth} 层'),
              ),
            ),
        ],
      ),
    );
    if (selection == null || !mounted) {
      return;
    }
    final targetOrder = allTasks
        .where(
          (candidate) =>
              !candidate.isDeleted &&
              candidate.parentId == selection.parentId &&
              candidate.id != task.id,
        )
        .length;
    await _moveTask(
      task,
      targetParentId: selection.parentId,
      targetSortOrder: targetOrder,
    );
  }

  Future<void> _reorder(
    TaskListItem item,
    String? targetParentId,
    int targetSortOrder,
  ) => _moveTask(
    item.task,
    targetParentId: targetParentId,
    targetSortOrder: targetSortOrder,
  );

  Future<void> _moveTask(
    Task task, {
    required String? targetParentId,
    required int targetSortOrder,
  }) async {
    try {
      await ref
          .read(taskActionsProvider)
          .move(
            task: task,
            targetParentId: targetParentId,
            targetSortOrder: targetSortOrder,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('任务未移动：$error')));
      }
    }
  }

  Future<void> _showFilters() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _TaskFilterSheet(),
  );
}

class _WorkspaceHeader extends ConsumerWidget {
  const _WorkspaceHeader({
    required this.searchController,
    required this.preferences,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onShowFilters,
  });

  final TextEditingController searchController;
  final AppPreferences preferences;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;
  final VoidCallback onShowFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Kairos', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    '现在最该推进什么',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KairosColors.quietInk,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新建'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索标题和描述',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            );
            final controls = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SegmentedButton<TaskViewMode>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<TaskViewMode>>[
                    ButtonSegment<TaskViewMode>(
                      value: TaskViewMode.list,
                      icon: Tooltip(
                        message: '列表视图',
                        child: Icon(Icons.view_agenda_outlined),
                      ),
                    ),
                    ButtonSegment<TaskViewMode>(
                      value: TaskViewMode.tree,
                      icon: Tooltip(
                        message: '树视图',
                        child: Icon(Icons.account_tree_outlined),
                      ),
                    ),
                    ButtonSegment<TaskViewMode>(
                      value: TaskViewMode.quadrant,
                      icon: Tooltip(
                        message: '四象限视图',
                        child: Icon(Icons.grid_view_outlined),
                      ),
                    ),
                  ],
                  selected: <TaskViewMode>{preferences.viewMode},
                  onSelectionChanged: (values) => ref
                      .read(workspaceControllerProvider.notifier)
                      .setViewMode(values.single),
                ),
                DropdownButton<TaskSortMode>(
                  value: preferences.sortMode,
                  borderRadius: BorderRadius.circular(6),
                  items: const <DropdownMenuItem<TaskSortMode>>[
                    DropdownMenuItem(
                      value: TaskSortMode.executionPriority,
                      child: Text('执行优先级'),
                    ),
                    DropdownMenuItem(
                      value: TaskSortMode.dueDate,
                      child: Text('DDL 时间'),
                    ),
                    DropdownMenuItem(
                      value: TaskSortMode.recentlyUpdated,
                      child: Text('最近更新'),
                    ),
                    DropdownMenuItem(
                      value: TaskSortMode.createdAt,
                      child: Text('创建时间'),
                    ),
                    DropdownMenuItem(
                      value: TaskSortMode.manual,
                      child: Text('手动排序'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(workspaceControllerProvider.notifier)
                          .setSortMode(value);
                    }
                  },
                ),
                OutlinedButton.icon(
                  onPressed: onShowFilters,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('筛选'),
                ),
              ],
            );
            return Column(
              children: <Widget>[
                if (constraints.maxWidth >= 900)
                  Row(
                    children: <Widget>[
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      controls,
                    ],
                  )
                else ...<Widget>[
                  search,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: controls),
                ],
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<TaskScope>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<TaskScope>>[
                      ButtonSegment(value: TaskScope.all, label: Text('全部')),
                      ButtonSegment(value: TaskScope.today, label: Text('今天')),
                      ButtonSegment(
                        value: TaskScope.overdue,
                        label: Text('已逾期'),
                      ),
                      ButtonSegment(
                        value: TaskScope.completed,
                        label: Text('已完成'),
                      ),
                    ],
                    selected: <TaskScope>{preferences.scope},
                    onSelectionChanged: (values) => ref
                        .read(workspaceControllerProvider.notifier)
                        .setScope(values.single),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _TaskFilterSheet extends ConsumerWidget {
  const _TaskFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final controller = ref.read(workspaceControllerProvider.notifier);
    final tags = ref
        .watch(tagsProvider)
        .when(
          data: (value) => value,
          error: (_, _) => const <Tag>[],
          loading: () => const <Tag>[],
        );
    final projects = ref
        .watch(projectsProvider)
        .when(
          data: (value) => value,
          error: (_, _) => const <Project>[],
          loading: () => const <Project>[],
        );
    final groups = ref
        .watch(checklistGroupsProvider)
        .when(
          data: (value) => value,
          error: (_, _) => const <ChecklistGroup>[],
          loading: () => const <ChecklistGroup>[],
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '筛选任务',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: controller.clearFilters,
                  child: const Text('清除'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('四象限', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final quadrant in TaskQuadrant.values)
                  FilterChip(
                    label: Text('Q${quadrant.code} ${quadrant.label}'),
                    selected: state.quadrants.contains(quadrant),
                    onSelected: (_) => controller.toggleQuadrant(quadrant),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('状态', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final status in TaskStatus.values)
                  FilterChip(
                    label: Text(status.label),
                    selected: state.statuses.contains(status),
                    onSelected: (_) => controller.toggleStatus(status),
                  ),
              ],
            ),
            if (tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Text('标签', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: state.tagIds.contains(tag.id),
                      onSelected: (_) => controller.toggleTag(tag.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: state.projectId ?? '',
              decoration: const InputDecoration(labelText: '项目'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(value: '', child: Text('不限')),
                for (final project in projects)
                  DropdownMenuItem<String>(
                    value: project.id,
                    child: Text(project.name),
                  ),
              ],
              onChanged: (value) => controller.setProjectFilter(
                value == null || value.isEmpty ? null : value,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: state.checklistGroupId ?? '',
              decoration: const InputDecoration(labelText: '清单分组'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(value: '', child: Text('不限')),
                for (final group in groups)
                  DropdownMenuItem<String>(
                    value: group.id,
                    child: Text(group.name),
                  ),
              ],
              onChanged: (value) => controller.setChecklistGroupFilter(
                value == null || value.isEmpty ? null : value,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DueDateFilter>(
              initialValue: state.dueDateFilter,
              decoration: const InputDecoration(labelText: 'DDL'),
              items: const <DropdownMenuItem<DueDateFilter>>[
                DropdownMenuItem(value: DueDateFilter.any, child: Text('不限')),
                DropdownMenuItem(
                  value: DueDateFilter.withDueDate,
                  child: Text('有 DDL'),
                ),
                DropdownMenuItem(
                  value: DueDateFilter.withoutDueDate,
                  child: Text('无 DDL'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.setDueDateFilter(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: switch (state.hasUnresolvedBlockers) {
                true => 'with',
                false => 'without',
                null => 'any',
              },
              decoration: const InputDecoration(labelText: '推进困难点'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'any', child: Text('不限')),
                DropdownMenuItem(value: 'with', child: Text('存在未解决困难点')),
                DropdownMenuItem(value: 'without', child: Text('无未解决困难点')),
              ],
              onChanged: (value) => controller.setBlockerFilter(switch (value) {
                'with' => true,
                'without' => false,
                _ => null,
              }),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline,
            size: 52,
            color: KairosColors.moss,
          ),
          const SizedBox(height: 16),
          Text('当前条件下没有任务', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('先记下一件现在可以推进的事。'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新建任务'),
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('无法读取本地任务。\n$error', textAlign: TextAlign.center),
    ),
  );
}

class _MoveSelection {
  const _MoveSelection(this.parentId);

  final String? parentId;
}

Set<String> _descendantIds(String taskId, List<Task> tasks) {
  final result = <String>{};
  final pending = <String>[taskId];
  while (pending.isNotEmpty) {
    final parentId = pending.removeLast();
    for (final task in tasks) {
      if (task.parentId == parentId && result.add(task.id)) {
        pending.add(task.id);
      }
    }
  }
  return result;
}
