import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// One colour stop of a CSS gradient.
///
/// [percent] is the CSS position (`45` for `45%`). Leave it null to let the
/// CSS rules place the stop, as in `linear-gradient(135deg, #a, #b)`.
@immutable
class CssColorStop {
  const CssColorStop(this.color, [this.percent]);

  final Color color;
  final double? percent;
}

/// Converts CSS `linear-gradient(<angleDeg>deg, <stops>)` to a
/// [LinearGradient].
///
/// CSS measures the angle clockwise from "to top" in the box's real pixel
/// space: 0deg points up, 90deg right, 180deg down, so 160deg runs mostly
/// down and slightly right. The gradient line passes through the centre and
/// is long enough for the first and last stops to reach the far corners. A
/// Flutter [Alignment] pair is normalised to the box instead, so it only
/// matches CSS on squares; [CssGradientTransform] rebuilds the CSS line for
/// the actual size when the gradient is painted.
///
/// `to right`, `to bottom`, `to left` and `to top` are 90, 180, 270 and 0.
LinearGradient cssLinearGradient(double angleDeg, List<CssColorStop> stops) {
  assert(stops.length >= 2, 'A CSS gradient needs at least two stops');
  return LinearGradient(
    // CssGradientTransform expects the vertical default and rotates it.
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [for (final stop in stops) stop.color],
    stops: resolveCssStopPositions([for (final stop in stops) stop.percent]),
    transform: CssGradientTransform(angleDeg),
  );
}

/// Fills in stop positions the way CSS does, returning fractions (0–1).
///
/// A missing first position is 0%, a missing last one is 100%, a position
/// smaller than an earlier one is raised to match it, and each run of missing
/// positions is spread evenly between its neighbours.
List<double> resolveCssStopPositions(List<double?> percents) {
  assert(percents.length >= 2, 'A CSS gradient needs at least two stops');
  final positions = [
    for (final percent in percents) percent == null ? null : percent / 100,
  ];
  positions[0] ??= 0;
  positions[positions.length - 1] ??= 1;

  var highest = positions[0]!;
  for (var i = 1; i < positions.length; i++) {
    final position = positions[i];
    if (position == null) continue;
    highest = math.max(highest, position);
    positions[i] = highest;
  }

  for (var i = 1; i < positions.length; i++) {
    if (positions[i] != null) continue;
    final before = i - 1;
    var after = i;
    while (positions[after] == null) {
      after++;
    }
    final from = positions[before]!;
    final to = positions[after]!;
    final gaps = after - before;
    for (var k = 1; k < gaps; k++) {
      positions[before + k] = from + (to - from) * k / gaps;
    }
    i = after;
  }
  return [for (final position in positions) position!];
}

/// Maps a top-to-bottom [LinearGradient] onto the CSS gradient line for
/// [angleDeg] in the painted box.
///
/// The CSS line runs through the box centre in direction
/// (sin θ, −cos θ) with length |w·sin θ| + |h·cos θ|. The default vertical
/// gradient is scaled to that length and rotated by θ + 180° about the
/// centre.
@immutable
class CssGradientTransform extends GradientTransform {
  const CssGradientTransform(this.angleDeg);

  final double angleDeg;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final theta = angleDeg * math.pi / 180;
    final length =
        (bounds.width * math.sin(theta)).abs() +
        (bounds.height * math.cos(theta)).abs();
    final scale = bounds.height == 0 ? 1.0 : length / bounds.height;
    final center = bounds.center;
    return Matrix4.translationValues(center.dx, center.dy, 0)
        .multiplied(Matrix4.rotationZ(theta + math.pi))
        .multiplied(Matrix4.diagonal3Values(1, scale, 1))
        .multiplied(Matrix4.translationValues(-center.dx, -center.dy, 0));
  }

  @override
  bool operator ==(Object other) =>
      other is CssGradientTransform && other.angleDeg == angleDeg;

  @override
  int get hashCode => angleDeg.hashCode;
}

/// Converts CSS `box-shadow: <x>px <y>px <blur>px [<spread>px] <color>` to a
/// [BoxShadow]. `filter: drop-shadow(...)` uses the same blur rule.
BoxShadow cssBoxShadow(
  double x,
  double y,
  double blur,
  Color color, {
  double spread = 0,
}) {
  return BoxShadow(
    color: color,
    offset: Offset(x, y),
    blurRadius: cssBlurToFlutterBlurRadius(blur),
    spreadRadius: spread,
  );
}

/// CSS blurs a shadow with a Gaussian whose standard deviation is half the
/// blur radius. Flutter derives the sigma from [BoxShadow.blurRadius] as
/// `radius * 0.57735 + 0.5`, so this returns the radius that lands on the
/// CSS sigma.
double cssBlurToFlutterBlurRadius(double cssBlur) {
  if (cssBlur <= 0) return 0;
  return math.max(0, (cssBlur / 2 - 0.5) / 0.57735);
}
