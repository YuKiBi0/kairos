import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/remote/realtime_socket.dart';
import 'package:kairos/data/remote/remote_models.dart';
import 'package:kairos/data/sync/sync_engine.dart';
import 'package:kairos/domain/entities/app_preferences.dart';
import 'package:kairos/domain/entities/realtime_status.dart';
import 'package:kairos/domain/repositories/settings_repository.dart';
import 'package:kairos/features/sync/application/auth_controller.dart';
import 'package:kairos/features/sync/application/realtime_controller.dart';

void main() {
  late _FakeNetworkMonitor network;
  late _FakeRealtimeConnector connector;
  late List<RealtimeStatus> statuses;
  late List<HealthEvent> events;
  late RealtimeController controller;
  var syncCount = 0;
  var now = DateTime.utc(2026, 8, 16, 8);

  setUp(() {
    network = _FakeNetworkMonitor();
    connector = _FakeRealtimeConnector();
    statuses = <RealtimeStatus>[];
    events = <HealthEvent>[];
    syncCount = 0;
    now = DateTime.utc(2026, 8, 16, 8);
    controller = RealtimeController(
      settings: _FakeSettingsRepository(),
      auth: const _FakeAccessTokenProvider(),
      connector: connector,
      network: network,
      synchronize: () async {
        syncCount++;
        return SyncOutcome(
          pulled: 1,
          pushed: 0,
          conflicts: 0,
          pending: 0,
          cursor: syncCount,
          completedAtUtc: now,
        );
      },
      onStatus: statuses.add,
      onEvents: (value) {
        events = value;
      },
      now: () => now,
      retrySchedule: const <Duration>[Duration(hours: 1)],
    );
  });

  tearDown(() async {
    await controller.dispose();
    await network.dispose();
    await connector.dispose();
  });

  test('connects, acknowledges heartbeats and syncs change hints', () async {
    controller.authStateChanged(_authenticatedState());
    await pumpEventQueue();
    final socket = connector.sockets.single;

    socket.add(<String, Object?>{
      'type': 'ready',
      'server_cursor': 4,
      'heartbeat_interval_sec': 15,
    });
    await pumpEventQueue();

    expect(controller.status.state, RealtimeConnectionState.healthy);
    expect(syncCount, 1);
    expect(events.first.type, '增量同步完成');

    socket.add(<String, Object?>{
      'type': 'heartbeat',
      'server_time': now.toIso8601String(),
    });
    await pumpEventQueue();

    expect(controller.status.lastHeartbeatAtUtc, now);
    expect(controller.status.heartbeatSuccesses, 1);
    expect(socket.sent.map(_messageType), contains('heartbeat_ack'));
    expect(syncCount, 1);

    now = now.add(const Duration(seconds: 1));
    socket.add(<String, Object?>{
      'type': 'change_hint',
      'cursor': 5,
      'entity_type': 'task',
      'entity_id': 'redacted-by-controller',
      'entity_version': 2,
    });
    await pumpEventQueue();

    expect(controller.status.lastNotificationType, 'task');
    expect(controller.status.appliedCursor, 2);
    expect(controller.status.serverCursor, 5);
    expect(syncCount, 2);
    expect(
      events.any(
        (event) =>
            event.type == '收到变更通知' &&
            event.details == 'task cursor=5' &&
            !event.details!.contains('redacted-by-controller'),
      ),
      isTrue,
    );
    now = now.add(const Duration(minutes: 5));
    socket.add(<String, Object?>{
      'type': 'heartbeat',
      'server_time': now.toIso8601String(),
    });
    await pumpEventQueue();
    expect(syncCount, 3);
  });

  test(
    'connection probe records round-trip latency without reconnecting',
    () async {
      controller.authStateChanged(_authenticatedState());
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.add(<String, Object?>{
        'type': 'ready',
        'server_cursor': 0,
        'heartbeat_interval_sec': 15,
      });
      await pumpEventQueue();

      final check = controller.checkConnection();
      await pumpEventQueue();
      final probe =
          jsonDecode(socket.sent.last as String) as Map<String, dynamic>;
      now = now.add(const Duration(milliseconds: 27));
      socket.add(<String, Object?>{
        'type': 'heartbeat_probe_ack',
        'probe_id': probe['probe_id']!,
        'server_time': now.toIso8601String(),
      });
      await check;

      expect(controller.status.roundTripMs, 27);
      expect(controller.status.state, RealtimeConnectionState.healthy);
      expect(connector.sockets, hasLength(1));
    },
  );

  test('distinguishes offline and reconnecting states', () async {
    controller.authStateChanged(_authenticatedState());
    await pumpEventQueue();
    final socket = connector.sockets.single;
    socket.add(<String, Object?>{
      'type': 'ready',
      'server_cursor': 0,
      'heartbeat_interval_sec': 15,
    });
    await pumpEventQueue();

    network.add(false);
    await pumpEventQueue();
    expect(controller.status.state, RealtimeConnectionState.offline);
    expect(socket.closed, isTrue);

    network.add(true);
    await pumpEventQueue();
    expect(connector.sockets, hasLength(2));
    expect(controller.status.state, RealtimeConnectionState.connecting);

    connector.sockets.last.fail(StateError('connection dropped'));
    await pumpEventQueue();
    expect(controller.status.state, RealtimeConnectionState.error);
    expect(controller.status.lastError?.code, 'CONNECTION_FAILED');
  });

  test('stops retrying when authentication expires', () async {
    controller.authStateChanged(
      const AuthState(phase: AuthPhase.signedOut, message: 'expired'),
    );
    await pumpEventQueue();

    expect(controller.status.state, RealtimeConnectionState.authExpired);
    expect(connector.sockets, isEmpty);
  });

  test('syncs immediately when a local operation enters the outbox', () async {
    controller.authStateChanged(_authenticatedState());
    await pumpEventQueue();

    controller.localSyncStateChanged(cursor: 0, pending: 1);
    await pumpEventQueue();

    expect(syncCount, 1);
    expect(controller.status.pendingOperations, 0);
  });

  test('uploads pending local operations when the network recovers', () async {
    controller.authStateChanged(_authenticatedState());
    await pumpEventQueue();
    network.add(false);
    await pumpEventQueue();

    controller.localSyncStateChanged(cursor: 0, pending: 1);
    await pumpEventQueue();
    expect(syncCount, 0);

    network.add(true);
    await pumpEventQueue();

    expect(syncCount, 1);
    expect(controller.status.pendingOperations, 0);
  });

  test('uploads pending local operations after authentication', () async {
    controller.localSyncStateChanged(cursor: 0, pending: 1);
    await pumpEventQueue();
    expect(syncCount, 0);

    controller.authStateChanged(_authenticatedState());
    await pumpEventQueue();

    expect(syncCount, 1);
    expect(controller.status.pendingOperations, 0);
  });
}

AuthState _authenticatedState() => AuthState(
  phase: AuthPhase.authenticated,
  session: RemoteSession(
    accessToken: 'memory-only-access-token',
    refreshToken: 'stored-by-fake-only',
    expiresAtUtc: DateTime.utc(2026, 8, 16, 9),
    user: const RemoteUser(id: 'user-id', username: 'kairos'),
    device: const RemoteDevice(
      id: 'device-id',
      name: 'test',
      platform: 'windows',
    ),
  ),
);

String? _messageType(Object? message) {
  if (message is! String) {
    return null;
  }
  return (jsonDecode(message) as Map<String, dynamic>)['type'] as String?;
}

class _FakeRealtimeConnector implements RealtimeConnector {
  final List<_FakeRealtimeSocket> sockets = <_FakeRealtimeSocket>[];

  @override
  RealtimeSocket connect(Uri endpoint, String accessToken) {
    final socket = _FakeRealtimeSocket();
    sockets.add(socket);
    return socket;
  }

  Future<void> dispose() async {
    for (final socket in sockets) {
      await socket.dispose();
    }
  }
}

class _FakeRealtimeSocket implements RealtimeSocket {
  final StreamController<Object?> _messages =
      StreamController<Object?>.broadcast();
  final List<Object?> sent = <Object?>[];
  bool closed = false;

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> get ready async {}

  void add(Map<String, Object?> value) => _messages.add(jsonEncode(value));

  void fail(Object error) => _messages.addError(error);

  @override
  void send(Object? message) => sent.add(message);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  Future<void> dispose() => _messages.close();
}

class _FakeNetworkMonitor implements NetworkMonitor {
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool online = true;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> isOnline() async => online;

  void add(bool value) {
    online = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}

class _FakeAccessTokenProvider implements AccessTokenProvider {
  const _FakeAccessTokenProvider();

  @override
  Future<String?> accessToken() async => 'access-token';
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<String> getOrCreateDeviceId() async => 'device-id';

  @override
  Future<AppPreferences> loadPreferences() async => const AppPreferences();

  @override
  Future<String?> readServiceEndpoint() async => 'https://kairos.example.test';

  @override
  Future<void> savePreferences(AppPreferences preferences) async {}

  @override
  Future<void> saveServiceEndpoint(String? endpoint) async {}

  @override
  Stream<AppPreferences> watchPreferences() =>
      Stream<AppPreferences>.value(const AppPreferences());
}
