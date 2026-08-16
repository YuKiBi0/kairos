class Blocker {
  Blocker({
    required this.id,
    required this.taskId,
    required String body,
    required this.resolved,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.resolvedAtUtc,
    this.version = 0,
    this.deletedAtUtc,
  }) : body = _validateBody(body);

  final String id;
  final String taskId;
  final String body;
  final bool resolved;
  final DateTime? resolvedAtUtc;
  final int version;
  final DateTime? deletedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  bool get isDeleted => deletedAtUtc != null;

  static String _validateBody(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.runes.length > 1000) {
      throw const FormatException(
        'Blocker body must contain between 1 and 1000 Unicode characters.',
      );
    }
    return normalized;
  }
}
