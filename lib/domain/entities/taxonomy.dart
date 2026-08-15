class Tag {
  Tag({
    required this.id,
    required String name,
    required this.updatedAtUtc,
    this.colorToken,
    this.archived = false,
    this.version = 0,
  }) : name = TaxonomyName.validate(name);

  final String id;
  final String name;
  final String? colorToken;
  final bool archived;
  final int version;
  final DateTime updatedAtUtc;
}

class Project {
  Project({
    required this.id,
    required String name,
    required this.updatedAtUtc,
    this.archived = false,
    this.version = 0,
  }) : name = TaxonomyName.validate(name);

  final String id;
  final String name;
  final bool archived;
  final int version;
  final DateTime updatedAtUtc;
}

class ChecklistGroup {
  ChecklistGroup({
    required this.id,
    required String name,
    required this.updatedAtUtc,
    this.archived = false,
    this.version = 0,
  }) : name = TaxonomyName.validate(name);

  final String id;
  final String name;
  final bool archived;
  final int version;
  final DateTime updatedAtUtc;
}

abstract final class TaxonomyName {
  static String validate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.runes.length > 100) {
      throw const FormatException(
        'Name must contain between 1 and 100 Unicode characters.',
      );
    }
    return normalized;
  }
}
