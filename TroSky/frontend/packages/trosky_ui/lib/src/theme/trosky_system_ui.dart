import 'package:flutter/services.dart';

import '../tokens/trosky_colors.dart';

/// Status and navigation bar styles. Every screen declares one with
/// `AnnotatedRegion<SystemUiOverlayStyle>`; the app uses [darkIcons] where a
/// screen doesn't.
///
/// Both bars are transparent so screens draw edge to edge behind them.
abstract final class TroskySystemUi {
  /// Light icons, for dark, green and navy backgrounds.
  static const SystemUiOverlayStyle lightIcons = SystemUiOverlayStyle(
    statusBarColor: TroskyColors.transparent,
    // Android sets the icon colour; iOS sets the bar's background brightness.
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: TroskyColors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  /// Dark icons, for light backgrounds.
  static const SystemUiOverlayStyle darkIcons = SystemUiOverlayStyle(
    statusBarColor: TroskyColors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: TroskyColors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
