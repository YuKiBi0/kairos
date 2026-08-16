import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kairos/app/app.dart';
import 'package:kairos/app/providers.dart';
import 'package:kairos/app/router.dart';
import 'package:kairos/core/security/secure_credential_store.dart';
import 'package:kairos/data/local/database.dart';
import 'package:kairos/data/remote/realtime_socket.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline task survives view changes and app rebuild', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    appRouter.go('/');

    Widget application() => ProviderScope(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        credentialStoreProvider.overrideWithValue(_MemoryCredentialStore()),
        networkMonitorProvider.overrideWithValue(const _OnlineNetworkMonitor()),
      ],
      child: const KairosApp(),
    );

    await tester.pumpWidget(application());
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '离线验收任务');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('离线验收任务'), findsOneWidget);
    await tester.tap(find.byTooltip('树视图'));
    await tester.pumpAndSettle();
    expect(find.text('离线验收任务'), findsOneWidget);
    await tester.tap(find.byTooltip('完成任务'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    appRouter.go('/');
    await tester.pumpWidget(application());
    await tester.pumpAndSettle();

    expect(find.text('离线验收任务'), findsOneWidget);
    expect(find.byTooltip('恢复任务'), findsOneWidget);
  });
}

class _MemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _OnlineNetworkMonitor implements NetworkMonitor {
  const _OnlineNetworkMonitor();

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => true;
}
