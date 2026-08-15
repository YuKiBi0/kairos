import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/app/providers.dart';
import 'package:kairos/domain/entities/realtime_status.dart';
import 'package:kairos/features/link_health/presentation/link_health_page.dart';

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
      serverCursor: 42,
      pendingOperations: 3,
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
    expect(
      find.textContaining('wss://kairos.example.com/api/v1/realtime'),
      findsOneWidget,
    );
  });
}
