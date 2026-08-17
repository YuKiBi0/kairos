class RemoteUser {
  const RemoteUser({required this.id, required this.username});

  factory RemoteUser.fromJson(Map<String, dynamic> json) => switch (json) {
    {'id': String id, 'username': String username} => RemoteUser(
      id: id,
      username: username,
    ),
    _ => throw const FormatException('Invalid remote user.'),
  };

  final String id;
  final String username;
}

class RemoteDevice {
  const RemoteDevice({
    required this.id,
    required this.name,
    required this.platform,
  });

  factory RemoteDevice.fromJson(Map<String, dynamic> json) => switch (json) {
    {'id': String id, 'name': String name, 'platform': String platform} =>
      RemoteDevice(id: id, name: name, platform: platform),
    _ => throw const FormatException('Invalid remote device.'),
  };

  final String id;
  final String name;
  final String platform;
}

class RemoteSession {
  const RemoteSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtUtc,
    required this.user,
    required this.device,
  });

  factory RemoteSession.fromJson(Map<String, dynamic> json, DateTime nowUtc) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    final expiresIn = json['expires_in'];
    final user = json['user'];
    final device = json['device'];
    if (accessToken is! String ||
        refreshToken is! String ||
        expiresIn is! num ||
        user is! Map<String, dynamic> ||
        device is! Map<String, dynamic>) {
      throw const FormatException('Invalid authentication response.');
    }
    return RemoteSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAtUtc: nowUtc.add(Duration(seconds: expiresIn.toInt())),
      user: RemoteUser.fromJson(user),
      device: RemoteDevice.fromJson(device),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAtUtc;
  final RemoteUser user;
  final RemoteDevice device;
}

class RemoteChange {
  const RemoteChange({
    required this.cursor,
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required this.deleted,
    this.entity,
  });

  factory RemoteChange.fromJson(Map<String, dynamic> json) {
    final entity = json['entity'];
    return RemoteChange(
      cursor: (json['cursor'] as num).toInt(),
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      entityVersion: (json['entity_version'] as num).toInt(),
      deleted: json['deleted'] as bool,
      entity: entity == null ? null : entity as Map<String, dynamic>,
    );
  }

  final int cursor;
  final String entityType;
  final String entityId;
  final int entityVersion;
  final bool deleted;
  final Map<String, dynamic>? entity;
}

class RemoteChangesPage {
  const RemoteChangesPage({
    required this.changes,
    required this.nextCursor,
    required this.serverCursor,
    required this.hasMore,
  });

  final List<RemoteChange> changes;
  final int nextCursor;
  final int serverCursor;
  final bool hasMore;
}

class RemoteSyncStatus {
  const RemoteSyncStatus({required this.serverCursor, required this.deviceId});

  factory RemoteSyncStatus.fromJson(Map<String, dynamic> json) =>
      RemoteSyncStatus(
        serverCursor: (json['server_cursor'] as num).toInt(),
        deviceId: json['device_id'] as String,
      );

  final int serverCursor;
  final String deviceId;
}

class PushResult {
  const PushResult({
    required this.operationId,
    required this.status,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.cursor,
    required this.code,
    required this.conflictingFields,
    this.serverEntity,
  });

  factory PushResult.fromJson(Map<String, dynamic> json) => PushResult(
    operationId: json['operation_id'] as String,
    status: json['status'] as String,
    entityType: json['entity_type'] as String,
    entityId: json['entity_id'] as String,
    version: (json['version'] as num?)?.toInt() ?? 0,
    cursor: (json['cursor'] as num?)?.toInt() ?? 0,
    code: json['code'] as String?,
    conflictingFields:
        (json['conflicting_fields'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
    serverEntity: json['server_entity'] as Map<String, dynamic>?,
  );

  final String operationId;
  final String status;
  final String entityType;
  final String entityId;
  final int version;
  final int cursor;
  final String? code;
  final List<String> conflictingFields;
  final Map<String, dynamic>? serverEntity;
}
