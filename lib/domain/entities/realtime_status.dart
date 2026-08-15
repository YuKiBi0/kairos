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
    this.serverCursor = 0,
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
  final int serverCursor;
  final LinkError? lastError;
}

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
