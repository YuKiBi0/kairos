import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/organic_theme.dart';
import '../../../../app/theme/quadrant_colors.dart';
import '../../../../domain/entities/task_filter.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.item,
    required this.onToggleCompleted,
    required this.onOpen,
    required this.onMenuRequested,
    super.key,
    this.compact = false,
  });

  final TaskListItem item;
  final VoidCallback onToggleCompleted;
  final VoidCallback onOpen;
  final VoidCallback onMenuRequested;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final stripe = quadrantColor(task.quadrant);
    return Semantics(
      button: true,
      label: '${task.title}，${task.quadrant.label}，${task.status.label}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: 4, child: ColoredBox(color: stripe)),
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  onLongPress: onMenuRequested,
                  onSecondaryTap: onMenuRequested,
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 10 : 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Semantics(
                          label: task.status.isCompleted ? '恢复任务' : '完成任务',
                          child: SizedBox.square(
                            dimension: 44,
                            child: IconButton(
                              tooltip: task.status.isCompleted
                                  ? '恢复任务'
                                  : '完成任务',
                              onPressed: onToggleCompleted,
                              icon: Icon(
                                task.status.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: task.status.isCompleted
                                    ? KairosColors.moss
                                    : KairosColors.quietInk,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (item.parentPath.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    item.parentPath.join(' / '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: KairosColors.quietInk,
                                        ),
                                  ),
                                ),
                              Text(
                                task.title,
                                maxLines: compact ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      decoration: task.status.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.status.isCompleted
                                          ? KairosColors.quietInk
                                          : KairosColors.forestInk,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: <Widget>[
                                  _MetaLabel(
                                    icon: Icons.grid_view_rounded,
                                    text: quadrantShortLabel(task.quadrant),
                                    color: stripe,
                                  ),
                                  _DueLabel(dueAtUtc: task.dueAtUtc),
                                  if (item.hasDescendants)
                                    _MetaLabel(
                                      icon: Icons.account_tree_outlined,
                                      text:
                                          '${item.completedDescendantCount}/${item.totalDescendantCount}',
                                      color: KairosColors.moss,
                                    ),
                                  if (item.unresolvedBlockerCount > 0)
                                    _MetaLabel(
                                      icon: Icons.report_problem_outlined,
                                      text:
                                          '困难点 ${item.unresolvedBlockerCount}',
                                      color: KairosColors.pollen,
                                    ),
                                  if (task.dirty)
                                    const _MetaLabel(
                                      icon: Icons.cloud_upload_outlined,
                                      text: '待同步',
                                      color: KairosColors.river,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox.square(
                          dimension: 44,
                          child: IconButton(
                            tooltip: '更多操作',
                            onPressed: onMenuRequested,
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueLabel extends StatelessWidget {
  const _DueLabel({required this.dueAtUtc});

  final DateTime? dueAtUtc;

  @override
  Widget build(BuildContext context) {
    final due = dueAtUtc?.toLocal();
    if (due == null) {
      return const _MetaLabel(
        icon: Icons.event_busy_outlined,
        text: '无 DDL',
        color: KairosColors.quietInk,
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final dayDifference = dueDay.difference(today).inDays;
    final (text, color) = due.isBefore(now)
        ? ('已逾期 ${DateFormat('MM-dd HH:mm').format(due)}', KairosColors.clay)
        : dayDifference == 0
        ? ('今天 ${DateFormat('HH:mm').format(due)}', KairosColors.pollen)
        : dayDifference == 1
        ? ('明天 ${DateFormat('HH:mm').format(due)}', KairosColors.pollen)
        : (DateFormat('MM-dd HH:mm').format(due), KairosColors.quietInk);
    return _MetaLabel(icon: Icons.schedule, text: text, color: color);
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 24),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.55)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: KairosColors.forestInk),
          ),
        ),
      ],
    ),
  );
}
