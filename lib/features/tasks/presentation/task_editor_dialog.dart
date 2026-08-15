import 'package:flutter/material.dart';

import '../../../app/theme/quadrant_colors.dart';
import '../../../domain/entities/task.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.quadrant,
    required this.dueAtUtc,
  });

  final String title;
  final String description;
  final TaskQuadrant quadrant;
  final DateTime? dueAtUtc;
}

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({super.key, this.parentTitle, this.initialTask});

  final String? parentTitle;
  final Task? initialTask;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskQuadrant _quadrant;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title);
    _descriptionController = TextEditingController(text: task?.description);
    _quadrant = task?.quadrant ?? TaskQuadrant.importantNotUrgent;
    _dueAt = task?.dueAtUtc?.toLocal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
                        children: <Widget>[
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: quadrantColor(quadrant),
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(quadrantShortLabel(quadrant))),
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
        dueAtUtc: _dueAt?.toUtc(),
      ),
    );
  }
}
