import 'package:flutter/material.dart';

import '../tokens/trosky_colors.dart';
import '../tokens/trosky_typography.dart';

/// Material 3 theme built from the TroSky tokens.
///
/// Screens style themselves with the tokens directly; the theme covers what
/// Material widgets pick up on their own. No colours are derived: every slot
/// is a token, and Material's ripples and highlights are switched off
/// because the design has none.
abstract final class TroskyTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: TroskyColors.green,
      onPrimary: TroskyColors.white,
      secondary: TroskyColors.amber,
      onSecondary: TroskyColors.ink,
      tertiary: TroskyColors.blue,
      onTertiary: TroskyColors.white,
      error: TroskyColors.red,
      onError: TroskyColors.white,
      surface: TroskyColors.surface,
      onSurface: TroskyColors.textPrimary,
      onSurfaceVariant: TroskyColors.textSecondary,
      outline: TroskyColors.border,
      outlineVariant: TroskyColors.border,
      // Material 3 tints raised surfaces (e.g. a scrolled app bar) with this
      // colour; the design has no such tint.
      surfaceTint: TroskyColors.transparent,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TroskyColors.background,
      fontFamily: TroskyTypography.bodyFamily,
      package: 'trosky_ui',
      dividerColor: TroskyColors.border,
      splashFactory: NoSplash.splashFactory,
      splashColor: TroskyColors.transparent,
      highlightColor: TroskyColors.transparent,
      hoverColor: TroskyColors.transparent,
    );
    // Material 3 spaces its text styles out (e.g. 0.5 px for bodyLarge,
    // which a TextField types in). The designs are CSS, where letter
    // spacing is 0 unless a style says otherwise.
    return base.copyWith(
      textTheme: _noLetterSpacing(base.textTheme),
      primaryTextTheme: _noLetterSpacing(base.primaryTextTheme),
    );
  }

  static TextTheme _noLetterSpacing(TextTheme theme) => theme.copyWith(
    displayLarge: theme.displayLarge?.copyWith(letterSpacing: 0),
    displayMedium: theme.displayMedium?.copyWith(letterSpacing: 0),
    displaySmall: theme.displaySmall?.copyWith(letterSpacing: 0),
    headlineLarge: theme.headlineLarge?.copyWith(letterSpacing: 0),
    headlineMedium: theme.headlineMedium?.copyWith(letterSpacing: 0),
    headlineSmall: theme.headlineSmall?.copyWith(letterSpacing: 0),
    titleLarge: theme.titleLarge?.copyWith(letterSpacing: 0),
    titleMedium: theme.titleMedium?.copyWith(letterSpacing: 0),
    titleSmall: theme.titleSmall?.copyWith(letterSpacing: 0),
    bodyLarge: theme.bodyLarge?.copyWith(letterSpacing: 0),
    bodyMedium: theme.bodyMedium?.copyWith(letterSpacing: 0),
    bodySmall: theme.bodySmall?.copyWith(letterSpacing: 0),
    labelLarge: theme.labelLarge?.copyWith(letterSpacing: 0),
    labelMedium: theme.labelMedium?.copyWith(letterSpacing: 0),
    labelSmall: theme.labelSmall?.copyWith(letterSpacing: 0),
  );
}
