import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

void main() {
  testWidgets(
    'a long booking reference stays on one line, full size, with a chip, '
    'on a 360 px phone at text scale 1.15',
    (tester) async {
      tester.view.physicalSize = const Size(360, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: TroskyTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 400),
              textScaler: TextScaler.linear(1.15),
            ),
            child: Material(
              child: TroskyPageHeader(
                title: 'Booking details',
                subtitle: 'TRK-6VJF55ME',
                onBack: () {},
                subtitleTrailing: TroskyIcons.copy(
                  color: TroskyColors.whiteA55,
                ),
                trailing: const TroskyStatusChip(
                  label: 'Pending payment',
                  tone: TroskyTagTone.amber,
                ),
              ),
            ),
          ),
        ),
      );
      final reference = tester.renderObject<RenderParagraph>(
        find.text('TRK-6VJF55ME'),
      );
      expect(reference.didExceedMaxLines, isFalse);
      expect(
        reference
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 12),
            )
            .map((box) => box.top)
            .toSet(),
        hasLength(1),
      );
      // Not shrunk to fit either: the chip leaves the line below the title
      // to the reference.
      final fitted = find.ancestor(
        of: find.text('TRK-6VJF55ME'),
        matching: find.byType(FittedBox),
      );
      expect(
        tester.getSize(fitted).width /
            tester.getSize(find.text('TRK-6VJF55ME')).width,
        greaterThan(0.95),
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('status colours read at WCAG AA (4.5:1)', () {
    double luminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double contrast(Color a, Color b) {
      final (la, lb) = (luminance(a), luminance(b));
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final tone in TroskyTagTone.values) {
      test(
        '${tone.name}: on its tag over a white card, and on the white chip',
        () {
          final tag = Color.alphaBlend(tone.background, TroskyColors.surface);
          expect(contrast(tone.text, tag), greaterThanOrEqualTo(4.5));
          expect(
            contrast(tone.text, TroskyColors.surface),
            greaterThanOrEqualTo(4.5),
          );
        },
      );
    }
  });
}
