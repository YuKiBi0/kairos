import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/link_health/presentation/link_health_page.dart';
import 'providers.dart';
import 'theme/organic_theme.dart';

class AdaptiveAppShell extends ConsumerWidget {
  const AdaptiveAppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeStatus = ref.watch(realtimeStatusProvider);
    final compactWorkspace =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        location == '/' &&
        ref.watch(
          workspaceControllerProvider.select(
            (preferences) => preferences.compactWorkspace,
          ),
        );
    final selectedIndex = location.startsWith('/link-health')
        ? 1
        : location.startsWith('/settings')
        ? 2
        : 0;
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
            _WindowsTitleBar(location: location),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (compactWorkspace) {
                  return child;
                }
                if (constraints.maxWidth >= 780) {
                  return Row(
                    children: <Widget>[
                      NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (index) =>
                            _navigate(context, index),
                        labelType: constraints.maxWidth >= 1100
                            ? NavigationRailLabelType.all
                            : NavigationRailLabelType.selected,
                        leading: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            header: true,
                            child: Text(
                              'K',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: KairosColors.forestInk),
                            ),
                          ),
                        ),
                        destinations: <NavigationRailDestination>[
                          const NavigationRailDestination(
                            icon: Icon(Icons.checklist_outlined),
                            selectedIcon: Icon(Icons.checklist),
                            label: Text('任务'),
                          ),
                          NavigationRailDestination(
                            icon: GlobalLinkStatusIcon(status: realtimeStatus),
                            selectedIcon: GlobalLinkStatusIcon(
                              status: realtimeStatus,
                            ),
                            label: const Text('链路健康'),
                          ),
                          const NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: Text('设置'),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: child),
                    ],
                  );
                }
                return child;
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          !compactWorkspace && MediaQuery.sizeOf(context).width < 780
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              destinations: <NavigationDestination>[
                const NavigationDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: '任务',
                ),
                NavigationDestination(
                  icon: GlobalLinkStatusIcon(status: realtimeStatus),
                  selectedIcon: GlobalLinkStatusIcon(status: realtimeStatus),
                  label: '链路',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            )
          : null,
    );
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/link-health');
      case 2:
        context.go('/settings');
    }
  }
}

class _WindowsTitleBar extends ConsumerWidget {
  const _WindowsTitleBar({required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alwaysOnTop = ref.watch(
      workspaceControllerProvider.select(
        (preferences) => preferences.alwaysOnTop,
      ),
    );
    final compactWorkspace =
        location == '/' &&
        ref.watch(
          workspaceControllerProvider.select(
            (preferences) => preferences.compactWorkspace,
          ),
        );
    final buttonColors = WindowButtonColors(
      iconNormal: KairosColors.forestInk,
      mouseOver: KairosColors.sage,
      mouseDown: KairosColors.moss,
      iconMouseOver: KairosColors.forestInk,
      iconMouseDown: Colors.white,
    );
    final closeColors = WindowButtonColors(
      iconNormal: KairosColors.forestInk,
      mouseOver: KairosColors.clay,
      mouseDown: KairosColors.clay,
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );
    return WindowTitleBarBox(
      child: ColoredBox(
        color: KairosColors.paper,
        child: Row(
          children: <Widget>[
            Expanded(
              child: MoveWindow(
                child: const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kairos'),
                  ),
                ),
              ),
            ),
            WindowsCompactWorkspaceButton(
              compact: compactWorkspace,
              onPressed: () {
                ref
                    .read(workspaceControllerProvider.notifier)
                    .setCompactWorkspace(!compactWorkspace);
                if (!compactWorkspace && location != '/') {
                  context.go('/');
                }
              },
            ),
            WindowsPinButton(
              pinned: alwaysOnTop,
              onPressed: () => _setAlwaysOnTop(context, ref, !alwaysOnTop),
            ),
            MinimizeWindowButton(colors: buttonColors),
            MaximizeWindowButton(colors: buttonColors),
            CloseWindowButton(colors: closeColors),
          ],
        ),
      ),
    );
  }

  Future<void> _setAlwaysOnTop(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(windowsWindowServiceProvider).setAlwaysOnTop(value);
      ref.read(workspaceControllerProvider.notifier).setAlwaysOnTop(value);
    } on PlatformException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('置顶设置未更新：${error.code}')));
      }
    }
  }
}

class WindowsPinButton extends StatelessWidget {
  const WindowsPinButton({
    required this.pinned,
    required this.onPressed,
    super.key,
  });

  final bool pinned;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _WindowsTitleBarToggleButton(
    controlKey: 'window-pin-button',
    tooltip: pinned ? '取消固定窗口' : '固定窗口',
    selected: pinned,
    onPressed: onPressed,
    icon: Icons.push_pin_outlined,
    selectedIcon: Icons.push_pin,
  );
}

class WindowsCompactWorkspaceButton extends StatelessWidget {
  const WindowsCompactWorkspaceButton({
    required this.compact,
    required this.onPressed,
    super.key,
  });

  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _WindowsTitleBarToggleButton(
    controlKey: 'window-compact-workspace-button',
    tooltip: compact ? '退出精简工作区' : '进入精简工作区',
    selected: compact,
    onPressed: onPressed,
    icon: Icons.view_compact_outlined,
    selectedIcon: Icons.fullscreen_exit,
  );
}

class _WindowsTitleBarToggleButton extends StatelessWidget {
  const _WindowsTitleBarToggleButton({
    required this.controlKey,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    required this.icon,
    required this.selectedIcon,
  });

  final String controlKey;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData icon;
  final IconData selectedIcon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 32,
    child: IconButton(
      key: ValueKey<String>(controlKey),
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      iconSize: 17,
      padding: EdgeInsets.zero,
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(46, 32)),
        maximumSize: WidgetStateProperty.all(const Size(46, 32)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStateProperty.all(const RoundedRectangleBorder()),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white;
          }
          return KairosColors.forestInk;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return KairosColors.moss;
          }
          if (states.contains(WidgetState.selected)) {
            return KairosColors.sage;
          }
          if (states.contains(WidgetState.hovered)) {
            return KairosColors.sage.withValues(alpha: 0.65);
          }
          return Colors.transparent;
        }),
      ),
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
    ),
  );
}
