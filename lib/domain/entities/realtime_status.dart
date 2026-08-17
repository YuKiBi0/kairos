enum RealtimeConnectionState {
  unconfigured,
  offline,
  connecting,
  healthy,
  reconnecting,
  error,
  authExpired,
}

class LinkError {
  const LinkError({
    required this.code,
    required this.stage,
    required this.message,
    required this.suggestion,
  });

  final String code;
  final String stage;
  final String message;
  final String suggestion;
}

class RealtimeStatus {
  const RealtimeStatus({
    required this.state,
    this.endpoint,
    this.lastHeartbeatAtUtc,
    this.lastNotificationAtUtc,
    this.lastIncrementalSyncAtUtc,
    this.roundTripMs,
    this.reconnectCount = 0,
    this.retryAtUtc,
    this.retryInterval = Duration.zero,
    this.pendingOperations = 0,
    this.appliedCursor = 0,
    this.serverCursor = 0,
    this.heartbeatSuccesses = 0,
    this.heartbeatFailures = 0,
    this.lastNotificationType,
    this.lastSyncResult,
    this.lastError,
  });

  const RealtimeStatus.unconfigured()
    : this(state: RealtimeConnectionState.unconfigured);

  final RealtimeConnectionState state;
  final Uri? endpoint;
  final DateTime? lastHeartbeatAtUtc;
  final DateTime? lastNotificationAtUtc;
  final DateTime? lastIncrementalSyncAtUtc;
  final int? roundTripMs;
  final int reconnectCount;
  final DateTime? retryAtUtc;
  final Duration retryInterval;
  final int pendingOperations;
  final int appliedCursor;
  final int serverCursor;
  final int heartbeatSuccesses;
  final int heartbeatFailures;
  final String? lastNotificationType;
  final String? lastSyncResult;
  final LinkError? lastError;

  RealtimeStatus copyWith({
    RealtimeConnectionState? state,
    Object? endpoint = _notProvided,
    Object? lastHeartbeatAtUtc = _notProvided,
    Object? lastNotificationAtUtc = _notProvided,
    Object? lastIncrementalSyncAtUtc = _notProvided,
    Object? roundTripMs = _notProvided,
    int? reconnectCount,
    Object? retryAtUtc = _notProvided,
    Duration? retryInterval,
    int? pendingOperations,
    int? appliedCursor,
    int? serverCursor,
    int? heartbeatSuccesses,
    int? heartbeatFailures,
    Object? lastNotificationType = _notProvided,
    Object? lastSyncResult = _notProvided,
    Object? lastError = _notProvided,
  }) => RealtimeStatus(
    state: state ?? this.state,
    endpoint: endpoint == _notProvided ? this.endpoint : endpoint as Uri?,
    lastHeartbeatAtUtc: lastHeartbeatAtUtc == _notProvided
        ? this.lastHeartbeatAtUtc
        : lastHeartbeatAtUtc as DateTime?,
    lastNotificationAtUtc: lastNotificationAtUtc == _notProvided
        ? this.lastNotificationAtUtc
        : lastNotificationAtUtc as DateTime?,
    lastIncrementalSyncAtUtc: lastIncrementalSyncAtUtc == _notProvided
        ? this.lastIncrementalSyncAtUtc
        : lastIncrementalSyncAtUtc as DateTime?,
    roundTripMs: roundTripMs == _notProvided
        ? this.roundTripMs
        : roundTripMs as int?,
    reconnectCount: reconnectCount ?? this.reconnectCount,
    retryAtUtc: retryAtUtc == _notProvided
        ? this.retryAtUtc
        : retryAtUtc as DateTime?,
    retryInterval: retryInterval ?? this.retryInterval,
    pendingOperations: pendingOperations ?? this.pendingOperations,
    appliedCursor: appliedCursor ?? this.appliedCursor,
    serverCursor: serverCursor ?? this.serverCursor,
    heartbeatSuccesses: heartbeatSuccesses ?? this.heartbeatSuccesses,
    heartbeatFailures: heartbeatFailures ?? this.heartbeatFailures,
    lastNotificationType: lastNotificationType == _notProvided
        ? this.lastNotificationType
        : lastNotificationType as String?,
    lastSyncResult: lastSyncResult == _notProvided
        ? this.lastSyncResult
        : lastSyncResult as String?,
    lastError: lastError == _notProvided
        ? this.lastError
        : lastError as LinkError?,
  );
}

const Object _notProvided = Object();

class HealthEvent {
  const HealthEvent({
    required this.type,
    required this.stage,
    required this.occurredAtUtc,
    this.latencyMs,
    this.errorCode,
    this.details,
  });

  final String type;
  final String stage;
  final DateTime occurredAtUtc;
  final int? latencyMs;
  final String? errorCode;
  final String? details;
}
