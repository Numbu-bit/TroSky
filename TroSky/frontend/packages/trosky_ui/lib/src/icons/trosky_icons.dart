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

  /// Clock on the "approaching your stop" banner (P6), 14 px; the P-07
  /// countdowns draw it larger.
  static Widget clock({required Color color, double size = 14}) =>
      _icon(_clock, color, size, size);

  /// "i" in a ring, white on the blue disc of an info banner (P-07), 16 px.
  static Widget info({required Color color, double size = 16}) =>
      _icon(_info, color, size, size);

  /// Up arrow on the "New vehicle assigned" tag (P-07), 12 px.
  static Widget arrowUp({required Color color, double size = 12}) =>
      _icon(_arrowUp, color, size, size);

  /// A booking card with a minus badge: "No driver accepted your booking"
  /// (P-07), 42 px.
  static Widget bookingNotAccepted({required Color color, double size = 42}) =>
      _icon(_bookingNotAccepted, color, size, size);

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

  /// Ticket on a Trip History row (P13), 20 px.
  static Widget ticket({required Color color}) => _icon(_ticket, color, 20, 20);

  /// Two sheets, copying the booking reference (P-16; not in the Figma
  /// code, drawn from the screenshot), 14 px.
  static Widget copy({required Color color}) => _icon(_copy, color, 14, 14);

  /// Wallet on a refund note (P-16; drawn from the screenshot), 16 px.
  static Widget wallet({required Color color}) => _icon(_wallet, color, 16, 16);

  /// Ticked circle: "Booking cancelled" (P-16; drawn from the screenshot),
  /// 36 px.
  static Widget checkCircle({required Color color, double size = 36}) =>
      _icon(_checkCircle, color, size, size);

  /// A vehicle seen from the front, on Booking details (P-16; drawn from
  /// the screenshot), 22 px.
  static Widget vehicle({required Color color}) =>
      _icon(_vehicle, color, 22, 22);

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

  // The three P-07 icons below are drawn from the Figma screenshots (no
  // Figma Make code), in the stroke style of the icons above.
  static const String _info =
      '<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="8" cy="8" r="6.5" stroke="currentColor" stroke-width="1.5"/>'
      '<path d="M8 7.5v3.5" stroke="currentColor" stroke-width="1.5" '
      'stroke-linecap="round"/>'
      '<circle cx="8" cy="5" r="0.9" fill="currentColor"/>'
      '</svg>';

  static const String _arrowUp =
      '<svg viewBox="0 0 10 10" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M5 9V1M2 4l3-3 3 3" stroke="currentColor" stroke-width="1.5" '
      'stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>';

  static const String _bookingNotAccepted =
      '<svg viewBox="5 4 33 33" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M26 31H11a4 4 0 0 1-4-4V13a4 4 0 0 1 4-4h18a4 4 0 0 1 4 4v8" '
      'stroke="currentColor" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M13 6v5M27 6v5M12 17h14M12 22h8" stroke="currentColor" '
      'stroke-width="2" stroke-linecap="round"/>'
      '<circle cx="31" cy="29" r="6" stroke="currentColor" stroke-width="2"/>'
      '<path d="M28 29h6" stroke="currentColor" stroke-width="2" '
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

  static const String _ticket =
      '<svg viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="2" y="6" width="16" height="11" rx="2" stroke="currentColor" '
      'stroke-width="1.5"/>'
      '<path d="M6 6V4a2 2 0 014 0v2M6 10h2m4 0h2M6 13h2" '
      'stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>';

  static const String _copy =
      '<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="5.5" y="5.5" width="8.5" height="8.5" rx="1.75" '
      'stroke="currentColor" stroke-width="1.5"/>'
      '<path d="M10.5 5.5V3.75A1.75 1.75 0 008.75 2h-5A1.75 1.75 0 002 3.75v5'
      'A1.75 1.75 0 003.75 10.5H5.5" stroke="currentColor" '
      'stroke-width="1.5"/>'
      '</svg>';

  static const String _wallet =
      '<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="1.75" y="3.25" width="12.5" height="9.5" rx="2" '
      'stroke="currentColor" stroke-width="1.5"/>'
      '<path d="M1.75 6.25h12.5" stroke="currentColor" stroke-width="1.5"/>'
      '</svg>';

  static const String _checkCircle =
      '<svg viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="18" cy="18" r="14.5" stroke="currentColor" '
      'stroke-width="2.5"/>'
      '<path d="M12 18.5l4 4 8-9" stroke="currentColor" stroke-width="2.5" '
      'stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>';

  static const String _vehicle =
      '<svg viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="4" y="4" width="14" height="12" rx="3" stroke="currentColor" '
      'stroke-width="1.8"/>'
      '<path d="M7.5 10h2M12.5 10h2M7 16v2M15 16v2" stroke="currentColor" '
      'stroke-width="1.8" stroke-linecap="round"/>'
      '</svg>';
}
