import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/shared/cancel_booking_sheet.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../booking/payment_helpers.dart';
import '../trips/trips_helpers.dart';

/// Every passenger-initiated cancel opens the same shared sheet widget
/// (public `CancelBookingSheet` with key `cancel-booking-sheet`), so a
/// change to the P-16 design lands everywhere at once. Covers the three
/// entry points named in the owner spec:
///   - Booking details → Cancel booking
///   - Payment screen → bottom Cancel / Cancel request button
///   - Payment screen → Back → Leave sheet → Release seats
void main() {
  const sharedKey = Key('cancel-booking-sheet');
  Finder sharedSheet() => find.byKey(sharedKey);

  testWidgets('Booking Details → Cancel booking opens the shared sheet', (
    tester,
  ) async {
    final world = withHistory();
    await openTrips(tester, world: world);
    await openBooking(tester, 'Madina', 'Circle');
    await tester.tap(find.widgetWithText(TroskyTextLink, 'Cancel booking'));
    await tester.pumpAndSettle();
    expect(sharedSheet(), findsOneWidget);
    expect(tester.widget(sharedSheet()), isA<CancelBookingSheet>());
  });

  testWidgets(
    'Payment screen → bottom Cancel request opens the shared sheet',
    (tester) async {
      await reserve(tester);
      await tester.ensureVisible(find.text('Cancel request'));
      await tester.tap(find.text('Cancel request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sharedSheet(), findsOneWidget);
      expect(tester.widget(sharedSheet()), isA<CancelBookingSheet>());
    },
  );

  testWidgets(
    'Payment screen → Back → Release seats opens the shared sheet',
    (tester) async {
      await reserve(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave payment?'), findsOneWidget);
      await tester.tap(find.text('Release seats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sharedSheet(), findsOneWidget);
      expect(tester.widget(sharedSheet()), isA<CancelBookingSheet>());
      // Unpaid booking: the refund banner is hidden.
      expect(find.byType(TroskyRefundBox), findsNothing);
    },
  );

  testWidgets('Booking Details cancel sheet with an unpaid booking hides '
      'the refund banner', (tester) async {
    // TS-Q7RD on withHistory() is pending (unpaid).
    final world = withHistory();
    await openTrips(tester, world: world);
    await openBooking(tester, 'Circle', 'Tema');
    await tester.tap(find.widgetWithText(TroskyTextLink, 'Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.byType(TroskyRefundBox), findsNothing);
  });
}
