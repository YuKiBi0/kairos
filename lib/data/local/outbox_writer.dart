import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

class OutboxWriter {
  const OutboxWriter(this._database, this._operationIdGenerator);

  final AppDatabase _database;
  final String Function() _operationIdGenerator;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required int baseVersion,
    required Map<String, Object?> payload,
    required DateTime createdAtUtc,
  }) async {
    await _database
        .into(_database.outboxOperations)
        .insert(
          OutboxOperationsCompanion.insert(
            operationId: _operationIdGenerator(),
            entityType: entityType,
            entityId: entityId,
            baseVersion: baseVersion,
            payload: jsonEncode(payload),
            createdAtUtc: createdAtUtc,
            nextAttemptAtUtc: createdAtUtc,
          ),
        );
    final current = await (_database.select(
      _database.syncStates,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    if (current == null) {
      await _database
          .into(_database.syncStates)
          .insert(const SyncStatesCompanion(pendingCount: Value<int>(1)));
      return;
    }
    await (_database.update(
      _database.syncStates,
    )..where((table) => table.id.equals(1))).write(
      SyncStatesCompanion(pendingCount: Value<int>(current.pendingCount + 1)),
    );
  }
}
