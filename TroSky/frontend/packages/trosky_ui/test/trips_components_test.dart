import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

void main() {
  testWidgets('a long booking reference stays on one line beside a chip, '
      'on a 360 px phone at text scale 1.15', (tester) async {
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
              subtitleTrailing: TroskyIcons.copy(color: TroskyColors.whiteA55),
              trailing: const TroskyChip(
                label: 'Pending payment',
                color: TroskyChipColor.amber,
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
    expect(tester.takeException(), isNull);
  });
}
