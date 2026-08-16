import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/organic_theme.dart';
import '../../../app/theme/quadrant_colors.dart';
import '../../../domain/entities/blocker.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/taxonomy.dart';
import '../../../domain/services/task_tree_rules.dart';
import 'task_editor_dialog.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('任务详情')),
      body: tasks.when(
        data: (values) {
          final matches = values.where((task) => task.id == taskId);
          if (matches.isEmpty) {
            return const Center(child: Text('任务不存在或已删除'));
          }
          final task = matches.single;
          final active = values
              .where((candidate) => !candidate.isDeleted)
              .toList();
          final descendants = _descendants(task.id, active);
          final progress = TaskTreeRules(active).progressFor(task.id);
          return _TaskDetailContent(
            task: task,
            descendants: descendants,
            parentPath: _taskParentPath(task, active),
            completedDescendants: progress.completed,
            totalDescendants: progress.total,
          );
        },
        error: (error, _) => Center(child: Text('无法读取任务：$error')),
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class _TaskDetailContent extends ConsumerWidget {
  const _TaskDetailContent({
    required this.task,
    required this.descendants,
    required this.parentPath,
    required this.completedDescendants,
    required this.totalDescendants,
  });

  final Task task;
  final List<Task> descendants;
  final List<Task> parentPath;
  final int completedDescendants;
  final int totalDescendants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockers = ref.watch(blockersProvider(task.id));
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
    final tagNames = <String, String>{for (final tag in tags) tag.id: tag.name};
    final projectNames = <String, String>{
      for (final project in projects) project.id: project.name,
    };
    final groupNames = <String, String>{
      for (final group in groups) group.id: group.name,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconButton(
              tooltip: task.status.isCompleted ? '恢复任务' : '完成任务',
              onPressed: () =>
                  ref.read(taskActionsProvider).toggleCompleted(task),
              icon: Icon(
                task.status.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.status.isCompleted
                    ? KairosColors.moss
                    : KairosColors.quietInk,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      _DetailLabel(
                        icon: Icons.grid_view,
                        text: quadrantShortLabel(task.quadrant),
                      ),
                      _DetailLabel(
                        icon: Icons.flag_outlined,
                        text: task.status.label,
                      ),
                      _DetailLabel(
                        icon: Icons.layers_outlined,
                        text: '第 ${task.depth} 层',
                      ),
                      _DetailLabel(
                        icon: Icons.cloud_upload_outlined,
                        text: task.dirty ? '待同步' : '已同步',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '编辑任务',
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        if (parentPath.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: <Widget>[
              for (final parent in parentPath) ...<Widget>[
                TextButton(
                  onPressed: () =>
                      context.pushReplacement('/tasks/${parent.id}'),
                  child: Text(parent.title),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
              Text(task.title),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _Section(
          title: '详细描述',
          child: Text(
            task.description?.isNotEmpty == true ? task.description! : '暂无描述',
            style: TextStyle(
              color: task.description?.isNotEmpty == true
                  ? KairosColors.forestInk
                  : KairosColors.quietInk,
            ),
          ),
        ),
        _Section(
          title: 'DDL',
          child: Text(
            task.dueAtUtc == null
                ? '无明确截止时间'
                : '${MaterialLocalizations.of(context).formatFullDate(task.dueAtUtc!.toLocal())} '
                      '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(task.dueAtUtc!.toLocal()))}',
          ),
        ),
        _Section(
          title: '归类',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tagId in task.tagIds)
                Chip(
                  avatar: const Icon(Icons.label_outline, size: 16),
                  label: Text(tagNames[tagId] ?? '未知标签'),
                ),
              if (task.projectId != null)
                Chip(
                  avatar: const Icon(Icons.folder_outlined, size: 16),
                  label: Text(projectNames[task.projectId] ?? '已归档项目'),
                ),
              if (task.checklistGroupId != null)
                Chip(
                  avatar: const Icon(Icons.checklist_outlined, size: 16),
                  label: Text(groupNames[task.checklistGroupId] ?? '已归档清单分组'),
                ),
              if (task.tagIds.isEmpty &&
                  task.projectId == null &&
                  task.checklistGroupId == null)
                const Text('未归类'),
            ],
          ),
        ),
        _Section(
          title: '推进困难点',
          trailing: IconButton(
            tooltip: '添加困难点',
            onPressed: () => _addBlocker(context, ref),
            icon: const Icon(Icons.add),
          ),
          child: blockers.when(
            data: (values) => values.isEmpty
                ? const Text('暂无未记录的推进困难')
                : Column(
                    children: <Widget>[
                      for (final blocker in values)
                        _BlockerRow(blocker: blocker),
                    ],
                  ),
            error: (error, _) => Text('无法读取困难点：$error'),
            loading: () => const LinearProgressIndicator(),
          ),
        ),
        _Section(
          title: '子任务树',
          trailing: IconButton(
            tooltip: task.depth >= 5 ? '已达到 5 层上限' : '添加子任务',
            onPressed: task.depth >= 5 ? null : () => _addChild(context, ref),
            icon: const Icon(Icons.add),
          ),
          child: descendants.isEmpty
              ? const Text('暂无子任务')
              : Column(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '已完成 $completedDescendants / $totalDescendants',
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final child in descendants)
                      Padding(
                        padding: EdgeInsets.only(
                          left: (child.depth - task.depth - 1) * 20.0,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            child.status.isCompleted
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: child.status.isCompleted
                                ? KairosColors.moss
                                : KairosColors.quietInk,
                          ),
                          title: Text(child.title),
                          subtitle: Text(quadrantShortLabel(child.quadrant)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.pushReplacement('/tasks/${child.id}'),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(
          '最近更新：${task.updatedAtUtc.toLocal()}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: KairosColors.quietInk),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<TaskDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TaskEditorDialog(initialTask: task),
    );
    if (draft == null) {
      return;
    }
    await ref.read(taskActionsProvider).save(
      task.copyWith(
        title: draft.title,
        description: draft.description.isEmpty ? null : draft.description,
        quadrant: draft.quadrant,
        status: draft.status,
        dueAtUtc: draft.dueAtUtc,
        tagIds: draft.tagIds,
        projectId: draft.projectId,
        checklistGroupId: draft.checklistGroupId,
      ),
      const <String>{
        'title',
        'description',
        'quadrant',
        'status',
        'due_at',
        'tag_ids',
        'project_id',
        'checklist_group_id',
      },
    );
  }

  Future<void> _addBlocker(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录推进困难'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(hintText: '说明为什么现在推进不了'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body != null && body.isNotEmpty) {
      await ref.read(metadataRepositoryProvider).addBlocker(task.id, body);
    }
  }

  Future<void> _addChild(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<TaskDraft>(
      context: context,
      builder: (context) => TaskEditorDialog(parentTitle: task.title),
    );
    if (draft != null) {
      await ref
          .read(taskActionsProvider)
          .create(
            title: draft.title,
            description: draft.description,
            quadrant: draft.quadrant,
            dueAtUtc: draft.dueAtUtc,
            parentId: task.id,
          );
    }
  }
}

List<Task> _taskParentPath(Task task, List<Task> tasks) {
  final byId = <String, Task>{for (final item in tasks) item.id: item};
  final path = <Task>[];
  final visited = <String>{task.id};
  var parentId = task.parentId;
  while (parentId != null && visited.add(parentId)) {
    final parent = byId[parentId];
    if (parent == null) {
      break;
    }
    path.insert(0, parent);
    parentId = parent.parentId;
  }
  return path;
}

List<Task> _descendants(String taskId, List<Task> tasks) {
  final byParent = <String, List<Task>>{};
  for (final task in tasks) {
    final parentId = task.parentId;
    if (parentId != null) {
      byParent.putIfAbsent(parentId, () => <Task>[]).add(task);
    }
  }
  for (final children in byParent.values) {
    children.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  }
  final result = <Task>[];
  void addChildren(String parentId) {
    for (final child in byParent[parentId] ?? const <Task>[]) {
      result.add(child);
      addChildren(child.id);
    }
  }

  addChildren(taskId);
  return result;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 17, color: KairosColors.quietInk),
      const SizedBox(width: 5),
      Text(text),
    ],
  );
}

class _BlockerRow extends ConsumerWidget {
  const _BlockerRow({required this.blocker});

  final Blocker blocker;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Checkbox(
      value: blocker.resolved,
      onChanged: (value) => ref
          .read(metadataRepositoryProvider)
          .setBlockerResolved(blocker.id, resolved: value ?? false),
    ),
    title: Text(
      blocker.body,
      style: TextStyle(
        decoration: blocker.resolved ? TextDecoration.lineThrough : null,
      ),
    ),
    trailing: IconButton(
      tooltip: '删除困难点',
      onPressed: () =>
          ref.read(metadataRepositoryProvider).deleteBlocker(blocker.id),
      icon: const Icon(Icons.delete_outline),
    ),
  );
}
