import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/quadrant_colors.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/taxonomy.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.quadrant,
    required this.status,
    required this.dueAtUtc,
    required this.tagIds,
    required this.projectId,
    required this.checklistGroupId,
  });

  final String title;
  final String description;
  final TaskQuadrant quadrant;
  final TaskStatus status;
  final DateTime? dueAtUtc;
  final Set<String> tagIds;
  final String? projectId;
  final String? checklistGroupId;
}

class TaskEditorDialog extends ConsumerStatefulWidget {
  const TaskEditorDialog({
    super.key,
    this.parentTitle,
    this.parentDueAtUtc,
    this.initialTask,
  });

  final String? parentTitle;
  final DateTime? parentDueAtUtc;
  final Task? initialTask;

  @override
  ConsumerState<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends ConsumerState<TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskQuadrant _quadrant;
  late TaskStatus _status;
  DateTime? _dueAt;
  late Set<String> _tagIds;
  String? _projectId;
  String? _checklistGroupId;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title);
    _descriptionController = TextEditingController(text: task?.description);
    _quadrant = task?.quadrant ?? TaskQuadrant.importantNotUrgent;
    _status = task?.status ?? TaskStatus.notStarted;
    _dueAt = task?.dueAtUtc?.toLocal();
    _tagIds = <String>{...?task?.tagIds};
    _projectId = task?.projectId;
    _checklistGroupId = task?.checklistGroupId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    return AlertDialog(
      title: Text(
        widget.initialTask != null
            ? '编辑任务'
            : widget.parentTitle == null
            ? '新建任务'
            : '添加子任务',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (widget.parentTitle != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('父任务：${widget.parentTitle}'),
                  ),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 200,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '写下一个可执行的动作',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请填写任务标题' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '详细描述',
                    hintText: '可选：背景、验收标准或上下文',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskQuadrant>(
                  initialValue: _quadrant,
                  decoration: const InputDecoration(labelText: '四象限'),
                  items: <DropdownMenuItem<TaskQuadrant>>[
                    for (final quadrant in TaskQuadrant.values)
                      DropdownMenuItem<TaskQuadrant>(
                        value: quadrant,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: quadrantColor(quadrant),
                            ),
                            const SizedBox(width: 8),
                            Text(quadrantShortLabel(quadrant)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _quadrant = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: '状态'),
                  items: <DropdownMenuItem<TaskStatus>>[
                    for (final status in TaskStatus.values)
                      DropdownMenuItem<TaskStatus>(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                if (tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text('标签', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final tag in tags)
                        FilterChip(
                          label: Text(tag.name),
                          selected: _tagIds.contains(tag.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _tagIds.add(tag.id)
                                : _tagIds.remove(tag.id);
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _projectId ?? '',
                  decoration: const InputDecoration(labelText: '项目'),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('无项目'),
                    ),
                    if (_projectId != null &&
                        projects.every((project) => project.id != _projectId))
                      DropdownMenuItem<String>(
                        value: _projectId!,
                        child: const Text('已归档项目'),
                      ),
                    for (final project in projects)
                      DropdownMenuItem<String>(
                        value: project.id,
                        child: Text(project.name),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _projectId = value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _checklistGroupId ?? '',
                  decoration: const InputDecoration(labelText: '清单分组'),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('无清单分组'),
                    ),
                    if (_checklistGroupId != null &&
                        groups.every((group) => group.id != _checklistGroupId))
                      DropdownMenuItem<String>(
                        value: _checklistGroupId!,
                        child: const Text('已归档清单分组'),
                      ),
                    for (final group in groups)
                      DropdownMenuItem<String>(
                        value: group.id,
                        child: Text(group.name),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _checklistGroupId = value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDueDate,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          _dueAt == null
                              ? '设置 DDL'
                              : MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(_dueAt!),
                        ),
                      ),
                    ),
                    if (_dueAt != null) ...<Widget>[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '清空 DDL',
                        onPressed: () => setState(() => _dueAt = null),
                        icon: const Icon(Icons.event_busy_outlined),
                      ),
                    ],
                  ],
                ),
                if (widget.parentDueAtUtc != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _dueAt = widget.parentDueAtUtc!.toLocal(),
                      ),
                      icon: const Icon(Icons.content_copy),
                      label: const Text('复制父任务 DDL'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selectedDate == null || !mounted) {
      return;
    }
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _dueAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (selectedTime == null || !mounted) {
      return;
    }
    setState(() {
      _dueAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      TaskDraft(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        quadrant: _quadrant,
        status: _status,
        dueAtUtc: _dueAt?.toUtc(),
        tagIds: Set<String>.unmodifiable(_tagIds),
        projectId: _projectId,
        checklistGroupId: _checklistGroupId,
      ),
    );
  }
}
