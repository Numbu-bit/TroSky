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

  /// Clock on the "approaching your stop" banner (P6), 14 px.
  static Widget clock({required Color color}) => _icon(_clock, color, 14, 14);

  /// Small clock on a trip card's badge (P6), 10 px.
  static Widget clockSmall({required Color color}) =>
      _icon(_clockSmall, color, 10, 10);

  /// Arrow on the "Already passed your stop" strip (P6), 10 px.
  static Widget arrowRight({required Color color}) =>
      _icon(_arrowRight, color, 10, 10);

  /// Map pin for "Board at …" on a trip card (not in Figma; drawn in the
  /// small clock's style), 10 px.
  static Widget pinSmall({required Color color}) =>
      _icon(_pinSmall, color, 10, 10);

  /// Star for saving a route (not in Figma), 18 px, outlined or [filled].
  static Widget star({required Color color, bool filled = false}) =>
      _icon(filled ? _starFilled : _star, color, 18, 18);

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

  static const String _clock =
      '<svg viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="7" cy="7" r="6" stroke="currentColor" stroke-width="1.5"/>'
      '<path d="M7 4v3.5l2 1.5" stroke="currentColor" stroke-width="1.5" '
      'stroke-linecap="round"/>'
      '</svg>';

  static const String _clockSmall =
      '<svg viewBox="0 0 10 10" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="5" cy="5" r="4" stroke="currentColor" stroke-width="1.2"/>'
      '<path d="M5 2v3l1.5 1.5" stroke="currentColor" stroke-width="1.2" '
      'stroke-linecap="round"/>'
      '</svg>';

  static const String _arrowRight =
      '<svg viewBox="0 0 10 10" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M1 5h8M6 2l3 3-3 3" stroke="currentColor" stroke-width="1.5" '
      'stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>';

  static const String _pinSmall =
      '<svg viewBox="0 0 10 10" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M5 9.2C5 9.2 8.2 6.3 8.2 4.1A3.2 3.2 0 0 0 1.8 4.1C1.8 6.3 5 '
      '9.2 5 9.2Z" stroke="currentColor" stroke-width="1.2" '
      'stroke-linejoin="round"/>'
      '<circle cx="5" cy="4.1" r="1.1" fill="currentColor"/>'
      '</svg>';

  static const String _starPath =
      'M9 1.8l2.2 4.6 5 .7-3.6 3.5.9 5L9 13.2l-4.5 2.4.9-5L1.8 7.1l5-.7z';

  static const String _star =
      '<svg viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="$_starPath" stroke="currentColor" stroke-width="1.5" '
      'stroke-linejoin="round"/>'
      '</svg>';

  static const String _starFilled =
      '<svg viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="$_starPath" fill="currentColor" stroke="currentColor" '
      'stroke-width="1.5" stroke-linejoin="round"/>'
      '</svg>';
}
