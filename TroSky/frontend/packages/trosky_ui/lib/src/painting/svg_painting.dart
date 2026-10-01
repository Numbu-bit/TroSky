import 'dart:math' as math;

import 'package:flutter/painting.dart';

// Helpers for drawing the Figma Make SVG illustrations with a CustomPainter,
// in the SVG's own coordinates.

/// SVG `text-anchor`.
enum SvgTextAnchor { start, middle }

/// A `<circle>` outline as SVG draws it: starting at 3 o'clock and running
/// clockwise, so `stroke-dasharray` dashes land where the browser puts them.
Path svgCirclePath(Offset centre, double radius) => Path()
  ..addArc(
    Rect.fromCircle(center: centre, radius: radius),
    0,
    2 * math.pi - 1e-9,
  );

/// [source] cut into dashes like SVG `stroke-dasharray`: [pattern] alternates
/// dash and gap lengths, restarting on every contour.
Path dashedPath(Path source, List<double> pattern) {
  assert(pattern.isNotEmpty && pattern.every((v) => v >= 0));
  final dashes = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var i = 0;
    while (distance < metric.length) {
      final length = pattern[i % pattern.length];
      if (i.isEven) {
        dashes.addPath(
          metric.extractPath(
            distance,
            math.min(distance + length, metric.length),
          ),
          Offset.zero,
        );
      }
      distance += length;
      i++;
    }
  }
  return dashes;
}

/// Paints [text] like an SVG `<text>`: [position] is the alphabetic baseline
/// at the anchor point. The text ignores the system text size, because it is
/// part of the drawing.
void paintSvgText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset position, {
  SvgTextAnchor anchor = SvgTextAnchor.start,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final dx = anchor == SvgTextAnchor.middle ? painter.width / 2 : 0.0;
  painter.paint(canvas, position - Offset(dx, baseline));
  painter.dispose();
}
