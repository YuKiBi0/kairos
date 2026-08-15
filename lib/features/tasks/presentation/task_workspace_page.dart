import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/organic_theme.dart';
import '../../../domain/entities/app_preferences.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_filter.dart';
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
                    data: (values) => values.isEmpty
                        ? _EmptyWorkspace(onCreate: _createTask)
                        : _buildView(preferences.viewMode, values),
                    error: (error, _) => _WorkspaceError(error: error),
                    loading: () => const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
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
      builder: (context) => TaskEditorDialog(parentTitle: parent?.title),
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
            dueAtUtc: draft.dueAtUtc,
            parentId: parent?.id,
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
      case 'delete':
        await ref.read(taskActionsProvider).delete(item.task);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('任务已删除，可在同步前恢复')));
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
            DropdownButtonFormField<bool?>(
              initialValue: state.hasUnresolvedBlockers,
              decoration: const InputDecoration(labelText: '推进困难点'),
              items: const <DropdownMenuItem<bool?>>[
                DropdownMenuItem(value: null, child: Text('不限')),
                DropdownMenuItem(value: true, child: Text('存在未解决困难点')),
                DropdownMenuItem(value: false, child: Text('无未解决困难点')),
              ],
              onChanged: controller.setBlockerFilter,
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
