import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/app/app.dart';
import 'package:kairos/app/providers.dart';
import 'package:kairos/domain/entities/app_preferences.dart';
import 'package:kairos/domain/entities/task.dart';
import 'package:kairos/domain/repositories/settings_repository.dart';

void main() {
  testWidgets('starts the Kairos task workspace', (tester) async {
    final settings = _MemorySettingsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tasksProvider.overrideWith(
            (ref) => Stream<List<Task>>.value(const <Task>[]),
          ),
          unresolvedBlockerCountsProvider.overrideWith(
            (ref) => Stream<Map<String, int>>.value(const <String, int>{}),
          ),
          workspaceControllerProvider.overrideWith(
            (ref) => WorkspaceController(settings),
          ),
        ],
        child: const KairosApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Kairos'), findsWidgets);
    expect(find.text('现在最该推进什么'), findsOneWidget);
    expect(find.text('新建'), findsOneWidget);
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  AppPreferences preferences = const AppPreferences();
  String? endpoint;

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<AppPreferences> loadPreferences() async => preferences;

  @override
  Future<String?> readServiceEndpoint() async => endpoint;

  @override
  Future<void> savePreferences(AppPreferences preferences) async {
    this.preferences = preferences;
  }

  @override
  Future<void> saveServiceEndpoint(String? endpoint) async {
    this.endpoint = endpoint;
  }

  @override
  Stream<AppPreferences> watchPreferences() =>
      Stream<AppPreferences>.value(preferences);
}
