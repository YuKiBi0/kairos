import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../local/database.dart';

typedef ExportDirectoryProvider = Future<Directory> Function();

class ExportResult {
  const ExportResult({
    required this.filePath,
    required this.taskCount,
    required this.blockerCount,
    this.pendingOperationCount = 0,
  });

  final String filePath;
  final int taskCount;
  final int blockerCount;
  final int pendingOperationCount;
}

class JsonExportService {
  JsonExportService({
    required AppDatabase database,
    ExportDirectoryProvider? directoryProvider,
    DateTime Function()? now,
  }) : _database = database,
       _directoryProvider = directoryProvider ?? _defaultExportDirectory,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final ExportDirectoryProvider _directoryProvider;
  final DateTime Function() _now;

  Future<ExportResult> export() => _export(includeOutbox: false);

  Future<ExportResult> exportRecovery() => _export(includeOutbox: true);

  Future<ExportResult> _export({required bool includeOutbox}) async {
    final tasks = await _database.select(_database.localTasks).get();
    final blockers = await _database.select(_database.localBlockers).get();
    final tags = await _database.select(_database.localTags).get();
    final projects = await _database.select(_database.localProjects).get();
    final groups = await _database.select(_database.localChecklistGroups).get();
    final taskTags = await _database.select(_database.taskTags).get();
    final outbox = includeOutbox
        ? await _database.select(_database.outboxOperations).get()
        : const <OutboxOperation>[];
    final exportedAt = _now().toUtc();
    final document = <String, Object?>{
      'format': 'kairos-export',
      'schema_version': 1,
      'exported_at': exportedAt.toIso8601String(),
      if (includeOutbox) 'recovery_mode': true,
      'tasks': <Map<String, Object?>>[
        for (final task in tasks)
          <String, Object?>{
            'id': task.id,
            'title': task.title,
            'description': task.description,
            'quadrant': task.quadrant,
            'status': task.status,
            'due_at': _time(task.dueAtUtc),
            'parent_id': task.parentId,
            'depth': task.depth,
            'sort_order': task.sortOrder,
            'project_id': task.projectId,
            'checklist_group_id': task.checklistGroupId,
            'version': task.version,
            'deleted_at': _time(task.deletedAtUtc),
            'created_at': _time(task.createdAtUtc),
            'updated_at': _time(task.updatedAtUtc),
            'completed_at': _time(task.completedAtUtc),
            'tag_ids':
                taskTags
                    .where((link) => link.taskId == task.id)
                    .map((link) => link.tagId)
                    .toList(growable: false)
                  ..sort(),
          },
      ],
      'blockers': <Map<String, Object?>>[
        for (final blocker in blockers)
          <String, Object?>{
            'id': blocker.id,
            'task_id': blocker.taskId,
            'body': blocker.body,
            'resolved': blocker.resolved,
            'resolved_at': _time(blocker.resolvedAtUtc),
            'version': blocker.version,
            'deleted_at': _time(blocker.deletedAtUtc),
            'created_at': _time(blocker.createdAtUtc),
            'updated_at': _time(blocker.updatedAtUtc),
          },
      ],
      'tags': <Map<String, Object?>>[
        for (final tag in tags)
          <String, Object?>{
            'id': tag.id,
            'name': tag.name,
            'color_token': tag.colorToken,
            'archived': tag.archived,
            'version': tag.version,
            'updated_at': _time(tag.updatedAtUtc),
          },
      ],
      'projects': <Map<String, Object?>>[
        for (final project in projects)
          <String, Object?>{
            'id': project.id,
            'name': project.name,
            'archived': project.archived,
            'version': project.version,
            'updated_at': _time(project.updatedAtUtc),
          },
      ],
      'checklist_groups': <Map<String, Object?>>[
        for (final group in groups)
          <String, Object?>{
            'id': group.id,
            'name': group.name,
            'archived': group.archived,
            'version': group.version,
            'updated_at': _time(group.updatedAtUtc),
          },
      ],
      if (includeOutbox)
        'outbox_operations': <Map<String, Object?>>[
          for (final operation in outbox)
            <String, Object?>{
              'operation_id': operation.operationId,
              'entity_type': operation.entityType,
              'entity_id': operation.entityId,
              'base_version': operation.baseVersion,
              'payload': _decodePayload(operation.payload),
              'created_at': _time(operation.createdAtUtc),
              'attempt_count': operation.attemptCount,
              'next_attempt_at': _time(operation.nextAttemptAtUtc),
              'last_error': operation.lastError,
            },
        ],
    };
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final stamp = exportedAt
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    final prefix = includeOutbox ? 'kairos-recovery' : 'kairos-export';
    final file = File(path.join(directory.path, '$prefix-$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
      flush: true,
    );
    return ExportResult(
      filePath: file.path,
      taskCount: tasks.length,
      blockerCount: blockers.length,
      pendingOperationCount: outbox.length,
    );
  }

  String? _time(DateTime? value) => value?.toUtc().toIso8601String();

  Object? _decodePayload(String value) {
    try {
      return jsonDecode(value);
    } on Object {
      return value;
    }
  }
}

Future<Directory> _defaultExportDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }
  } on Object {
    // Android versions without a downloads provider use app documents.
  }
  return getApplicationDocumentsDirectory();
}
