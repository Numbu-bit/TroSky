import 'package:flutter/widgets.dart';

import '../icons/trosky_icons.dart';
import '../painting/svg_painting.dart';
import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_motion.dart';
import '../tokens/trosky_opacity.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_shadows.dart';
import '../tokens/trosky_typography.dart';

/// A vehicle on the map: `BusPin` in Shared.tsx. A 32 px disc with the bus
/// glyph and a drop shadow, and a seat-count badge up and to the right, all
/// in green, or amber for [amber].
///
/// The widget is [size], with the disc's centre in the middle, so a map
/// marker centred on the vehicle's position places it right.
class TroskyBusPin extends StatelessWidget {
  const TroskyBusPin({
    super.key,
    required this.seats,
    this.amber = false,
    this.semanticsLabel,
  });

  /// Free seats, shown in the badge.
  final int seats;
  final bool amber;
  final String? semanticsLabel;

  /// The badge sticks out 28 px right of and 22 px above the centre.
  static const Size size = Size(56, 44);

  @override
  Widget build(BuildContext context) {
    final fill = amber ? TroskyColors.amber : TroskyColors.green;
    // `<rect x={x + 8} y={y - 22} width={seats > 9 ? 20 : 17} height={14}>`
    final badgeWidth = seats > 9 ? 20.0 : 17.0;
    return Semantics(
      // One node per pin, not merged with its neighbours on the map.
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            Positioned(
              left: size.width / 2 - 16,
              top: size.height / 2 - 16,
              width: 32,
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  boxShadow: amber
                      ? TroskyShadows.busPinAmber
                      : TroskyShadows.busPinGreen,
                ),
                child: Center(
                  child: TroskyIcons.bus(color: TroskyColors.white),
                ),
              ),
            ),
            Positioned(
              left: size.width / 2 + 8,
              top: size.height / 2 - 22,
              width: badgeWidth,
              height: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(TroskyRadii.r7),
                ),
                child: CustomPaint(painter: _BadgeText('$seats', badgeWidth)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `<text x={x + (seats > 9 ? 18 : 16.5)} y={y - 14} textAnchor="middle">`:
/// 8 px down from the badge's top, centred on the narrow badge, 2 px right
/// of the wide one's centre.
class _BadgeText extends CustomPainter {
  _BadgeText(this.text, this.badgeWidth);

  final String text;
  final double badgeWidth;

  @override
  void paint(Canvas canvas, Size size) => paintSvgText(
    canvas,
    text,
    TroskyTypography.svgBody8Bold.copyWith(color: TroskyColors.white),
    Offset(badgeWidth > 17 ? 10 : 8.5, 8),
    anchor: SvgTextAnchor.middle,
  );

  @override
  bool shouldRepaint(_BadgeText old) => old.text != text;
}

/// The passenger's position: `AcraMap`'s overlay in Shared.tsx. A 7 px
/// green dot with a 3 px white centre, a 14 px halo at 25 %, and a 24 px
/// ring pulsing (`.anim-pulse`: scale 1 → 1.6, opacity 0.8 → 0.3, 2 s).
///
/// The browser scales the ring from the SVG's corner, so in the design it
/// drifts away from the dot; here it pulses around the dot as intended.
/// When the phone asks for fewer animations the ring stands still at the
/// SVG's own 15 %.
class TroskyLocationDot extends StatefulWidget {
  const TroskyLocationDot({super.key, this.semanticsLabel});

  final String? semanticsLabel;

  /// Room for the ring at its largest (24 × 1.6 px radius).
  static const Size size = Size(78, 78);

  @override
  State<TroskyLocationDot> createState() => _TroskyLocationDotState();
}

class _TroskyLocationDotState extends State<TroskyLocationDot>
    with SingleTickerProviderStateMixin {
  // One half of the keyframes (0% → 50%); reversing gives the other half.
  late final AnimationController _half = AnimationController(
    vsync: this,
    duration: TroskyMotion.pulseDuration ~/ 2,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _half,
    curve: TroskyMotion.easeInOut,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _half
        ..stop()
        ..value = 0;
    } else if (!_half.isAnimating) {
      _half.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _half.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: TroskyLocationDot.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _t,
              builder: (context, child) {
                // `<circle r="24" opacity="0.15">` without its animation.
                if (_still) {
                  return Opacity(opacity: TroskyOpacity.o15, child: child);
                }
                final t = _t.value;
                final scale =
                    TroskyMotion.pulseScaleFrom +
                    (TroskyMotion.pulseScaleTo - TroskyMotion.pulseScaleFrom) *
                        t;
                final opacity =
                    TroskyMotion.pulseOpacityFrom +
                    (TroskyMotion.pulseOpacityTo -
                            TroskyMotion.pulseOpacityFrom) *
                        t;
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: const _Disc(diameter: 48, color: TroskyColors.green),
            ),
            const _Disc(diameter: 28, color: TroskyColors.greenA25),
            const _Disc(diameter: 14, color: TroskyColors.green),
            const _Disc(diameter: 6, color: TroskyColors.white),
          ],
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A round button over a map, drawn at its design size with a 48 px touch
/// area around it.
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.diameter,
    required this.decoration,
    required this.semanticsLabel,
    required this.onPressed,
    required this.child,
  });

  final double diameter;
  final BoxDecoration decoration;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final Widget child;

  static const double touchSize = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: touchSize,
          child: Center(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: decoration,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// "My location" on the Home map (P5): a 36 px white disc with the green
/// crosshair. Its touch area is 48 px, 6 px past the disc on every side.
class TroskyMyLocationButton extends StatelessWidget {
  const TroskyMyLocationButton({
    super.key,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _MapButton(
      diameter: 36,
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        shape: BoxShape.circle,
        boxShadow: TroskyShadows.mapFab,
      ),
      semanticsLabel: semanticsLabel,
      onPressed: onPressed,
      child: TroskyIcons.myLocation(color: TroskyColors.green),
    );
  }
}

/// The SOS button on the Home map (P5): a 44 px red disc with a 2 px white
/// rim at 30 % and a red glow, "SOS" in Plus Jakarta Sans 10/800. Its touch
/// area is 48 px.
class TroskySosButton extends StatelessWidget {
  const TroskySosButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  /// "SOS".
  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _MapButton(
      diameter: 44,
      decoration: BoxDecoration(
        color: TroskyColors.red,
        shape: BoxShape.circle,
        border: Border.all(
          color: TroskyColors.whiteA30,
          width: TroskyBorders.w2,
        ),
        boxShadow: TroskyShadows.sosButton,
      ),
      semanticsLabel: semanticsLabel,
      onPressed: onPressed,
      child: Text(
        label,
        // Part of the drawing: it must fit the disc at any text size.
        textScaler: TextScaler.noScaling,
        style: TroskyTypography.heading10ExtraBold.copyWith(
          color: TroskyColors.white,
        ),
      ),
    );
  }
}
