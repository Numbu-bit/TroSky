@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/trosky_mobile_app.dart';

import 'payment_helpers.dart';

/// Leaving Payment with seats held (decision 31) at the design frame, 390 x
/// 844, in mock mode: the sheet, and Home's card for the held booking. The
/// whole app is captured, so the sheet shows over Payment.
void _goldenTest(
  String description,
  String name,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(TroskyMobileApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  const frame = Size(390, 844);

  _goldenTest(
    'Leave payment? over a booking waiting for its driver',
    'leave_sheet_390',
    (tester) async {
      final (world, _) = await reserve(tester, size: frame);
      await waitFor(tester, world, const Duration(seconds: 18));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    },
  );

  _goldenTest(
    'Home: the card of a booking waiting for its driver',
    'home_held_waiting_390',
    (tester) async {
      final (world, _) = await reserve(tester, size: frame);
      await waitFor(tester, world, const Duration(seconds: 18));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep seats & leave'));
      await tester.pumpAndSettle();
    },
  );

  _goldenTest('Home: the card of seats held to pay for', 'home_held_pay_390', (
    tester,
  ) async {
    final (world, booking) = await reserve(tester, size: frame);
    world.backend.acceptBooking(booking.id);
    await nextPoll(tester, world);
    await waitFor(tester, world, const Duration(seconds: 48));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep seats & leave'));
    await tester.pumpAndSettle();
  });
}
