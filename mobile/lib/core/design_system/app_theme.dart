import 'package:flutter/material.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

abstract final class PlanItTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PlanItColors.primary,
      brightness: brightness,
      surface: isDark ? PlanItColors.darkSurface : PlanItColors.surface,
      error: PlanItColors.negative,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? PlanItColors.darkCanvas : PlanItColors.canvas,
      textTheme: Typography.material2021(platform: TargetPlatform.android).black.apply(
            bodyColor: isDark ? Colors.white : PlanItColors.ink,
            displayColor: isDark ? Colors.white : PlanItColors.ink,
          ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? PlanItColors.darkSurface : PlanItColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlanItRadius.md),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.55)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        elevation: 0,
        backgroundColor: isDark ? PlanItColors.darkSurface : PlanItColors.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? PlanItColors.darkSurface : PlanItColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlanItRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlanItRadius.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
