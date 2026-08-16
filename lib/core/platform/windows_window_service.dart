import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowsWindowService {
  const WindowsWindowService();

  static const MethodChannel _channel = MethodChannel('kairos/window');

  Future<void> setAlwaysOnTop(bool value) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    await _channel.invokeMethod<void>('setAlwaysOnTop', value);
  }
}
