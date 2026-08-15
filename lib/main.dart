import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KairosApp()));

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    doWhenWindowReady(() {
      const initialSize = Size(1180, 760);
      appWindow
        ..minSize = const Size(420, 640)
        ..size = initialSize
        ..alignment = Alignment.center
        ..title = 'Kairos'
        ..show();
    });
  }
}
