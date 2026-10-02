import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inline SVG icons copied from the Figma Make code. Strokes use
/// `currentColor`, so the icon takes the colour it is given.
abstract final class TroskyIcons {
  /// Envelope on "Continue with Email" (P4), drawn 18 px in a 24 px viewBox.
  static Widget mail({required Color color, double size = 18}) =>
      _icon(_mail, color, size, size);

  /// Back chevron in the round header buttons (P6, P7), 18 px.
  static Widget back({required Color color, double size = 18}) =>
      _icon(_back, color, size, size);

  /// Check mark on a selected seat (P7), 16 px.
  static Widget check({required Color color, double size = 16}) =>
      _icon(_check, color, size, size);

  /// Down chevron in the phone number prefix (P4), 12 × 8 px.
  static Widget chevronDown({required Color color}) =>
      _icon(_chevronDown, color, 12, 8);

  /// Magnifier in the Home search bar (P5), 18 px.
  static Widget search({required Color color, double size = 18}) =>
      _icon(_search, color, size, size);

  /// Crosshair on the my-location map button (P5), 16 px.
  static Widget myLocation({required Color color, double size = 16}) =>
      _icon(_myLocation, color, size, size);

  /// The bus inside a map pin (`BusPin` in Shared.tsx), 16 × 10 px. The
  /// window cut-outs share the body's winding, so like the browser it draws
  /// as one rounded block.
  static Widget bus({required Color color}) => _icon(_bus, color, 16, 10);

  static Widget _icon(String svg, Color color, double width, double height) {
    return SvgPicture.string(
      svg,
      width: width,
      height: height,
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

  static const String _back =
      '<svg viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M11 14L6 9L11 4" stroke="currentColor" stroke-width="2" '
      'stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>';

  static const String _check =
      '<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M3 8l4 4 6-7" stroke="currentColor" stroke-width="2.5" '
      'stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>';

  static const String _chevronDown =
      '<svg viewBox="0 0 12 8" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M1 1l5 5 5-5" stroke="currentColor" stroke-width="1.5" '
      'stroke-linecap="round"/>'
      '</svg>';

  static const String _search =
      '<svg viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="8" cy="8" r="5.5" stroke="currentColor" stroke-width="1.5"/>'
      '<path d="M12.5 12.5l2.5 2.5" stroke="currentColor" stroke-width="1.5" '
      'stroke-linecap="round"/>'
      '</svg>';

  static const String _myLocation =
      '<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="8" cy="8" r="3" fill="currentColor"/>'
      '<circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.5"/>'
      '<line x1="8" y1="0" x2="8" y2="4" stroke="currentColor" '
      'stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="8" y1="12" x2="8" y2="16" stroke="currentColor" '
      'stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>';

  static const String _bus =
      '<svg viewBox="-8 -5 16 10" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M-6,-5 h12 a2,2 0 0 1 2,2 v6 a2,2 0 0 1 -2,2 h-12 '
      'a2,2 0 0 1 -2,-2 v-6 a2,2 0 0 1 2,-2 z M-5,-2 h3 v4 h-3 z '
      'M1,-2 h3 v4 h-3 z" fill="currentColor" fill-opacity="0.9"/>'
      '</svg>';
}
