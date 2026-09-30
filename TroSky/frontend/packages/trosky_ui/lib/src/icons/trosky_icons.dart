import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inline SVG icons copied from the Figma Make code. Strokes use
/// `currentColor`, so the icon takes the colour it is given.
abstract final class TroskyIcons {
  /// Envelope on "Continue with Email" (P4), drawn 18 px in a 24 px viewBox.
  static Widget mail({required Color color, double size = 18}) {
    return SvgPicture.string(
      _mail,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
      excludeFromSemantics: true,
    );
  }

  static const String _mail =
      '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="2" y="4" width="20" height="16" rx="3" stroke="currentColor" '
      'stroke-width="2"/>'
      '<path d="M2 8l10 6 10-6" stroke="currentColor" stroke-width="2" '
      'stroke-linecap="round"/>'
      '</svg>';
}
