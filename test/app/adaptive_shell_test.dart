import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/app/adaptive_shell.dart';

void main() {
  testWidgets('window pin button toggles and exposes its current state', (
    tester,
  ) async {
    var toggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WindowsPinButton(pinned: false, onPressed: () => toggleCount++),
        ),
      ),
    );

    expect(find.byTooltip('固定窗口'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('window-pin-button')))
          .isSelected,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('window-pin-button')));
    await tester.pump();

    expect(toggleCount, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WindowsPinButton(pinned: true, onPressed: () => toggleCount++),
        ),
      ),
    );

    expect(find.byTooltip('取消固定窗口'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('window-pin-button')))
          .isSelected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact workspace button toggles and exposes its current state',
    (tester) async {
      var toggleCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WindowsCompactWorkspaceButton(
              compact: false,
              onPressed: () => toggleCount++,
            ),
          ),
        ),
      );

      expect(find.byTooltip('进入精简工作区'), findsOneWidget);
      expect(find.byIcon(Icons.view_compact_outlined), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('window-compact-workspace-button')),
      );
      await tester.pump();

      expect(toggleCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WindowsCompactWorkspaceButton(
              compact: true,
              onPressed: () => toggleCount++,
            ),
          ),
        ),
      );

      expect(find.byTooltip('退出精简工作区'), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('window-compact-workspace-button')),
            )
            .isSelected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
