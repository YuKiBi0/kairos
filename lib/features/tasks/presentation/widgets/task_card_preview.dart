import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/theme/organic_theme.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/entities/task_filter.dart';
import 'task_card.dart';

@Preview(
  name: 'Task card - Windows width',
  group: 'Tasks',
  size: Size(560, 180),
)
Widget taskCardDesktopPreview() => MaterialApp(
  theme: OrganicTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: TaskCard(
        item: _previewItem(),
        onToggleCompleted: _noop,
        onOpen: _noop,
        onMenuRequested: _noop,
      ),
    ),
  ),
);

@Preview(
  name: 'Task card - Android width',
  group: 'Tasks',
  size: Size(375, 220),
)
Widget taskCardMobilePreview() => MaterialApp(
  theme: OrganicTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(12),
      child: TaskCard(
        item: _previewItem(),
        onToggleCompleted: _noop,
        onOpen: _noop,
        onMenuRequested: _noop,
      ),
    ),
  ),
);

TaskListItem _previewItem() => TaskListItem(
  task: Task(
    id: 'preview-task',
    title: '确认 MVP 同步协议与冲突提示',
    description: '审查 HTTP 增量拉取与 WebSocket 通知边界',
    quadrant: TaskQuadrant.importantUrgent,
    status: TaskStatus.inProgress,
    dueAtUtc: DateTime.now().add(const Duration(hours: 3)).toUtc(),
    depth: 1,
    sortOrder: 0,
    createdAtUtc: DateTime.now().toUtc(),
    updatedAtUtc: DateTime.now().toUtc(),
    updatedByDeviceId: 'preview-device',
  ),
  completedDescendantCount: 3,
  totalDescendantCount: 7,
  unresolvedBlockerCount: 2,
);

void _noop() {}
