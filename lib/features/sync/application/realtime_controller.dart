import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../data/remote/realtime_socket.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/entities/realtime_status.dart';
import '../../../domain/repositories/settings_repository.dart';
import 'auth_controller.dart';

typedef StatusSink = void Function(RealtimeStatus status);
typedef EventsSink = void Function(List<HealthEvent> events);
typedef SyncCallback = Future<SyncOutcome> Function();

abstract interface class RealtimeActions {
  Future<void> checkConnection();

  Future<void> reconnect();

  Future<void> synchronizeNow();
}

class RealtimeController implements RealtimeActions {
  RealtimeController({
    required SettingsRepository settings,
    required AccessTokenProvider auth,
    required RealtimeConnector connector,
    required NetworkMonitor network,
    required SyncCallback synchronize,
    required StatusSink onStatus,
    required EventsSink onEvents,
    DateTime Function()? now,
    Uuid uuid = const Uuid(),
    List<Duration> retrySchedule = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 32),
      Duration(seconds: 60),
    ],
  }) : _settings = settings,
       _auth = auth,
       _connector = connector,
       _network = network,
       _synchronize = synchronize,
       _onStatus = onStatus,
       _onEvents = onEvents,
       _now = now ?? DateTime.now,
       _uuid = uuid,
       _retrySchedule = retrySchedule,
       _status = const RealtimeStatus.unconfigured() {
    _networkSubscription = _network.changes.listen(_networkChanged);
    unawaited(_loadNetworkState());
  }

  final SettingsRepository _settings;
  final AccessTokenProvider _auth;
  final RealtimeConnector _connector;
  final NetworkMonitor _network;
  final SyncCallback _synchronize;
  final StatusSink _onStatus;
  final EventsSink _onEvents;
  final DateTime Function() _now;
  final Uuid _uuid;
  final List<Duration> _retrySchedule;

  RealtimeStatus _status;
  final List<HealthEvent> _events = <HealthEvent>[];
  final Map<String, ({DateTime sentAt, Completer<void> completion})>
  _pendingProbes = <String, ({DateTime sentAt, Completer<void> completion})>{};
  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<Object?>? _messageSubscription;
  RealtimeSocket? _socket;
  Timer? _retryTimer;
  Timer? _heartbeatTimer;
  Duration _heartbeatInterval = const Duration(seconds: 15);
  bool _enabled = false;
  bool _online = true;
  bool _connecting = false;
  bool _syncRunning = false;
  bool _syncRequested = false;
  bool _disposed = false;
  int _generation = 0;
  int _retryIndex = 0;

  RealtimeStatus get status => _status;

  void authStateChanged(AuthState authState) {
    final hasSession = authState.session != null;
    final authenticated =
        authState.phase == AuthPhase.authenticated ||
        (authState.phase == AuthPhase.error && hasSession);
    if (authenticated) {
      _enabled = true;
      unawaited(connect());
      return;
    }
    _enabled = false;
    final expired = authState.phase == AuthPhase.error && !hasSession;
    unawaited(
      _stop(
        state: expired
            ? RealtimeConnectionState.authExpired
            : RealtimeConnectionState.unconfigured,
      ),
    );
  }

  void localSyncStateChanged({required int cursor, required int pending}) {
    _emit(_status.copyWith(serverCursor: cursor, pendingOperations: pending));
  }

  Future<void> connect({bool manual = false}) async {
    if (_disposed || !_enabled || !_online || (_connecting && !manual)) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _connecting = true;
    final generation = ++_generation;
    await _closeSocket();
    final endpointRaw = await _settings.readServiceEndpoint();
    final accessToken = await _auth.accessToken();
    if (_disposed || generation != _generation) {
      _connecting = false;
      return;
    }
    if (endpointRaw == null || accessToken == null) {
      _connecting = false;
      _enabled = false;
      _emit(
        _status.copyWith(
          state: RealtimeConnectionState.unconfigured,
          endpoint: null,
          retryAtUtc: null,
          lastError: null,
        ),
      );
      return;
    }
    final endpoint = _realtimeEndpoint(Uri.parse(endpointRaw));
    _emit(
      _status.copyWith(
        state: manual || _status.reconnectCount == 0
            ? RealtimeConnectionState.connecting
            : RealtimeConnectionState.reconnecting,
        endpoint: endpoint,
        retryAtUtc: null,
        lastError: null,
      ),
    );
    _addEvent('连接', 'WebSocket', details: _safeAuthority(endpoint));
    try {
      final socket = _connector.connect(endpoint, accessToken);
      await socket.ready;
      if (_disposed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      _messageSubscription = socket.messages.listen(
        (message) => _messageReceived(generation, message),
        onError: (Object error, StackTrace stackTrace) =>
            _connectionLost(generation, error),
        onDone: () => _connectionLost(generation, null),
        cancelOnError: true,
      );
    } on Object catch (error) {
      if (generation == _generation) {
        _scheduleReconnect(error);
      }
    } finally {
      if (generation == _generation) {
        _connecting = false;
      }
    }
  }

  @override
  Future<void> checkConnection() async {
    final socket = _socket;
    if (socket == null || _status.state != RealtimeConnectionState.healthy) {
      await reconnect();
      return;
    }
    final probeId = _uuid.v4();
    final completion = Completer<void>();
    _pendingProbes[probeId] = (sentAt: _now().toUtc(), completion: completion);
    socket.send(
      jsonEncode(<String, Object?>{
        'type': 'heartbeat_probe',
        'probe_id': probeId,
      }),
    );
    _addEvent('检查连接', 'WebSocket');
    try {
      await completion.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (_pendingProbes.remove(probeId) == null || _disposed) {
        return;
      }
      _emit(
        _status.copyWith(
          heartbeatFailures: _status.heartbeatFailures + 1,
          lastError: const LinkError(
            code: 'HEARTBEAT_TIMEOUT',
            stage: 'heartbeat',
            message: '连接检查超时',
            suggestion: '检查网络后立即重连',
          ),
        ),
      );
      _addEvent('连接检查失败', 'heartbeat', errorCode: 'HEARTBEAT_TIMEOUT');
    }
  }

  @override
  Future<void> reconnect() async {
    _retryIndex = 0;
    _emit(_status.copyWith(reconnectCount: _status.reconnectCount + 1));
    await connect(manual: true);
  }

  @override
  Future<void> synchronizeNow() async {
    _syncRequested = true;
    if (_syncRunning || _disposed) {
      return;
    }
    _syncRunning = true;
    try {
      while (_syncRequested && !_disposed) {
        _syncRequested = false;
        try {
          final outcome = await _synchronize();
          _emit(
            _status.copyWith(
              lastIncrementalSyncAtUtc: outcome.completedAtUtc,
              serverCursor: outcome.cursor,
              pendingOperations: outcome.pending,
              lastSyncResult:
                  '成功：拉取 ${outcome.pulled}，上传 ${outcome.pushed}，冲突 ${outcome.conflicts}',
            ),
          );
          _addEvent('增量同步完成', 'HTTP', details: 'cursor=${outcome.cursor}');
        } on Object catch (error) {
          _emit(
            _status.copyWith(lastSyncResult: '失败：${_safeErrorMessage(error)}'),
          );
          _addEvent('增量同步失败', 'HTTP', errorCode: _errorCode(error));
        }
      }
    } finally {
      _syncRunning = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    _retryTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _networkSubscription?.cancel();
    await _closeSocket();
  }

  Future<void> _loadNetworkState() async {
    try {
      _networkChanged(await _network.isOnline());
    } on Object {
      _networkChanged(true);
    }
  }

  void _networkChanged(bool online) {
    if (_disposed || online == _online) {
      return;
    }
    _online = online;
    if (!online) {
      _retryTimer?.cancel();
      _heartbeatTimer?.cancel();
      _generation++;
      unawaited(_closeSocket());
      _emit(
        _status.copyWith(
          state: RealtimeConnectionState.offline,
          retryAtUtc: null,
          lastError: null,
        ),
      );
      _addEvent('设备离线', 'network');
      return;
    }
    _addEvent('网络恢复', 'network');
    if (_enabled) {
      unawaited(connect(manual: true));
    }
  }

  void _messageReceived(int generation, Object? message) {
    if (_disposed || generation != _generation) {
      return;
    }
    try {
      final decoded = jsonDecode(message as String);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      switch (decoded['type']) {
        case 'ready':
          _ready(decoded);
        case 'heartbeat':
          _heartbeat(decoded);
        case 'heartbeat_probe_ack':
          _probeAcknowledged(decoded);
        case 'change_hint':
          _changeHint(decoded);
        case 'error':
          _serverError(decoded);
      }
    } on FormatException {
      _addEvent('忽略无效消息', 'WebSocket', errorCode: 'INVALID_MESSAGE');
    } on TypeError {
      _addEvent('忽略无效消息', 'WebSocket', errorCode: 'INVALID_MESSAGE');
    }
  }

  void _ready(Map<String, dynamic> message) {
    final interval = (message['heartbeat_interval_sec'] as num?)?.toInt();
    if (interval != null && interval > 0) {
      _heartbeatInterval = Duration(seconds: interval);
    }
    _retryIndex = 0;
    _emit(
      _status.copyWith(
        state: RealtimeConnectionState.healthy,
        retryAtUtc: null,
        retryInterval: Duration.zero,
        lastError: null,
      ),
    );
    _resetHeartbeatWatchdog();
    _addEvent('通知通道在线', 'WebSocket');
    unawaited(synchronizeNow());
  }

  void _heartbeat(Map<String, dynamic> message) {
    final now = _now().toUtc();
    _socket?.send(
      jsonEncode(<String, Object?>{
        'type': 'heartbeat_ack',
        'client_time': now.toIso8601String(),
      }),
    );
    _emit(
      _status.copyWith(
        state: RealtimeConnectionState.healthy,
        lastHeartbeatAtUtc: now,
        heartbeatSuccesses: _status.heartbeatSuccesses + 1,
        heartbeatFailures: 0,
        lastError: null,
      ),
    );
    _resetHeartbeatWatchdog();
    _addEvent('收到心跳', 'heartbeat');
    unawaited(synchronizeNow());
  }

  void _probeAcknowledged(Map<String, dynamic> message) {
    final probeId = message['probe_id'];
    if (probeId is! String) {
      return;
    }
    final pending = _pendingProbes.remove(probeId);
    if (pending == null) {
      return;
    }
    final elapsed = _now().toUtc().difference(pending.sentAt).inMilliseconds;
    _emit(
      _status.copyWith(
        lastHeartbeatAtUtc: _now().toUtc(),
        roundTripMs: elapsed < 0 ? 0 : elapsed,
        heartbeatSuccesses: _status.heartbeatSuccesses + 1,
        heartbeatFailures: 0,
        lastError: null,
      ),
    );
    _addEvent('连接检查成功', 'heartbeat', latencyMs: elapsed);
    pending.completion.complete();
  }

  void _changeHint(Map<String, dynamic> message) {
    final entityType = message['entity_type'] as String? ?? 'unknown';
    final cursor = (message['cursor'] as num?)?.toInt();
    _emit(
      _status.copyWith(
        lastNotificationAtUtc: _now().toUtc(),
        lastNotificationType: entityType,
      ),
    );
    _addEvent(
      '收到变更通知',
      'WebSocket',
      details: '$entityType${cursor == null ? '' : ' cursor=$cursor'}',
    );
    unawaited(synchronizeNow());
  }

  void _serverError(Map<String, dynamic> message) {
    final code = message['code'] as String? ?? 'SERVER_ERROR';
    final authExpired = code == 'AUTH_EXPIRED' || code == 'UNAUTHORIZED';
    final error = LinkError(
      code: code,
      stage: 'server',
      message: message['message'] as String? ?? '服务端拒绝实时连接',
      suggestion: authExpired ? '在同步设置中重新登录' : '检查同步服务状态',
    );
    _addEvent('服务端错误', 'server', errorCode: code);
    if (authExpired) {
      _enabled = false;
      unawaited(
        _stop(state: RealtimeConnectionState.authExpired, error: error),
      );
    } else {
      _scheduleReconnect(error);
    }
  }

  void _connectionLost(int generation, Object? error) {
    if (_disposed || generation != _generation) {
      return;
    }
    _scheduleReconnect(error ?? StateError('WebSocket connection closed.'));
  }

  void _scheduleReconnect(Object error) {
    if (_disposed || !_enabled || !_online) {
      return;
    }
    final linkError = error is LinkError ? error : _linkError(error);
    if (linkError.code == 'UNAUTHORIZED') {
      _enabled = false;
      unawaited(
        _stop(state: RealtimeConnectionState.authExpired, error: linkError),
      );
      return;
    }
    _heartbeatTimer?.cancel();
    unawaited(_closeSocket());
    final index = _retryIndex.clamp(0, _retrySchedule.length - 1);
    final delay = _retrySchedule[index];
    _retryIndex++;
    final failedPermanently = _retryIndex >= _retrySchedule.length;
    _emit(
      _status.copyWith(
        state: failedPermanently
            ? RealtimeConnectionState.error
            : RealtimeConnectionState.reconnecting,
        reconnectCount: _status.reconnectCount + 1,
        retryAtUtc: _now().toUtc().add(delay),
        retryInterval: delay,
        lastError: linkError,
      ),
    );
    _addEvent('连接中断', linkError.stage, errorCode: linkError.code);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(connect()));
  }

  void _resetHeartbeatWatchdog() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(_heartbeatInterval * 2, () {
      _emit(
        _status.copyWith(
          heartbeatFailures: _status.heartbeatFailures + 1,
          lastError: const LinkError(
            code: 'HEARTBEAT_TIMEOUT',
            stage: 'heartbeat',
            message: '连续心跳超时',
            suggestion: '检查网络或同步服务状态',
          ),
        ),
      );
      _scheduleReconnect(
        const LinkError(
          code: 'HEARTBEAT_TIMEOUT',
          stage: 'heartbeat',
          message: '连续心跳超时',
          suggestion: '检查网络或同步服务状态',
        ),
      );
    });
  }

  Future<void> _stop({
    required RealtimeConnectionState state,
    LinkError? error,
  }) async {
    _generation++;
    _retryTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _closeSocket();
    _emit(
      _status.copyWith(
        state: state,
        retryAtUtc: null,
        retryInterval: Duration.zero,
        lastError: error,
      ),
    );
  }

  Future<void> _closeSocket() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close(1000, 'client state changed');
      } on Object {
        // Closing a failed channel is best-effort.
      }
    }
  }

  void _emit(RealtimeStatus next) {
    _status = next;
    if (!_disposed) {
      _onStatus(next);
    }
  }

  void _addEvent(
    String type,
    String stage, {
    int? latencyMs,
    String? errorCode,
    String? details,
  }) {
    _events.insert(
      0,
      HealthEvent(
        type: type,
        stage: stage,
        occurredAtUtc: _now().toUtc(),
        latencyMs: latencyMs,
        errorCode: errorCode,
        details: details,
      ),
    );
    if (_events.length > 50) {
      _events.removeRange(50, _events.length);
    }
    if (!_disposed) {
      _onEvents(List<HealthEvent>.unmodifiable(_events));
    }
  }

  Uri _realtimeEndpoint(Uri endpoint) {
    final base = endpoint.resolve('/api/v1/realtime');
    return base.replace(
      scheme: switch (base.scheme) {
        'https' => 'wss',
        'http' => 'ws',
        final value => value,
      },
      query: '',
      fragment: '',
    );
  }

  String _safeAuthority(Uri endpoint) =>
      endpoint.replace(path: '', query: '', fragment: '').toString();

  LinkError _linkError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('401') ||
        raw.contains('403') ||
        raw.contains('unauthor')) {
      return const LinkError(
        code: 'UNAUTHORIZED',
        stage: 'authentication',
        message: '实时连接认证失败',
        suggestion: '在同步设置中重新登录',
      );
    }
    if (raw.contains('certificate') || raw.contains('handshake')) {
      return const LinkError(
        code: 'TLS_HANDSHAKE_FAILED',
        stage: 'TLS',
        message: '安全连接握手失败',
        suggestion: '确认服务器证书有效且域名匹配',
      );
    }
    if (raw.contains('host lookup') || raw.contains('name resolution')) {
      return const LinkError(
        code: 'DNS_LOOKUP_FAILED',
        stage: 'DNS',
        message: '无法解析同步服务地址',
        suggestion: '检查同步服务地址和 DNS 设置',
      );
    }
    return const LinkError(
      code: 'CONNECTION_FAILED',
      stage: 'connect',
      message: '无法连接实时通知服务',
      suggestion: '确认服务正在运行并检查网络',
    );
  }

  String _errorCode(Object error) => error.runtimeType.toString();

  String _safeErrorMessage(Object error) {
    final text = error.toString();
    return text.length <= 160 ? text : '${text.substring(0, 157)}...';
  }
}
