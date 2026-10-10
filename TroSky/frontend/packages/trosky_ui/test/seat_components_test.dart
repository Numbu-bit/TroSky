import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

Widget _frame(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

Widget _price(String value, {bool reduceMotion = false}) => _frame(
  TroskyPriceFlash(
    value: value,
    style: TroskyTypography.heading30ExtraBoldH100.copyWith(
      color: TroskyColors.ink,
    ),
  ),
  reduceMotion: reduceMotion,
);

Text _priceText(WidgetTester tester) => tester.widget<Text>(
  find.descendant(
    of: find.byType(TroskyPriceFlash),
    matching: find.byType(Text),
  ),
);

double _priceScale(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(TroskyPriceFlash),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getMaxScaleOnAxis();

void main() {
  group('TroskyPriceFlash (P7 fare-flash)', () {
    testWidgets('a new price flashes green and grows 5 %, then settles', (
      tester,
    ) async {
      await tester.pumpWidget(_price('₵14.00'));
      expect(_priceText(tester).style?.color, TroskyColors.ink);

      await tester.pumpWidget(_price('₵7.33'));
      // The peak, at 40 % of 500 ms.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_priceText(tester).data, '₵7.33');
      expect(_priceText(tester).style?.color, TroskyColors.green);
      expect(_priceScale(tester), closeTo(1.05, 0.001));

      await tester.pumpAndSettle();
      expect(_priceText(tester).style?.color, TroskyColors.ink);
      expect(_priceScale(tester), 1);
    });

    testWidgets('the same price does not flash', (tester) async {
      await tester.pumpWidget(_price('₵14.00'));
      await tester.pumpWidget(_price('₵14.00'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_priceText(tester).style?.color, TroskyColors.ink);
    });

    testWidgets('with "remove animations" on, the price just changes', (
      tester,
    ) async {
      await tester.pumpWidget(_price('₵14.00', reduceMotion: true));
      await tester.pumpWidget(_price('₵7.33', reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_priceText(tester).data, '₵7.33');
      expect(_priceText(tester).style?.color, TroskyColors.ink);
    });
  });

  group('TroskySeat', () {
    testWidgets('taps only while free; taken seats are dimmed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _frame(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TroskySeat(
                number: '4',
                state: TroskySeatState.available,
                semanticsLabel: 'Seat 4',
                onPressed: () => taps++,
              ),
              const TroskySeat(
                number: '2',
                state: TroskySeatState.taken,
                semanticsLabel: 'Seat 2, taken',
              ),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(TroskySeat).first), TroskySeat.size);
      await tester.tap(find.text('4'));
      expect(taps, 1);
      // A taken seat shows who sits there, not its number.
      expect(find.text('2'), findsNothing);
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(TroskySeat).last,
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        TroskyOpacity.seatTaken,
      );
    });
  });

  testWidgets('TroskyBookedCounter: one bar per seat, the booked ones green', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        const SizedBox(
          width: 360,
          child: TroskyBookedCounter(
            booked: 5,
            total: 14,
            suffix: '/14 booked',
            semanticsLabel: '5 of 14 seats booked',
          ),
        ),
      ),
    );
    expect(find.textContaining(RegExp(r'^5.?/14 booked$')), findsOneWidget);
    final bars = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => (c.decoration! as BoxDecoration).color)
        .toList();
    expect(bars, [
      for (var i = 0; i < 14; i++)
        i < 5 ? TroskyColors.green : TroskyColors.border,
    ]);
  });
}
