import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/task.dart' as domain;
import '../local/database.dart';

class TaskMapper {
  const TaskMapper();

  domain.Task fromLocal(LocalTask row, Set<String> tagIds) => domain.Task(
    id: row.id,
    title: row.title,
    description: row.description,
    quadrant: domain.TaskQuadrant.fromCode(row.quadrant),
    status: domain.TaskStatus.fromCode(row.status),
    dueAtUtc: _asUtc(row.dueAtUtc),
    parentId: row.parentId,
    depth: row.depth,
    sortOrder: row.sortOrder,
    tagIds: tagIds,
    projectId: row.projectId,
    checklistGroupId: row.checklistGroupId,
    version: row.version,
    deletedAtUtc: _asUtc(row.deletedAtUtc),
    createdAtUtc: _asUtc(row.createdAtUtc)!,
    updatedAtUtc: _asUtc(row.updatedAtUtc)!,
    completedAtUtc: _asUtc(row.completedAtUtc),
    dirty: row.dirty,
    updatedByDeviceId: row.updatedByDeviceId,
  );

  LocalTasksCompanion toLocal(domain.Task task) => LocalTasksCompanion(
    id: Value<String>(task.id),
    title: Value<String>(task.title),
    description: Value<String?>(task.description),
    quadrant: Value<int>(task.quadrant.code),
    status: Value<int>(task.status.code),
    dueAtUtc: Value<DateTime?>(task.dueAtUtc),
    parentId: Value<String?>(task.parentId),
    depth: Value<int>(task.depth),
    sortOrder: Value<int>(task.sortOrder),
    projectId: Value<String?>(task.projectId),
    checklistGroupId: Value<String?>(task.checklistGroupId),
    version: Value<int>(task.version),
    deletedAtUtc: Value<DateTime?>(task.deletedAtUtc),
    createdAtUtc: Value<DateTime>(task.createdAtUtc),
    updatedAtUtc: Value<DateTime>(task.updatedAtUtc),
    completedAtUtc: Value<DateTime?>(task.completedAtUtc),
    dirty: Value<bool>(task.dirty),
    updatedByDeviceId: Value<String>(task.updatedByDeviceId),
  );

  Map<String, Object?> toWire(domain.Task task, {Set<String>? fields}) {
    final complete = <String, Object?>{
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'quadrant': task.quadrant.code,
      'status': task.status.code,
      'due_at': task.dueAtUtc?.toIso8601String(),
      'parent_id': task.parentId,
      'depth': task.depth,
      'sort_order': task.sortOrder,
      'tag_ids': task.tagIds.toList(growable: false)..sort(),
      'project_id': task.projectId,
      'checklist_group_id': task.checklistGroupId,
      'deleted_at': task.deletedAtUtc?.toIso8601String(),
      'created_at': task.createdAtUtc.toIso8601String(),
      'updated_at': task.updatedAtUtc.toIso8601String(),
      'completed_at': task.completedAtUtc?.toIso8601String(),
      'updated_by_device_id': task.updatedByDeviceId,
    };
    if (fields == null) {
      return complete;
    }
    return <String, Object?>{
      for (final field in fields)
        if (complete.containsKey(field)) field: complete[field],
    };
  }

  String encodeOperation({
    required domain.Task task,
    required Set<String> changedFields,
  }) => jsonEncode(<String, Object?>{
    'changes': toWire(task, fields: changedFields),
    'changed_fields': changedFields.toList(growable: false)..sort(),
  });

  DateTime? _asUtc(DateTime? value) => value?.toUtc();
}
