import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/windows_window_service.dart';
import '../domain/entities/app_preferences.dart';
import '../l10n/generated/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/organic_theme.dart';

class KairosApp extends ConsumerStatefulWidget {
  const KairosApp({super.key});

  @override
  ConsumerState<KairosApp> createState() => _KairosAppState();
}

class _KairosAppState extends ConsumerState<KairosApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(realtimeActionsProvider).synchronizeNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeControllerProvider);
    ref.listen<AppPreferences>(
      workspaceControllerProvider,
      (previous, next) => unawaited(
        _restoreWindowPreference(
          ref.read(windowsWindowServiceProvider),
          next.alwaysOnTop,
        ),
      ),
    );
    return MaterialApp.router(
      title: 'Kairos',
      debugShowCheckedModeBanner: false,
      theme: OrganicTheme.light,
      routerConfig: appRouter,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

Future<void> _restoreWindowPreference(
  WindowsWindowService service,
  bool alwaysOnTop,
) async {
  try {
    await service.setAlwaysOnTop(alwaysOnTop);
  } on PlatformException {
    // The settings page surfaces platform failures during direct user actions.
  }
}
