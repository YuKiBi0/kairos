import 'package:flutter/material.dart';

import '../../../../app/theme/organic_theme.dart';
import '../../../../app/theme/quadrant_colors.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/entities/task_filter.dart';
import 'task_card.dart';

typedef TaskItemCallback = void Function(TaskListItem item);
typedef TaskReorderCallback =
    void Function(
      TaskListItem item,
      String? targetParentId,
      int targetSortOrder,
    );

class TaskListView extends StatelessWidget {
  const TaskListView({
    required this.items,
    required this.onToggle,
    required this.onOpen,
    required this.onMenu,
    super.key,
  });

  final List<TaskListItem> items;
  final TaskItemCallback onToggle;
  final TaskItemCallback onOpen;
  final TaskItemCallback onMenu;

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final item = items[index];
      return TaskCard(
        key: ValueKey<String>(item.task.id),
        item: item,
        onToggleCompleted: () => onToggle(item),
        onOpen: () => onOpen(item),
        onMenuRequested: () => onMenu(item),
      );
    },
  );
}

class TaskTreeView extends StatefulWidget {
  const TaskTreeView({
    required this.items,
    required this.onToggle,
    required this.onOpen,
    required this.onMenu,
    required this.onAddChild,
    required this.onReorder,
    super.key,
  });

  final List<TaskListItem> items;
  final TaskItemCallback onToggle;
  final TaskItemCallback onOpen;
  final TaskItemCallback onMenu;
  final TaskItemCallback onAddChild;
  final TaskReorderCallback onReorder;

  @override
  State<TaskTreeView> createState() => _TaskTreeViewState();
}

class _TaskTreeViewState extends State<TaskTreeView> {
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    final byParent = <String?, List<TaskListItem>>{};
    final ids = widget.items.map((item) => item.task.id).toSet();
    for (final item in widget.items) {
      final parent = ids.contains(item.task.parentId)
          ? item.task.parentId
          : null;
      byParent.putIfAbsent(parent, () => <TaskListItem>[]).add(item);
    }
    final rows = <_TreeRow>[];
    void addRows(String? parentId, int visualDepth) {
      for (final item in byParent[parentId] ?? const <TaskListItem>[]) {
        final children = byParent[item.task.id] ?? const <TaskListItem>[];
        rows.add(
          _TreeRow(
            item: item,
            visualDepth: visualDepth,
            hasChildren: children.isNotEmpty,
          ),
        );
        if (!_collapsed.contains(item.task.id)) {
          addRows(item.task.id, visualDepth + 1);
        }
      }
    }

    addRows(null, 0);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => setState(_collapsed.clear),
                icon: const Icon(Icons.unfold_more),
                label: const Text('展开全部'),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _collapsed
                    ..clear()
                    ..addAll(byParent.keys.whereType<String>());
                }),
                icon: const Icon(Icons.unfold_less),
                label: const Text('折叠全部'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            itemCount: rows.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) {
                newIndex--;
              }
              if (newIndex == oldIndex || rows.isEmpty) {
                return;
              }
              final moved = rows[oldIndex].item;
              final target = rows[newIndex].item.task;
              widget.onReorder(moved, target.parentId, target.sortOrder);
            },
            itemBuilder: (context, index) {
              final row = rows[index];
              return Padding(
                key: ValueKey<String>('tree-row-${row.item.task.id}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: EdgeInsets.only(left: row.visualDepth * 22.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: row.visualDepth == 0
                          ? null
                          : const Border(
                              left: BorderSide(
                                color: KairosColors.sage,
                                width: 2,
                              ),
                            ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 44,
                          child: row.hasChildren
                              ? IconButton(
                                  tooltip: _collapsed.contains(row.item.task.id)
                                      ? '展开子任务'
                                      : '折叠子任务',
                                  onPressed: () => setState(() {
                                    _collapsed.contains(row.item.task.id)
                                        ? _collapsed.remove(row.item.task.id)
                                        : _collapsed.add(row.item.task.id);
                                  }),
                                  icon: Icon(
                                    _collapsed.contains(row.item.task.id)
                                        ? Icons.chevron_right
                                        : Icons.expand_more,
                                  ),
                                )
                              : const Icon(
                                  Icons.circle,
                                  size: 9,
                                  color: KairosColors.sage,
                                ),
                        ),
                        Expanded(
                          child: TaskCard(
                            item: row.item,
                            compact: true,
                            onToggleCompleted: () => widget.onToggle(row.item),
                            onOpen: () => widget.onOpen(row.item),
                            onMenuRequested: () => widget.onMenu(row.item),
                          ),
                        ),
                        SizedBox.square(
                          dimension: 44,
                          child: IconButton(
                            tooltip: row.item.task.depth >= 5
                                ? '已达到 5 层上限'
                                : '添加子任务',
                            onPressed: row.item.task.depth >= 5
                                ? null
                                : () => widget.onAddChild(row.item),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ),
                        SizedBox.square(
                          dimension: 44,
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: const Tooltip(
                              message: '长按拖动排序',
                              child: Icon(Icons.drag_indicator),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class QuadrantTaskView extends StatelessWidget {
  const QuadrantTaskView({
    required this.items,
    required this.onToggle,
    required this.onOpen,
    required this.onMenu,
    super.key,
  });

  final List<TaskListItem> items;
  final TaskItemCallback onToggle;
  final TaskItemCallback onOpen;
  final TaskItemCallback onMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sections = <Widget>[
        for (final quadrant in TaskQuadrant.values)
          _QuadrantSection(
            key: ValueKey<String>('quadrant-section-${quadrant.code}'),
            quadrant: quadrant,
            items: items
                .where((item) => item.task.quadrant == quadrant)
                .toList(),
            onToggle: onToggle,
            onOpen: onOpen,
            onMenu: onMenu,
          ),
      ];
      if (constraints.maxWidth >= 900) {
        return GridView.count(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          crossAxisCount: 2,
          childAspectRatio: 1.28,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: sections,
        );
      }
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            SizedBox(height: 380, child: sections[index]),
      );
    },
  );
}

class _QuadrantSection extends StatelessWidget {
  const _QuadrantSection({
    super.key,
    required this.quadrant,
    required this.items,
    required this.onToggle,
    required this.onOpen,
    required this.onMenu,
  });

  final TaskQuadrant quadrant;
  final List<TaskListItem> items;
  final TaskItemCallback onToggle;
  final TaskItemCallback onOpen;
  final TaskItemCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final color = quadrantColor(quadrant);
    final incomplete = items
        .where((item) => !item.task.status.isCompleted)
        .length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: <Widget>[
                Icon(Icons.circle, size: 11, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quadrantShortLabel(quadrant),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('$incomplete 项未完成'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('这个象限暂无任务'))
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return TaskCard(
                        item: item,
                        compact: true,
                        onToggleCompleted: () => onToggle(item),
                        onOpen: () => onOpen(item),
                        onMenuRequested: () => onMenu(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TreeRow {
  const _TreeRow({
    required this.item,
    required this.visualDepth,
    required this.hasChildren,
  });

  final TaskListItem item;
  final int visualDepth;
  final bool hasChildren;
}
