import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_shadows.dart';

/// A decorative circle: an outlined ring or a filled disc.
class DecorativeCircle extends StatelessWidget {
  /// Ring with a border drawn inside [diameter] (CSS box-sizing: border-box).
  const DecorativeCircle.ring({
    super.key,
    required this.diameter,
    required this.color,
    this.borderWidth = TroskyBorders.w1,
  }) : filled = false;

  /// Filled disc.
  const DecorativeCircle.filled({
    super.key,
    required this.diameter,
    required this.color,
  }) : filled = true,
       borderWidth = 0;

  final double diameter;
  final Color color;
  final double borderWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : null,
            border: filled
                ? null
                : Border.all(color: color, width: borderWidth),
          ),
        ),
      ),
    );
  }
}

/// Soft glow: a filled disc blurred with a Gaussian of [sigma].
class DecorativeGlow extends StatelessWidget {
  const DecorativeGlow({
    super.key,
    required this.diameter,
    required this.color,
    required this.sigma,
  });

  final double diameter;
  final Color color;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
      child: DecorativeCircle.filled(diameter: diameter, color: color),
    );
  }
}

/// One ring of [DecorativeRings].
@immutable
class DecorativeRing {
  const DecorativeRing(this.diameter, this.color);

  final double diameter;
  final Color color;
}

/// Concentric 1 px rings centred on their parent, allowed to overflow it (the
/// splash rings are wider than the screen).
class DecorativeRings extends StatelessWidget {
  const DecorativeRings({super.key, required this.rings});

  final List<DecorativeRing> rings;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final ring in rings)
            DecorativeCircle.ring(diameter: ring.diameter, color: ring.color),
        ],
      ),
    );
  }
}

/// A circle placed like the absolutely positioned decorations in the design:
/// offsets are distances from the screen edges and may be negative.
@immutable
class _Placed {
  const _Placed(this.circle, {this.top, this.right, this.bottom, this.left});

  final Widget circle;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
}

/// The decoration layer behind the splash and onboarding screens, with the
/// sizes, offsets and colours from the Figma Make code. Fill the screen with
/// it (e.g. `Positioned.fill`) under the content.
class DecorativeBackdrop extends StatelessWidget {
  /// Splash: rings of 500, 380 and 260 px, a 200 px glow blurred 40 px, a
  /// dark disc bottom-left and a light disc top-right.
  const DecorativeBackdrop.splash({super.key}) : _variant = 0;

  /// Onboarding 1: two rings off the top-right corner and a dark disc
  /// bottom-left.
  const DecorativeBackdrop.onboarding1({super.key}) : _variant = 1;

  /// Onboarding 2: a ring off the top-left corner and a faint amber disc on
  /// the right. Onboarding 3 has no decorations.
  const DecorativeBackdrop.onboarding2({super.key}) : _variant = 2;

  final int _variant;

  static const _splashRings = DecorativeRings(
    rings: [
      DecorativeRing(500, TroskyColors.whiteA06),
      DecorativeRing(380, TroskyColors.whiteA08),
      DecorativeRing(260, TroskyColors.whiteA10),
    ],
  );

  List<_Placed> get _placed => switch (_variant) {
    0 => const [
      _Placed(
        DecorativeCircle.filled(diameter: 220, color: TroskyColors.blackA08),
        bottom: -80,
        left: -60,
      ),
      _Placed(
        DecorativeCircle.filled(diameter: 180, color: TroskyColors.whiteA06),
        top: -60,
        right: -60,
      ),
    ],
    1 => const [
      _Placed(
        DecorativeCircle.ring(diameter: 300, color: TroskyColors.whiteA08),
        top: -80,
        right: -80,
      ),
      _Placed(
        DecorativeCircle.ring(diameter: 200, color: TroskyColors.whiteA06),
        top: -20,
        right: -20,
      ),
      _Placed(
        DecorativeCircle.filled(diameter: 180, color: TroskyColors.blackA08),
        bottom: -60,
        left: -40,
      ),
    ],
    _ => const [
      _Placed(
        DecorativeCircle.ring(diameter: 280, color: TroskyColors.whiteA05),
        top: -60,
        left: -60,
      ),
      _Placed(
        DecorativeCircle.filled(diameter: 200, color: TroskyColors.amberA04),
        bottom: 100,
        right: -60,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (_variant == 0) ...[
            const Positioned.fill(child: _splashRings),
            const Positioned.fill(
              child: Center(
                child: DecorativeGlow(
                  diameter: 200,
                  color: TroskyColors.whiteA07,
                  sigma: TroskyShadows.splashGlowBlurSigma,
                ),
              ),
            ),
          ],
          for (final p in _placed)
            Positioned(
              top: p.top,
              right: p.right,
              bottom: p.bottom,
              left: p.left,
              child: p.circle,
            ),
        ],
      ),
    );
  }
}
