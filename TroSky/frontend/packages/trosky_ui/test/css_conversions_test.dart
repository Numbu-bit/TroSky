import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// Start and end of the CSS gradient line for [angle] painted into [rect].
(Offset, Offset) gradientLine(double angle, Rect rect) {
  final matrix = CssGradientTransform(angle).transform(rect);
  return (
    MatrixUtils.transformPoint(matrix, rect.topCenter),
    MatrixUtils.transformPoint(matrix, rect.bottomCenter),
  );
}

Matcher offsetCloseTo(Offset expected) => isA<Offset>()
    .having((o) => o.dx, 'dx', closeTo(expected.dx, 1e-6))
    .having((o) => o.dy, 'dy', closeTo(expected.dy, 1e-6));

void main() {
  group('cssLinearGradient angles', () {
    const tall = Rect.fromLTWH(0, 0, 100, 200);

    test('0deg runs to the top', () {
      final (start, end) = gradientLine(0, tall);
      expect(start, offsetCloseTo(const Offset(50, 200)));
      expect(end, offsetCloseTo(const Offset(50, 0)));
    });

    test('90deg runs to the right', () {
      final (start, end) = gradientLine(90, tall);
      expect(start, offsetCloseTo(const Offset(0, 100)));
      expect(end, offsetCloseTo(const Offset(100, 100)));
    });

    test('180deg runs to the bottom and 270deg to the left', () {
      final (start, end) = gradientLine(180, tall);
      expect(start, offsetCloseTo(const Offset(50, 0)));
      expect(end, offsetCloseTo(const Offset(50, 200)));
      final (start270, end270) = gradientLine(270, tall);
      expect(start270, offsetCloseTo(const Offset(100, 100)));
      expect(end270, offsetCloseTo(const Offset(0, 100)));
    });

    test('135deg on a square goes corner to corner', () {
      final (start, end) = gradientLine(
        135,
        const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(start, offsetCloseTo(Offset.zero));
      expect(end, offsetCloseTo(const Offset(100, 100)));
    });

    test('160deg on the 312 x 686 screen runs mostly down, a little right', () {
      final (start, end) = gradientLine(
        160,
        const Rect.fromLTWH(0, 0, 312, 686),
      );
      final direction = end - start;
      expect(direction.dy, greaterThan(0));
      expect(direction.dx, greaterThan(0));
      expect(
        direction.dy / direction.dx,
        closeTo(1 / math.tan(20 * math.pi / 180), 1e-6),
      );
    });

    // CSS sizes the line so the nearest and farthest corners sit exactly at
    // 0% and 100%; check that for several angles and box shapes.
    for (final angle in <double>[
      0,
      30,
      90,
      120,
      135,
      160,
      180,
      200,
      270,
      315,
    ]) {
      for (final size in [const Size(312, 686), const Size(390, 120)]) {
        test(
          '${angle}deg on ${size.width} x ${size.height} spans the corners',
          () {
            final rect = Offset.zero & size;
            final (start, end) = gradientLine(angle, rect);
            final line = end - start;
            double at(Offset p) {
              final v = p - start;
              return (v.dx * line.dx + v.dy * line.dy) / line.distanceSquared;
            }

            final ts = [
              at(rect.topLeft),
              at(rect.topRight),
              at(rect.bottomLeft),
              at(rect.bottomRight),
            ];
            expect(ts.reduce(math.min), closeTo(0, 1e-9));
            expect(ts.reduce(math.max), closeTo(1, 1e-9));
          },
        );
      }
    }
  });

  group('CSS stop positions', () {
    test('explicit percentages such as 45% become fractions', () {
      expect(resolveCssStopPositions([0, 45, 100]), [0, 0.45, 1]);
    });

    test('missing ends default to 0% and 100%', () {
      expect(resolveCssStopPositions([null, null]), [0, 1]);
    });

    test('missing middle stops are spread evenly', () {
      expect(resolveCssStopPositions([null, null, null]), [0, 0.5, 1]);
      final spread = resolveCssStopPositions([10, null, null, 70]);
      expect(spread[1], closeTo(0.3, 1e-9));
      expect(spread[2], closeTo(0.5, 1e-9));
    });

    test('a stop before an earlier one is raised to it', () {
      expect(resolveCssStopPositions([0, 50, 30, 100]), [0, 0.5, 0.5, 1]);
    });

    test('cssLinearGradient carries colours and resolved stops', () {
      final gradient = cssLinearGradient(160, const [
        CssColorStop(TroskyColors.greenDark, 0),
        CssColorStop(TroskyColors.green, 45),
        CssColorStop(TroskyColors.onboardingGreenEnd, 100),
      ]);
      expect(gradient.colors, [
        TroskyColors.greenDark,
        TroskyColors.green,
        TroskyColors.onboardingGreenEnd,
      ]);
      expect(gradient.stops, [0, 0.45, 1]);
      expect(gradient.transform, const CssGradientTransform(160));
    });
  });

  group('cssBoxShadow', () {
    test('keeps offset and colour', () {
      final shadow = cssBoxShadow(0, 8, 24, TroskyColors.blackA20);
      expect(shadow.offset, const Offset(0, 8));
      expect(shadow.color, TroskyColors.blackA20);
      expect(shadow.spreadRadius, 0);
    });

    test('matches the CSS blur: sigma is half the blur radius', () {
      for (final blur in <double>[6, 8, 12, 20, 24, 40, 64, 80]) {
        final shadow = cssBoxShadow(0, 0, blur, TroskyColors.blackA20);
        expect(shadow.blurSigma, closeTo(blur / 2, 1e-4), reason: '$blur px');
      }
    });

    test('no blur stays sharp and spread is passed through', () {
      final shadow = cssBoxShadow(1, 2, 0, TroskyColors.redA50, spread: 3);
      expect(shadow.blurRadius, 0);
      expect(shadow.spreadRadius, 3);
    });
  });
}
