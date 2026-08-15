import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/organic_theme.dart';

class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = location.startsWith('/link-health')
        ? 1
        : location.startsWith('/settings')
        ? 2
        : 0;
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
            const _WindowsTitleBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                        destinations: const <NavigationRailDestination>[
                          NavigationRailDestination(
                            icon: Icon(Icons.checklist_outlined),
                            selectedIcon: Icon(Icons.checklist),
                            label: Text('任务'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.hub_outlined),
                            selectedIcon: Icon(Icons.hub),
                            label: Text('链路健康'),
                          ),
                          NavigationRailDestination(
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
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 780
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: '任务',
                ),
                NavigationDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub),
                  label: '链路',
                ),
                NavigationDestination(
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

class _WindowsTitleBar extends StatelessWidget {
  const _WindowsTitleBar();

  @override
  Widget build(BuildContext context) {
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
            MinimizeWindowButton(colors: buttonColors),
            MaximizeWindowButton(colors: buttonColors),
            CloseWindowButton(colors: closeColors),
          ],
        ),
      ),
    );
  }
}
