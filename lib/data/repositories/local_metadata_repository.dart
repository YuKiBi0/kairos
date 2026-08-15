import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/blocker.dart' as domain;
import '../../domain/entities/taxonomy.dart' as domain;
import '../../domain/repositories/metadata_repository.dart';
import '../local/database.dart';
import '../local/outbox_writer.dart';

class LocalMetadataRepository implements MetadataRepository {
  LocalMetadataRepository(
    this._database, {
    Uuid uuid = const Uuid(),
    String Function()? entityIdGenerator,
    String Function()? operationIdGenerator,
  }) : _entityIdGenerator = entityIdGenerator ?? uuid.v4,
       _outbox = OutboxWriter(_database, operationIdGenerator ?? uuid.v4);

  final AppDatabase _database;
  final String Function() _entityIdGenerator;
  final OutboxWriter _outbox;

  @override
  Stream<List<domain.Blocker>> watchBlockers(String taskId) =>
      (_database.select(_database.localBlockers)
            ..where(
              (table) =>
                  table.taskId.equals(taskId) & table.deletedAtUtc.isNull(),
            )
            ..orderBy(<OrderingTerm Function(LocalBlockers)>[
              (table) => OrderingTerm.asc(table.createdAtUtc),
            ]))
          .watch()
          .map((rows) => rows.map(_blockerFromLocal).toList(growable: false));

  @override
  Future<domain.Blocker> addBlocker(String taskId, String body) =>
      _database.transaction(() async {
        final task =
            await (_database.select(_database.localTasks)..where(
                  (table) =>
                      table.id.equals(taskId) & table.deletedAtUtc.isNull(),
                ))
                .getSingleOrNull();
        if (task == null) {
          throw StateError('Cannot add a blocker to a missing task.');
        }
        final nowUtc = DateTime.now().toUtc();
        final blocker = domain.Blocker(
          id: _entityIdGenerator(),
          taskId: taskId,
          body: body,
          resolved: false,
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
        );
        await _database
            .into(_database.localBlockers)
            .insert(
              LocalBlockersCompanion.insert(
                id: blocker.id,
                taskId: blocker.taskId,
                body: blocker.body,
                createdAtUtc: blocker.createdAtUtc,
                updatedAtUtc: blocker.updatedAtUtc,
              ),
            );
        await _enqueueBlocker(blocker, action: 'create');
        return blocker;
      });

  @override
  Future<domain.Blocker> setBlockerResolved(
    String id, {
    required bool resolved,
  }) => _database.transaction(() async {
    final row = await _blockerRow(id);
    final nowUtc = DateTime.now().toUtc();
    final updated = domain.Blocker(
      id: row.id,
      taskId: row.taskId,
      body: row.body,
      resolved: resolved,
      resolvedAtUtc: resolved ? nowUtc : null,
      version: row.version,
      deletedAtUtc: row.deletedAtUtc?.toUtc(),
      createdAtUtc: row.createdAtUtc.toUtc(),
      updatedAtUtc: nowUtc,
    );
    await (_database.update(
      _database.localBlockers,
    )..where((table) => table.id.equals(id))).write(
      LocalBlockersCompanion(
        resolved: Value<bool>(resolved),
        resolvedAtUtc: Value<DateTime?>(updated.resolvedAtUtc),
        updatedAtUtc: Value<DateTime>(nowUtc),
      ),
    );
    await _enqueueBlocker(updated, action: 'update');
    return updated;
  });

  @override
  Future<void> deleteBlocker(String id) => _database.transaction(() async {
    final row = await _blockerRow(id);
    final nowUtc = DateTime.now().toUtc();
    await (_database.update(
      _database.localBlockers,
    )..where((table) => table.id.equals(id))).write(
      LocalBlockersCompanion(
        deletedAtUtc: Value<DateTime>(nowUtc),
        updatedAtUtc: Value<DateTime>(nowUtc),
      ),
    );
    await _outbox.enqueue(
      entityType: 'blocker',
      entityId: id,
      baseVersion: row.version,
      payload: <String, Object?>{
        'action': 'delete',
        'changes': <String, Object?>{
          'deleted_at': nowUtc.toIso8601String(),
          'updated_at': nowUtc.toIso8601String(),
        },
      },
      createdAtUtc: nowUtc,
    );
  });

  @override
  Stream<List<domain.Tag>> watchTags() =>
      (_database.select(_database.localTags)
            ..orderBy(<OrderingTerm Function(LocalTags)>[
              (table) => OrderingTerm.asc(table.name),
            ]))
          .watch()
          .map((rows) => rows.map(_tagFromLocal).toList(growable: false));

  @override
  Future<domain.Tag> createTag(String name, {String? colorToken}) =>
      _database.transaction(() async {
        final nowUtc = DateTime.now().toUtc();
        final tag = domain.Tag(
          id: _entityIdGenerator(),
          name: name,
          colorToken: colorToken,
          updatedAtUtc: nowUtc,
        );
        await _database
            .into(_database.localTags)
            .insert(
              LocalTagsCompanion.insert(
                id: tag.id,
                name: tag.name,
                colorToken: Value<String?>(tag.colorToken),
                updatedAtUtc: nowUtc,
              ),
            );
        await _enqueueTaxonomy(
          action: 'create',
          entityType: 'tag',
          id: tag.id,
          name: tag.name,
          archived: false,
          version: 0,
          nowUtc: nowUtc,
          extra: <String, Object?>{'color_token': tag.colorToken},
        );
        return tag;
      });

  @override
  Future<domain.Tag> renameTag(String id, String name) =>
      _database.transaction(() async {
        final row = await (_database.select(
          _database.localTags,
        )..where((table) => table.id.equals(id))).getSingleOrNull();
        if (row == null) {
          throw StateError('Tag does not exist.');
        }
        final nowUtc = DateTime.now().toUtc();
        final validated = domain.TaxonomyName.validate(name);
        await (_database.update(
          _database.localTags,
        )..where((table) => table.id.equals(id))).write(
          LocalTagsCompanion(
            name: Value<String>(validated),
            updatedAtUtc: Value<DateTime>(nowUtc),
          ),
        );
        await _enqueueTaxonomy(
          action: 'update',
          entityType: 'tag',
          id: id,
          name: validated,
          archived: row.archived,
          version: row.version,
          nowUtc: nowUtc,
          extra: <String, Object?>{'color_token': row.colorToken},
        );
        return domain.Tag(
          id: id,
          name: validated,
          colorToken: row.colorToken,
          archived: row.archived,
          version: row.version,
          updatedAtUtc: nowUtc,
        );
      });

  @override
  Future<void> deleteTag(String id) => _database.transaction(() async {
    final row = await (_database.select(
      _database.localTags,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Tag does not exist.');
    }
    final nowUtc = DateTime.now().toUtc();
    await (_database.update(
      _database.localTags,
    )..where((table) => table.id.equals(id))).write(
      LocalTagsCompanion(
        archived: const Value<bool>(true),
        updatedAtUtc: Value<DateTime>(nowUtc),
      ),
    );
    await (_database.delete(
      _database.taskTags,
    )..where((table) => table.tagId.equals(id))).go();
    await _outbox.enqueue(
      entityType: 'tag',
      entityId: id,
      baseVersion: row.version,
      payload: <String, Object?>{'action': 'delete'},
      createdAtUtc: nowUtc,
    );
  });

  @override
  Stream<List<domain.Project>> watchProjects() =>
      (_database.select(_database.localProjects)
            ..orderBy(<OrderingTerm Function(LocalProjects)>[
              (table) => OrderingTerm.asc(table.name),
            ]))
          .watch()
          .map((rows) => rows.map(_projectFromLocal).toList(growable: false));

  @override
  Future<domain.Project> createProject(String name) =>
      _database.transaction(() async {
        final nowUtc = DateTime.now().toUtc();
        final project = domain.Project(
          id: _entityIdGenerator(),
          name: name,
          updatedAtUtc: nowUtc,
        );
        await _database
            .into(_database.localProjects)
            .insert(
              LocalProjectsCompanion.insert(
                id: project.id,
                name: project.name,
                updatedAtUtc: nowUtc,
              ),
            );
        await _enqueueTaxonomy(
          action: 'create',
          entityType: 'project',
          id: project.id,
          name: project.name,
          archived: false,
          version: 0,
          nowUtc: nowUtc,
        );
        return project;
      });

  @override
  Future<domain.Project> renameProject(String id, String name) async {
    final archived = await _projectArchived(id);
    return _writeProject(id, name: name, archived: archived);
  }

  @override
  Future<domain.Project> setProjectArchived(
    String id, {
    required bool archived,
  }) async {
    final row = await (_database.select(
      _database.localProjects,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Project does not exist.');
    }
    return _writeProject(id, name: row.name, archived: archived);
  }

  @override
  Stream<List<domain.ChecklistGroup>> watchChecklistGroups() =>
      (_database.select(_database.localChecklistGroups)
            ..orderBy(<OrderingTerm Function(LocalChecklistGroups)>[
              (table) => OrderingTerm.asc(table.name),
            ]))
          .watch()
          .map((rows) => rows.map(_checklistFromLocal).toList(growable: false));

  @override
  Future<domain.ChecklistGroup> createChecklistGroup(String name) =>
      _database.transaction(() async {
        final nowUtc = DateTime.now().toUtc();
        final group = domain.ChecklistGroup(
          id: _entityIdGenerator(),
          name: name,
          updatedAtUtc: nowUtc,
        );
        await _database
            .into(_database.localChecklistGroups)
            .insert(
              LocalChecklistGroupsCompanion.insert(
                id: group.id,
                name: group.name,
                updatedAtUtc: nowUtc,
              ),
            );
        await _enqueueTaxonomy(
          action: 'create',
          entityType: 'checklist_group',
          id: group.id,
          name: group.name,
          archived: false,
          version: 0,
          nowUtc: nowUtc,
        );
        return group;
      });

  @override
  Future<domain.ChecklistGroup> renameChecklistGroup(
    String id,
    String name,
  ) async {
    final archived = await _checklistArchived(id);
    return _writeChecklist(id, name: name, archived: archived);
  }

  @override
  Future<domain.ChecklistGroup> setChecklistGroupArchived(
    String id, {
    required bool archived,
  }) async {
    final row = await (_database.select(
      _database.localChecklistGroups,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Checklist group does not exist.');
    }
    return _writeChecklist(id, name: row.name, archived: archived);
  }

  Future<domain.Project> _writeProject(
    String id, {
    required String name,
    required bool archived,
  }) => _database.transaction(() async {
    final row = await (_database.select(
      _database.localProjects,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Project does not exist.');
    }
    final nowUtc = DateTime.now().toUtc();
    final validated = domain.TaxonomyName.validate(name);
    await (_database.update(
      _database.localProjects,
    )..where((table) => table.id.equals(id))).write(
      LocalProjectsCompanion(
        name: Value<String>(validated),
        archived: Value<bool>(archived),
        updatedAtUtc: Value<DateTime>(nowUtc),
      ),
    );
    await _enqueueTaxonomy(
      action: 'update',
      entityType: 'project',
      id: id,
      name: validated,
      archived: archived,
      version: row.version,
      nowUtc: nowUtc,
    );
    return domain.Project(
      id: id,
      name: validated,
      archived: archived,
      version: row.version,
      updatedAtUtc: nowUtc,
    );
  });

  Future<domain.ChecklistGroup> _writeChecklist(
    String id, {
    required String name,
    required bool archived,
  }) => _database.transaction(() async {
    final row = await (_database.select(
      _database.localChecklistGroups,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Checklist group does not exist.');
    }
    final nowUtc = DateTime.now().toUtc();
    final validated = domain.TaxonomyName.validate(name);
    await (_database.update(
      _database.localChecklistGroups,
    )..where((table) => table.id.equals(id))).write(
      LocalChecklistGroupsCompanion(
        name: Value<String>(validated),
        archived: Value<bool>(archived),
        updatedAtUtc: Value<DateTime>(nowUtc),
      ),
    );
    await _enqueueTaxonomy(
      action: 'update',
      entityType: 'checklist_group',
      id: id,
      name: validated,
      archived: archived,
      version: row.version,
      nowUtc: nowUtc,
    );
    return domain.ChecklistGroup(
      id: id,
      name: validated,
      archived: archived,
      version: row.version,
      updatedAtUtc: nowUtc,
    );
  });

  Future<bool> _projectArchived(String id) async {
    final row = await (_database.select(
      _database.localProjects,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Project does not exist.');
    }
    return row.archived;
  }

  Future<bool> _checklistArchived(String id) async {
    final row = await (_database.select(
      _database.localChecklistGroups,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Checklist group does not exist.');
    }
    return row.archived;
  }

  Future<LocalBlocker> _blockerRow(String id) async {
    final row = await (_database.select(
      _database.localBlockers,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Blocker does not exist.');
    }
    return row;
  }

  domain.Blocker _blockerFromLocal(LocalBlocker row) => domain.Blocker(
    id: row.id,
    taskId: row.taskId,
    body: row.body,
    resolved: row.resolved,
    resolvedAtUtc: row.resolvedAtUtc?.toUtc(),
    version: row.version,
    deletedAtUtc: row.deletedAtUtc?.toUtc(),
    createdAtUtc: row.createdAtUtc.toUtc(),
    updatedAtUtc: row.updatedAtUtc.toUtc(),
  );

  domain.Tag _tagFromLocal(LocalTag row) => domain.Tag(
    id: row.id,
    name: row.name,
    colorToken: row.colorToken,
    archived: row.archived,
    version: row.version,
    updatedAtUtc: row.updatedAtUtc.toUtc(),
  );

  domain.Project _projectFromLocal(LocalProject row) => domain.Project(
    id: row.id,
    name: row.name,
    archived: row.archived,
    version: row.version,
    updatedAtUtc: row.updatedAtUtc.toUtc(),
  );

  domain.ChecklistGroup _checklistFromLocal(LocalChecklistGroup row) =>
      domain.ChecklistGroup(
        id: row.id,
        name: row.name,
        archived: row.archived,
        version: row.version,
        updatedAtUtc: row.updatedAtUtc.toUtc(),
      );

  Future<void> _enqueueBlocker(
    domain.Blocker blocker, {
    required String action,
  }) => _outbox.enqueue(
    entityType: 'blocker',
    entityId: blocker.id,
    baseVersion: blocker.version,
    payload: <String, Object?>{
      'action': action,
      'changes': <String, Object?>{
        'id': blocker.id,
        'task_id': blocker.taskId,
        'body': blocker.body,
        'resolved': blocker.resolved,
        'resolved_at': blocker.resolvedAtUtc?.toIso8601String(),
        'created_at': blocker.createdAtUtc.toIso8601String(),
        'updated_at': blocker.updatedAtUtc.toIso8601String(),
      },
    },
    createdAtUtc: blocker.updatedAtUtc,
  );

  Future<void> _enqueueTaxonomy({
    required String action,
    required String entityType,
    required String id,
    required String name,
    required bool archived,
    required int version,
    required DateTime nowUtc,
    Map<String, Object?> extra = const <String, Object?>{},
  }) => _outbox.enqueue(
    entityType: entityType,
    entityId: id,
    baseVersion: version,
    payload: <String, Object?>{
      'action': action,
      'changes': <String, Object?>{
        'id': id,
        'name': name,
        'archived': archived,
        'updated_at': nowUtc.toIso8601String(),
        ...extra,
      },
    },
    createdAtUtc: nowUtc,
  );
}
