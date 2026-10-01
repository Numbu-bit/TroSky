import 'dart:ui' show PictureRecorder;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

double _offset(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(TroskyFloat),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .y;

Widget _float({required Duration delay, bool reduceMotion = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: TroskyFloat(
        delay: delay,
        child: const SizedBox.square(dimension: 10),
      ),
    );

void main() {
  group('TroskyFloat', () {
    testWidgets('rests for the delay, then floats up 6 px and back over 3 s', (
      tester,
    ) async {
      await tester.pumpWidget(_float(delay: const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 499));
      expect(_offset(tester), 0);

      // Delay over: the cycle starts on the next frame.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(_offset(tester), moreOrLessEquals(TroskyMotion.floatOffset));

      await tester.pump(const Duration(milliseconds: 1500));
      expect(_offset(tester), moreOrLessEquals(0));
    });

    testWidgets('stays still with reduce motion', (tester) async {
      await tester.pumpWidget(_float(delay: Duration.zero, reduceMotion: true));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 750));
        expect(_offset(tester), 0);
      }
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('dashedPath', () {
    test('cuts dashes and gaps along the path', () {
      final line = Path()
        ..moveTo(0, 0)
        ..lineTo(40, 0);
      final dashes = dashedPath(line, const [12, 8]).computeMetrics().toList();
      // 0–12, 20–32: two full dashes; the next would start at 40.
      expect(dashes.map((m) => m.length), [12, 12]);
    });

    test('a dashed SVG circle starts at 3 o\'clock and runs clockwise', () {
      final first = dashedPath(svgCirclePath(Offset.zero, 10), const [
        4,
        4,
      ]).computeMetrics().first;
      final start = first.getTangentForOffset(0)!;
      expect(start.position.dx, moreOrLessEquals(10));
      expect(start.position.dy, moreOrLessEquals(0));
      // Clockwise on screen means moving towards +y first.
      expect(start.vector.dy, greaterThan(0));
    });
  });

  testWidgets('paintSvgText paints with either anchor', (tester) async {
    // Placement is checked by the onboarding goldens; this only checks both
    // anchors paint.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    paintSvgText(
      canvas,
      'YOUR SEAT',
      TroskyTypography.svgBody9Bold,
      const Offset(108, 85),
      anchor: SvgTextAnchor.middle,
    );
    paintSvgText(
      canvas,
      '07:15',
      TroskyTypography.svgBody8SemiBold,
      Offset.zero,
    );
    recorder.endRecording().dispose();
  });

  testWidgets('PageDots reads out the label it is given', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PageDots.onboarding(index: 1, semanticsLabel: 'Ukurasa 2'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Ukurasa 2'), findsOneWidget);
    semantics.dispose();
  });
}
