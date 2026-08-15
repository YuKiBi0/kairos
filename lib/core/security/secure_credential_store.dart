import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class CredentialStore {
  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);
}

class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore();

  static const MethodChannel _channel = MethodChannel('kairos/secure_storage');
  static final RegExp _validKey = RegExp(r'^[A-Za-z0-9._-]{1,80}$');

  @override
  Future<void> write(String key, String value) async {
    _checkPlatform();
    _checkKey(key);
    if (value.isEmpty) {
      throw const FormatException('Credential value cannot be empty.');
    }
    await _channel.invokeMethod<void>('write', <String, Object?>{
      'key': key,
      'value': value,
    });
  }

  @override
  Future<String?> read(String key) async {
    _checkPlatform();
    _checkKey(key);
    return _channel.invokeMethod<String>('read', <String, Object?>{'key': key});
  }

  @override
  Future<void> delete(String key) async {
    _checkPlatform();
    _checkKey(key);
    await _channel.invokeMethod<void>('delete', <String, Object?>{'key': key});
  }

  void _checkPlatform() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.windows &&
            defaultTargetPlatform != TargetPlatform.android)) {
      throw UnsupportedError(
        'Secure credentials are supported on Windows and Android.',
      );
    }
  }

  void _checkKey(String key) {
    if (!_validKey.hasMatch(key)) {
      throw const FormatException(
        'Credential key contains invalid characters.',
      );
    }
  }
}
