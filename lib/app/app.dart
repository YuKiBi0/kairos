import 'dart:async';

import 'package:flutter/foundation.dart';
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
    final theme = kairosThemeForPlatform(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
    final app = MaterialApp.router(
      title: 'Kairos',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: appRouter,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );

    return applyPlatformSemanticsPolicy(
      child: app,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
  }
}

@visibleForTesting
Widget applyPlatformSemanticsPolicy({
  required Widget child,
  required bool isWeb,
  required TargetPlatform platform,
}) {
  // Flutter 3.41 can crash the Windows AXTree while updating a complex
  // semantics tree. Windows remains fully usable with visual, pointer, and
  // keyboard interaction, so disable only its native accessibility bridge.
  if (!isWeb && platform == TargetPlatform.windows) {
    return ExcludeSemantics(child: child);
  }
  return child;
}

@visibleForTesting
ThemeData kairosThemeForPlatform({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb || platform != TargetPlatform.windows) {
    return OrganicTheme.light;
  }
  // Flutter 3.41 can crash the Windows AXTree when hover-triggered tooltip
  // overlays are grafted into a scrollable semantics tree.
  return OrganicTheme.light.copyWith(
    tooltipTheme: OrganicTheme.light.tooltipTheme.copyWith(
      triggerMode: TooltipTriggerMode.manual,
      waitDuration: const Duration(days: 365),
    ),
  );
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
