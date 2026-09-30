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
    return ThemeData(
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
  }
}
