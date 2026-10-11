@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';
import 'package:mobile/passenger/seats/presentation/seat_selection_screen.dart';

import '../search/search_helpers.dart';
import 'seat_helpers.dart';

/// Seat Selection (P-05) and the Payment placeholder in mock mode at 09:00.
/// Emoji have no font in tests.
Future<void> _golden(WidgetTester tester, Type screen, String name) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
  debugDisableShadows = false;
  try {
    await expectLater(
      find.byType(screen),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('P-05 at the design frame, 390 x 844: seat 4 chosen, as P7', (
    tester,
  ) async {
    await openSeats(tester, world: morning(), size: const Size(390, 844));
    await tapSeat(tester, '4');
    await _golden(tester, SeatSelectionScreen, 'seat_selection_390');
  });

  testWidgets('P-05 on the TECNO BG6, 360 x 806: a group of two', (
    tester,
  ) async {
    await openSeats(tester, world: morning());
    await tapSeat(tester, '4');
    await tapSeat(tester, '5');
    await _golden(tester, SeatSelectionScreen, 'seat_selection_group_360');
  });

  testWidgets('P-05, the 10:15 bus: an aisle column and a full back bench', (
    tester,
  ) async {
    await openSeats(tester, world: morning(), departs: '10:15');
    await _golden(tester, SeatSelectionScreen, 'seat_selection_bus_360');
  });

  testWidgets('P-07 Payment placeholder, 360 x 806', (tester) async {
    await openSeats(tester, world: morning());
    await tapSeat(tester, '4');
    await tapSeat(tester, '5');
    await tapReserve(tester);
    await _golden(tester, PaymentScreen, 'payment_360');
  });

  testWidgets('P-05 live: the fare quote for two seats', (tester) async {
    await openLiveSeats(tester, morning(), p7Seats(taken: {'2', '6'}));
    await tapSeat(tester, '4');
    await tapSeat(tester, '5');
    await _golden(tester, SeatSelectionScreen, 'seat_selection_live_360');
  });
}
