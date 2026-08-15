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

class KairosApp extends ConsumerWidget {
  const KairosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
