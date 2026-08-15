import 'package:flutter/material.dart';

abstract final class KairosColors {
  static const Color forestInk = Color(0xFF203A34);
  static const Color moss = Color(0xFF6E956F);
  static const Color paper = Color(0xFFF4F3EC);
  static const Color sage = Color(0xFFC8D8BD);
  static const Color pollen = Color(0xFFE2B35C);
  static const Color clay = Color(0xFFC97863);
  static const Color river = Color(0xFF8FBBC1);
  static const Color quietInk = Color(0xFF52635E);
  static const Color line = Color(0xFFD8D8CE);
}

abstract final class OrganicTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: KairosColors.moss,
      onPrimary: Colors.white,
      primaryContainer: KairosColors.sage,
      onPrimaryContainer: KairosColors.forestInk,
      secondary: KairosColors.river,
      onSecondary: KairosColors.forestInk,
      secondaryContainer: Color(0xFFDCEAEC),
      onSecondaryContainer: KairosColors.forestInk,
      error: KairosColors.clay,
      onError: Colors.white,
      errorContainer: Color(0xFFF2DDD7),
      onErrorContainer: KairosColors.forestInk,
      surface: KairosColors.paper,
      onSurface: KairosColors.forestInk,
      surfaceContainerHighest: Color(0xFFE5EBDD),
      outline: Color(0xFF87938D),
      outlineVariant: KairosColors.line,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: KairosColors.paper,
      fontFamily: 'Noto Sans SC',
      fontFamilyFallback: const <String>['Microsoft YaHei UI', 'sans-serif'],
      visualDensity: VisualDensity.standard,
    );
    final serif = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: 'Noto Serif SC',
        fontFamilyFallback: const <String>['SimSun', 'serif'],
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontFamily: 'Noto Serif SC',
        fontFamilyFallback: const <String>['SimSun', 'serif'],
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'Noto Serif SC',
        fontFamilyFallback: const <String>['SimSun', 'serif'],
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
      labelLarge: base.textTheme.labelLarge?.copyWith(height: 1.25),
    );

    return base.copyWith(
      textTheme: serif,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Color(0xFFF9F8F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: KairosColors.line),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF9F8F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: KairosColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: KairosColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: KairosColors.moss, width: 2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
