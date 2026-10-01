// Values from design/figma-make/globals.css (keyframes) and the inline
// `transition` / `animation-delay` styles in design/figma-make/src/designs.
// docs/design-tokens.md lists where each one is used.

import 'package:flutter/animation.dart';

/// Motion from the Figma Make designs.
///
/// CSS keyframe animations ease every segment separately, so an infinite
/// 0% → 50% → 100% animation such as pulse or float runs [easeInOut] on each
/// half. Honour `MediaQuery.disableAnimations` wherever these are used.
abstract final class TroskyMotion {
  // Timing functions

  /// CSS `ease`, the default for `transition` and `animation`:
  /// cubic-bezier(0.25, 0.1, 0.25, 1).
  static const Curve ease = Curves.ease;

  /// CSS `ease-in-out`: cubic-bezier(0.42, 0, 0.58, 1).
  static const Curve easeInOut = Curves.easeInOut;

  /// CSS `linear`.
  static const Curve linear = Curves.linear;

  /// `.anim-slide`: cubic-bezier(0.16, 1, 0.3, 1).
  static const Curve slideUpCurve = Cubic(0.16, 1, 0.3, 1);

  // pulse-dot · `.anim-pulse` · 2s ease-in-out infinite
  // Live location dot (AcraMap, P8).

  static const Duration pulseDuration = Duration(seconds: 2);
  static const double pulseScaleFrom = 1;
  static const double pulseScaleTo = 1.6;
  static const double pulseOpacityFrom = 0.8;
  static const double pulseOpacityTo = 0.3;

  // slide-up · `.anim-slide` · 0.4s cubic-bezier(0.16,1,0.3,1) forwards
  // Defined but not used by any screen yet.

  static const Duration slideUpDuration = Duration(milliseconds: 400);
  static const double slideUpOffset = 20;

  // float · `.anim-float` · 3s ease-in-out infinite
  // Onboarding illustrations (P1–P3).

  static const Duration floatDuration = Duration(seconds: 3);

  /// translateY at the 50% keyframe.
  static const double floatOffset = -6;

  /// `animation-delay` on the Onboarding 2 illustration.
  static const Duration floatDelayOnboarding2 = Duration(milliseconds: 500);

  /// `animation-delay` on the Onboarding 3 illustration.
  static const Duration floatDelayOnboarding3 = Duration(seconds: 1);

  // price-flash · `.anim-price` · 0.5s ease
  // Colour ink → green → ink with scale 1.05 at the 40% keyframe. Defined
  // but not used by any screen yet.

  static const Duration priceFlashDuration = Duration(milliseconds: 500);
  static const double priceFlashPeak = 0.4;
  static const double priceFlashScale = 1.05;

  // spin-slow · rotate 0 → 360deg
  // The CSS defines no duration or easing and no class uses it, so there is
  // no duration token. Ask for one before using it.

  static const double spinSlowTurns = 1;

  // ripple · scale 1 → 3, opacity 0.6 → 0
  // Also defined without a duration or class. Ask before using it.

  static const double rippleScaleFrom = 1;
  static const double rippleScaleTo = 3;
  static const double rippleOpacityFrom = 0.6;
  static const double rippleOpacityTo = 0;

  // Inline `transition` durations (CSS `ease` unless noted)

  /// `all 0.15s` · subscription plan cards (P10).
  static const Duration transition150 = Duration(milliseconds: 150);

  /// `all 0.2s` · seats (P7), Go Online/Offline button (D1).
  static const Duration transition200 = Duration(milliseconds: 200);

  /// `all 0.25s` · seat selection (P7).
  static const Duration transition250 = Duration(milliseconds: 250);

  /// `all 0.3s` · onboarding page dots (P1); `background 0.3s` (D2).
  static const Duration transition300 = Duration(milliseconds: 300);

  /// `all 0.4s` (D4); `background 0.4s` · booked counter (P7).
  static const Duration transition400 = Duration(milliseconds: 400);
}
