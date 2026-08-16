import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/entities/app_preferences.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_filter.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/task_sorter.dart';
import '../local/database.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._database, {Uuid uuid = const Uuid()})
    : _uuid = uuid;

  static const String _preferencesKey = 'app_preferences';
  static const String _deviceIdKey = 'device_id';
  static const String _serviceEndpointKey = 'service_endpoint';

  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Stream<AppPreferences> watchPreferences() =>
      (_database.select(_database.localPreferences)
            ..where((table) => table.key.equals(_preferencesKey)))
          .watchSingleOrNull()
          .map((row) => _decodePreferences(row?.value));

  @override
  Future<AppPreferences> loadPreferences() async {
    final value = await _read(_preferencesKey);
    return _decodePreferences(value);
  }

  @override
  Future<void> savePreferences(AppPreferences preferences) => _write(
    _preferencesKey,
    jsonEncode(<String, Object?>{
      'view_mode': preferences.viewMode.name,
      'sort_mode': preferences.sortMode.name,
      'scope': preferences.scope.name,
      'search_text': preferences.searchText,
      'always_on_top': preferences.alwaysOnTop,
      'compact_workspace': preferences.compactWorkspace,
      'quadrants': preferences.quadrants
          .map((quadrant) => quadrant.wireName)
          .toList(growable: false),
      'statuses': preferences.statuses
          .map((status) => status.name)
          .toList(growable: false),
      'due_date_filter': preferences.dueDateFilter.name,
      'has_unresolved_blockers': preferences.hasUnresolvedBlockers,
      'tag_ids': preferences.tagIds.toList(growable: false)..sort(),
      'project_id': preferences.projectId,
      'checklist_group_id': preferences.checklistGroupId,
    }),
  );

  @override
  Future<String> getOrCreateDeviceId() => _database.transaction(() async {
    final existing = await _read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    await _write(_deviceIdKey, created);
    return created;
  });

  @override
  Future<String?> readServiceEndpoint() => _read(_serviceEndpointKey);

  @override
  Future<void> saveServiceEndpoint(String? endpoint) async {
    final normalized = endpoint?.trim();
    if (normalized == null || normalized.isEmpty) {
      await (_database.delete(
        _database.localPreferences,
      )..where((table) => table.key.equals(_serviceEndpointKey))).go();
      return;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Service endpoint must be an HTTP(S) base URL without credentials or query parameters.',
      );
    }
    await _write(_serviceEndpointKey, uri.toString());
  }

  Future<String?> _read(String key) async {
    final row = await (_database.select(
      _database.localPreferences,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) => _database
      .into(_database.localPreferences)
      .insertOnConflictUpdate(
        LocalPreferencesCompanion.insert(key: key, value: value),
      );

  AppPreferences _decodePreferences(String? source) {
    if (source == null) {
      return const AppPreferences();
    }
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      return AppPreferences(
        viewMode: TaskViewMode.values.byName(
          json['view_mode'] as String? ?? TaskViewMode.list.name,
        ),
        sortMode: TaskSortMode.values.byName(
          json['sort_mode'] as String? ?? TaskSortMode.executionPriority.name,
        ),
        scope: TaskScope.values.byName(
          json['scope'] as String? ?? TaskScope.all.name,
        ),
        searchText: json['search_text'] as String? ?? '',
        alwaysOnTop: json['always_on_top'] as bool? ?? false,
        compactWorkspace: json['compact_workspace'] as bool? ?? false,
        quadrants: (json['quadrants'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .map(TaskQuadrant.fromWireName)
            .toSet(),
        statuses: (json['statuses'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .map(TaskStatus.values.byName)
            .toSet(),
        dueDateFilter: DueDateFilter.values.byName(
          json['due_date_filter'] as String? ?? DueDateFilter.any.name,
        ),
        hasUnresolvedBlockers: json['has_unresolved_blockers'] as bool?,
        tagIds: (json['tag_ids'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toSet(),
        projectId: json['project_id'] as String?,
        checklistGroupId: json['checklist_group_id'] as String?,
      );
    } on Object {
      return const AppPreferences();
    }
  }
}
