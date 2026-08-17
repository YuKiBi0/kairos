import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/app/providers.dart';
import 'package:kairos/domain/entities/realtime_status.dart';
import 'package:kairos/features/link_health/presentation/link_health_page.dart';
import 'package:kairos/features/sync/application/realtime_controller.dart';

void main() {
  const cases = <RealtimeConnectionState, String>{
    RealtimeConnectionState.healthy: '通知通道在线',
    RealtimeConnectionState.reconnecting: '正在恢复实时通知',
    RealtimeConnectionState.error: '实时通知不可用',
    RealtimeConnectionState.unconfigured: '尚未连接同步服务',
    RealtimeConnectionState.offline: '设备离线',
  };

  for (final entry in cases.entries) {
    testWidgets('shows ${entry.key.name} state with readable text', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            realtimeStatusProvider.overrideWith(
              (ref) => RealtimeStatus(state: entry.key),
            ),
          ],
          child: const MaterialApp(home: LinkHealthPage()),
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(Icon), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('diagnostics omit query parameters and task content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final status = RealtimeStatus(
      state: RealtimeConnectionState.healthy,
      endpoint: Uri.parse(
        'wss://kairos.example.com/api/v1/realtime?token=secret',
      ),
      appliedCursor: 40,
      serverCursor: 42,
      pendingOperations: 3,
    );
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          realtimeStatusProvider.overrideWith((ref) => status),
        ],
        child: const MaterialApp(home: LinkHealthPage()),
      ),
    );

    expect(find.textContaining('token='), findsNothing);
    expect(find.text('本机已应用游标'), findsOneWidget);
    expect(find.text('服务端最新游标'), findsOneWidget);
    expect(
      find.textContaining('wss://kairos.example.com/api/v1/realtime'),
      findsOneWidget,
    );
    await tester.tap(find.text('复制诊断信息'));
    await tester.pump();
    expect(clipboardText, isNotNull);
    expect(clipboardText, isNot(contains('token=')));
    expect(clipboardText, isNot(contains('secret')));
    expect(clipboardText, isNot(contains('task title')));
  });

  testWidgets('connection and sync actions invoke their controllers', (
    tester,
  ) async {
    final actions = _FakeRealtimeActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          realtimeStatusProvider.overrideWith(
            (ref) => RealtimeStatus(
              state: RealtimeConnectionState.healthy,
              endpoint: Uri.parse('wss://kairos.example.com/api/v1/realtime'),
            ),
          ),
          realtimeActionsProvider.overrideWithValue(actions),
        ],
        child: const MaterialApp(home: LinkHealthPage()),
      ),
    );

    await tester.tap(find.text('检查连接'));
    await tester.tap(find.text('立即同步'));
    await tester.pump();

    expect(actions.checkCount, 1);
    expect(actions.syncCount, 1);
  });

  testWidgets('error state exposes immediate reconnect action', (tester) async {
    final actions = _FakeRealtimeActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          realtimeStatusProvider.overrideWith(
            (ref) => RealtimeStatus(
              state: RealtimeConnectionState.error,
              endpoint: Uri.parse('wss://kairos.example.com/api/v1/realtime'),
            ),
          ),
          realtimeActionsProvider.overrideWithValue(actions),
        ],
        child: const MaterialApp(home: LinkHealthPage()),
      ),
    );

    await tester.tap(find.text('立即重连'));
    await tester.pump();

    expect(actions.reconnectCount, 1);
  });

  testWidgets('narrow layout supports 200 percent text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          realtimeStatusProvider.overrideWith(
            (ref) => RealtimeStatus(
              state: RealtimeConnectionState.error,
              endpoint: Uri.parse('wss://kairos.example.com/api/v1/realtime'),
              lastError: const LinkError(
                code: 'TLS_HANDSHAKE_FAILED',
                stage: 'TLS',
                message: '安全连接握手失败',
                suggestion: '确认服务器证书有效且域名匹配',
              ),
            ),
          ),
          realtimeActionsProvider.overrideWithValue(_FakeRealtimeActions()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const LinkHealthPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('实时通知不可用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRealtimeActions implements RealtimeActions {
  int checkCount = 0;
  int reconnectCount = 0;
  int syncCount = 0;

  @override
  Future<void> checkConnection() async {
    checkCount++;
  }

  @override
  Future<void> reconnect() async {
    reconnectCount++;
  }

  @override
  Future<void> synchronizeNow() async {
    syncCount++;
  }
}
