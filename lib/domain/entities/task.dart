enum TaskQuadrant {
  importantUrgent(1, 'important_urgent', '重要且紧急'),
  importantNotUrgent(2, 'important_not_urgent', '重要不紧急'),
  notImportantUrgent(3, 'not_important_urgent', '不重要但紧急'),
  notImportantNotUrgent(4, 'not_important_not_urgent', '不重要不紧急');

  const TaskQuadrant(this.code, this.wireName, this.label);

  final int code;
  final String wireName;
  final String label;

  static TaskQuadrant fromCode(int code) => switch (code) {
    1 => importantUrgent,
    2 => importantNotUrgent,
    3 => notImportantUrgent,
    4 => notImportantNotUrgent,
    _ => throw FormatException('Unknown task quadrant code: $code'),
  };

  static TaskQuadrant fromWireName(String value) => switch (value) {
    'important_urgent' => importantUrgent,
    'important_not_urgent' => importantNotUrgent,
    'not_important_urgent' => notImportantUrgent,
    'not_important_not_urgent' => notImportantNotUrgent,
    _ => throw FormatException('Unknown task quadrant: $value'),
  };
}

enum TaskStatus {
  notStarted(0, 'not_started', '未开始'),
  inProgress(1, 'in_progress', '进行中'),
  completed(2, 'completed', '已完成'),
  archived(3, 'archived', '已归档');

  const TaskStatus(this.code, this.wireName, this.label);

  final int code;
  final String wireName;
  final String label;

  bool get isCompleted => this == completed;

  static TaskStatus fromCode(int code) => switch (code) {
    0 => notStarted,
    1 => inProgress,
    2 => completed,
    3 => archived,
    _ => throw FormatException('Unknown task status code: $code'),
  };

  static TaskStatus fromWireName(String value) => switch (value) {
    'not_started' => notStarted,
    'in_progress' => inProgress,
    'completed' => completed,
    'archived' => archived,
    _ => throw FormatException('Unknown task status: $value'),
  };
}

const Object _unset = Object();

class Task {
  Task({
    required this.id,
    required String title,
    required this.quadrant,
    required this.status,
    required this.depth,
    required this.sortOrder,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.updatedByDeviceId,
    this.description,
    this.dueAtUtc,
    this.parentId,
    Set<String> tagIds = const <String>{},
    this.projectId,
    this.checklistGroupId,
    this.completedAtUtc,
    this.deletedAtUtc,
    this.version = 0,
    this.dirty = true,
  }) : title = validateTitle(title),
       tagIds = Set<String>.unmodifiable(tagIds) {
    if (id.isEmpty) {
      throw const FormatException('Task id cannot be empty.');
    }
    if (depth < 1 || depth > 5) {
      throw RangeError.range(depth, 1, 5, 'depth');
    }
    if (!createdAtUtc.isUtc || !updatedAtUtc.isUtc) {
      throw const FormatException('Task timestamps must be UTC.');
    }
    if (dueAtUtc != null && !dueAtUtc!.isUtc) {
      throw const FormatException('Task due time must be UTC.');
    }
  }

  factory Task.create({
    required String id,
    required String title,
    required String updatedByDeviceId,
    required DateTime nowUtc,
    TaskQuadrant quadrant = TaskQuadrant.importantNotUrgent,
    TaskStatus status = TaskStatus.notStarted,
    String? parentId,
    int depth = 1,
    int sortOrder = 0,
    String? description,
    DateTime? dueAtUtc,
    Set<String> tagIds = const <String>{},
    String? projectId,
    String? checklistGroupId,
  }) => Task(
    id: id,
    title: title,
    description: description,
    quadrant: quadrant,
    status: status,
    dueAtUtc: dueAtUtc,
    parentId: parentId,
    depth: depth,
    sortOrder: sortOrder,
    tagIds: tagIds,
    projectId: projectId,
    checklistGroupId: checklistGroupId,
    createdAtUtc: nowUtc,
    updatedAtUtc: nowUtc,
    completedAtUtc: status.isCompleted ? nowUtc : null,
    updatedByDeviceId: updatedByDeviceId,
  );

  final String id;
  final String title;
  final String? description;
  final TaskQuadrant quadrant;
  final TaskStatus status;
  final DateTime? dueAtUtc;
  final String? parentId;
  final int depth;
  final int sortOrder;
  final Set<String> tagIds;
  final String? projectId;
  final String? checklistGroupId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? completedAtUtc;
  final int version;
  final DateTime? deletedAtUtc;
  final bool dirty;
  final String updatedByDeviceId;

  bool get isDeleted => deletedAtUtc != null;

  Task copyWith({
    String? title,
    Object? description = _unset,
    TaskQuadrant? quadrant,
    TaskStatus? status,
    Object? dueAtUtc = _unset,
    Object? parentId = _unset,
    int? depth,
    int? sortOrder,
    Set<String>? tagIds,
    Object? projectId = _unset,
    Object? checklistGroupId = _unset,
    DateTime? updatedAtUtc,
    Object? completedAtUtc = _unset,
    int? version,
    Object? deletedAtUtc = _unset,
    bool? dirty,
    String? updatedByDeviceId,
  }) => Task(
    id: id,
    title: title ?? this.title,
    description: identical(description, _unset)
        ? this.description
        : description as String?,
    quadrant: quadrant ?? this.quadrant,
    status: status ?? this.status,
    dueAtUtc: identical(dueAtUtc, _unset)
        ? this.dueAtUtc
        : dueAtUtc as DateTime?,
    parentId: identical(parentId, _unset) ? this.parentId : parentId as String?,
    depth: depth ?? this.depth,
    sortOrder: sortOrder ?? this.sortOrder,
    tagIds: tagIds ?? this.tagIds,
    projectId: identical(projectId, _unset)
        ? this.projectId
        : projectId as String?,
    checklistGroupId: identical(checklistGroupId, _unset)
        ? this.checklistGroupId
        : checklistGroupId as String?,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    completedAtUtc: identical(completedAtUtc, _unset)
        ? this.completedAtUtc
        : completedAtUtc as DateTime?,
    version: version ?? this.version,
    deletedAtUtc: identical(deletedAtUtc, _unset)
        ? this.deletedAtUtc
        : deletedAtUtc as DateTime?,
    dirty: dirty ?? this.dirty,
    updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
  );

  static String validateTitle(String value) {
    final normalized = value.trim();
    final length = normalized.runes.length;
    if (length < 1 || length > 200) {
      throw FormatException(
        'Task title must contain between 1 and 200 Unicode characters.',
      );
    }
    return normalized;
  }
}
