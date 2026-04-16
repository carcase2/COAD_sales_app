// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// 영업 현장용 — 가독성·대비·여백 위주의 Material 3 테마
class AppTheme {
  AppTheme._();

  // 조금 더 세련된 네이비 코발트 톤
  static const Color _seed = Color(0xFF2B5C92);

  static TextStyle? _scaled(TextStyle? style, double factor) {
    if (style == null) return null;
    final size = style.fontSize;
    if (size == null) return style;
    return style.copyWith(fontSize: size * factor);
  }

  static TextTheme _scaleTextTheme(TextTheme theme, double factor) {
    return theme.copyWith(
      displayLarge: _scaled(theme.displayLarge, factor),
      displayMedium: _scaled(theme.displayMedium, factor),
      displaySmall: _scaled(theme.displaySmall, factor),
      headlineLarge: _scaled(theme.headlineLarge, factor),
      headlineMedium: _scaled(theme.headlineMedium, factor),
      headlineSmall: _scaled(theme.headlineSmall, factor),
      titleLarge: _scaled(theme.titleLarge, factor),
      titleMedium: _scaled(theme.titleMedium, factor),
      titleSmall: _scaled(theme.titleSmall, factor),
      bodyLarge: _scaled(theme.bodyLarge, factor),
      bodyMedium: _scaled(theme.bodyMedium, factor),
      bodySmall: _scaled(theme.bodySmall, factor),
      labelLarge: _scaled(theme.labelLarge, factor),
      labelMedium: _scaled(theme.labelMedium, factor),
      labelSmall: _scaled(theme.labelSmall, factor),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: const Color(0xFFF8F9FA),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
    );

    final baseTextTheme = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(
          fontFamily: null, // Keep default for performance, or specify like 'Pretendard' if imported
          bodyColor: const Color(0xFF1F2937), // 덜 까만 회검색
          displayColor: const Color(0xFF111827),
        )
        .copyWith(
          titleLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          titleMedium: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5, letterSpacing: -0.1),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.5, letterSpacing: -0.1),
          labelLarge: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        );
    final textTheme = _scaleTextTheme(baseTextTheme, 0.8);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: colorScheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error.withOpacity(0.5), width: 1.5),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.6), fontSize: 14),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.focused) ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          );
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
        height: 64,
        indicatorColor: colorScheme.primaryContainer.withOpacity(0.6),
        labelTextStyle: WidgetStateTextStyle.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
