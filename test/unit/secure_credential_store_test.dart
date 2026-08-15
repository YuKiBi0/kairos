import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/core/security/secure_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kairos/secure_storage');
  const store = SecureCredentialStore();
  final values = <String, String>{};

  setUp(() {
    values.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map<Object?, Object?>;
          final key = arguments['key']! as String;
          switch (call.method) {
            case 'write':
              values[key] = arguments['value']! as String;
            case 'read':
              return values[key];
            case 'delete':
              values.remove(key);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'writes, reads and deletes a credential through the platform channel',
    () async {
      await store.write('refresh_token', 'opaque-token');
      expect(await store.read('refresh_token'), 'opaque-token');

      await store.delete('refresh_token');
      expect(await store.read('refresh_token'), isNull);
    },
  );

  test(
    'rejects unsafe keys and empty values before invoking the platform',
    () async {
      await expectLater(
        store.write('../refresh-token', 'value'),
        throwsFormatException,
      );
      await expectLater(
        store.write('refresh_token', ''),
        throwsFormatException,
      );
    },
  );
}
