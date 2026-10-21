@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';

import 'payment_helpers.dart';

/// Payment's four booking states (P-07) at the design frame, 390 x 844, in
/// mock mode: Madina → Circle on the 09:03 minibus, seats 3 and 4. Shadows
/// are blurred from the start, so the cards are painted as on a phone.
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
        find.byType(PaymentScreen),
        matchesGoldenFile('goldens/$name.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  const frame = Size(390, 844);

  _goldenTest('waiting for the driver, 1:42 left', 'payment_waiting_390', (
    tester,
  ) async {
    final (world, _) = await reserve(tester, size: frame);
    await waitFor(tester, world, const Duration(seconds: 18));
  });

  _goldenTest('the driver accepted, 9:58 to pay', 'payment_accepted_390', (
    tester,
  ) async {
    final (world, booking) = await reserve(tester, size: frame);
    await waitFor(tester, world, const Duration(seconds: 20));
    world.backend.acceptBooking(booking.id);
    await nextPoll(tester, world);
    await waitFor(tester, world, const Duration(seconds: 2));
  });

  _goldenTest('moved to another vehicle', 'payment_moved_390', (tester) async {
    final (world, booking) = await reserve(tester, size: frame);
    await letDeadlinePass(tester, world, booking);
  });

  _goldenTest('no driver accepted', 'payment_not_accepted_390', (tester) async {
    final (world, booking) = await reserve(tester, size: frame);
    await waitFor(tester, world, const Duration(seconds: 30));
    world.backend.declineBooking(booking.id, move: false);
    await nextPoll(tester, world);
  });

  _goldenTest('waiting, on the TECNO BG6 (360 x 806)', 'payment_waiting_360', (
    tester,
  ) async {
    await reserve(tester, seats: ['4', '5']);
  });
}
