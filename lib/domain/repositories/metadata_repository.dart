import '../entities/blocker.dart';
import '../entities/taxonomy.dart';

abstract interface class MetadataRepository {
  Stream<Map<String, int>> watchUnresolvedBlockerCounts();

  Stream<List<Blocker>> watchBlockers(String taskId);

  Future<Blocker> addBlocker(String taskId, String body);

  Future<Blocker> setBlockerResolved(String id, {required bool resolved});

  Future<void> deleteBlocker(String id);

  Stream<List<Tag>> watchTags();

  Future<Tag> createTag(String name, {String? colorToken});

  Future<Tag> renameTag(String id, String name);

  Future<void> deleteTag(String id);

  Stream<List<Project>> watchProjects();

  Future<Project> createProject(String name);

  Future<Project> renameProject(String id, String name);

  Future<Project> setProjectArchived(String id, {required bool archived});

  Stream<List<ChecklistGroup>> watchChecklistGroups();

  Future<ChecklistGroup> createChecklistGroup(String name);

  Future<ChecklistGroup> renameChecklistGroup(String id, String name);

  Future<ChecklistGroup> setChecklistGroupArchived(
    String id, {
    required bool archived,
  });
}
