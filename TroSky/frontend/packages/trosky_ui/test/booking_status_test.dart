import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// The trip card after a move, with the backend's real stop names, in a
/// [width] wide card at [scale] text.
Future<void> _card(
  WidgetTester tester, {
  required double width,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const TroskyTripSummaryCard(
                from: 'Accra Madina',
                to: 'Accra Circle',
                day: 'Today',
                time: '09:30',
                previousTime: '10:00',
                tag: 'New vehicle assigned',
                highlighted: true,
                facts: [
                  TroskyTripFact('Vehicle', 'GD-11-26'),
                  TroskyTripFact('Seats', 'A1 & A2'),
                  TroskyTripFact('Total', '₵9.00'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

bool _cut(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

void main() {
  testWidgets('a moved trip: both times on one line when the names fit', (
    tester,
  ) async {
    await _card(tester, width: 354);
    final before = tester.getRect(find.text('10:00'));
    final after = tester.getRect(find.text('09:30'));
    expect(before.right, lessThan(after.left));
    expect(_cut(tester, 'Accra Madina'), isFalse);
  });

  testWidgets('a narrow card with large text: the old time goes above the '
      'new one, and the stop names stay whole', (tester) async {
    await _card(tester, width: 324, scale: 1.15);
    final before = tester.getRect(find.text('10:00'));
    final after = tester.getRect(find.text('09:30'));
    expect(before.bottom, lessThanOrEqualTo(after.top + 1));
    expect(_cut(tester, 'Accra Madina'), isFalse);
    expect(_cut(tester, 'Accra Circle'), isFalse);
  });
}
