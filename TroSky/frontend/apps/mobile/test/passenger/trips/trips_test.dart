import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';
import 'package:mobile/passenger/search/presentation/search_screen.dart';
import 'package:mobile/passenger/trips/presentation/booking_details_screen.dart';
import 'package:mobile/passenger/trips/presentation/trips_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../entry/auth/auth_helpers.dart';
import '../../helpers/fakes.dart';
import 'trips_helpers.dart';

/// Trip History (P-15) and Booking details with cancel (P-16), in mock
/// mode on Ama Mensah's week of bookings.
void main() {
  /// The routes of the rows on the current tab, top to bottom.
  List<String> routes(WidgetTester tester) => [
    for (final r in tester.widgetList<TroskyBookingRow>(
      find.byType(TroskyBookingRow),
    ))
      r.route,
  ];

  TroskyBookingRow rowOf(WidgetTester tester, String from, String to) =>
      tester.widget<TroskyBookingRow>(row(from, to));

  group('Trip History (P-15)', () {
    testWidgets('Upcoming: open bookings, soonest first; the month card', (
      tester,
    ) async {
      await openTrips(tester);
      expect(routes(tester), [
        'Achimota → Lapaz',
        'Madina → Circle',
        'Legon → Osu',
        'Circle → Tema',
      ]);
      final paid = rowOf(tester, 'Madina', 'Circle');
      expect(
        (paid.when, paid.price, paid.status, paid.struck),
        ('Tomorrow, 07:15', '₵17.00', 'Paid · Upcoming', false),
      );
      expect(rowOf(tester, 'Achimota', 'Lapaz').status, 'Paid · On the way');
      expect(rowOf(tester, 'Legon', 'Osu').status, 'Waiting for driver');
      expect(rowOf(tester, 'Circle', 'Tema').status, 'Pending payment');
      // Paid this month: TS-8KQ2, TS-C2MX and three completed trips.
      final card = tester.widget<TroskySpendingSummaryCard>(
        find.byType(TroskySpendingSummaryCard),
      );
      expect(card.amount, '₵53.00');
      expect(card.stats, [
        ('5', 'Trips'),
        ('₵10.60', 'Avg Fare'),
        ('₵27.50', 'Saved'),
      ]);
    });

    testWidgets('Past: ended bookings, newest first; cancelled ones struck', (
      tester,
    ) async {
      await openTrips(tester);
      await showPast(tester);
      final seen = <String>{...routes(tester)};
      await tester.scrollUntilVisible(
        row('Lapaz', 'Madina'),
        200,
        scrollable: find.descendant(
          of: find.byType(TripsScreen),
          matching: find.byType(Scrollable),
        ),
      );
      seen.addAll(routes(tester));
      expect(seen, {
        'Osu → Circle',
        'Circle → Tema',
        'Accra Central → Kaneshie',
        'Madina → Circle',
        'Tema → Circle',
        'Kaneshie → Lapaz',
        'Lapaz → Madina',
      });
      final completed = rowOf(tester, 'Circle', 'Tema');
      expect(
        (completed.when, completed.status, completed.tone, completed.struck),
        ('Yesterday, 17:15', 'Completed', TroskyTagTone.green, false),
      );
      final cancelled = rowOf(tester, 'Tema', 'Circle');
      expect(
        (cancelled.status, cancelled.tone, cancelled.struck),
        ('Cancelled', TroskyTagTone.red, true),
      );
      expect(rowOf(tester, 'Accra Central', 'Kaneshie').when, 'Tue, 07:45');
      expect(rowOf(tester, 'Kaneshie', 'Lapaz').status, 'Cancelled');
      final expired = rowOf(tester, 'Lapaz', 'Madina');
      expect((expired.status, expired.struck), ('Expired', true));
    });

    testWidgets('a passenger with no bookings: each tab says so; Find a ride', (
      tester,
    ) async {
      await openTrips(tester, world: TestWorld()..now = DateTime(2026, 10, 15));
      expect(
        find.text('No upcoming trips. Book a seat and it shows up here.'),
        findsOneWidget,
      );
      await showPast(tester);
      expect(find.text('No past trips yet.'), findsOneWidget);
      expect(find.byType(TroskyBookingRow), findsNothing);
      await tester.tap(find.text('Find a ride'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('loading: skeleton rows; a failure: the reason and Retry', (
      tester,
    ) async {
      final world = withHistory();
      final bookings = ScriptedBookings(world)
        ..listFailures.add(const NetworkFailure());
      await openTrips(tester, world: world, overrides: [bookings.provider]);
      expect(find.byType(TroskyBookingRow), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(TroskyBookingRowSkeleton), findsNWidgets(3));
      await tester.pumpAndSettle();
      expect(find.byType(TroskyBookingRow), findsNWidgets(4));
    });

    testWidgets('20 a page: the next one loads near the end of the list', (
      tester,
    ) async {
      final world = withHistory();
      final token = world.backend
          .login(
            LoginRequest(
              identifier: '0241234567',
              password: MockBackend.seedPassword,
            ),
          )
          .valueOrNull!
          .accessToken;
      final done = world.backend
          .listBookings(token, statuses: [BookingStatus.completed])
          .valueOrNull!
          .items
          .first;
      final bookings = ScriptedBookings(world)
        ..served = [
          for (var i = 0; i < 25; i++)
            done.copyWith(id: 'b$i', bookingReference: 'TS-P${i + 10}'),
        ];
      await openTrips(tester, world: world, overrides: [bookings.provider]);
      expect(bookings.offsets, [0]);
      await tester.drag(
        find.descendant(
          of: find.byType(TripsScreen),
          matching: find.byType(Scrollable),
        ),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(bookings.offsets, [0, 20]);
      await tester.drag(
        find.descendant(
          of: find.byType(TripsScreen),
          matching: find.byType(Scrollable),
        ),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      // All 25 are in: no third request.
      expect(bookings.offsets, [0, 20]);
    });

    testWidgets('pull to refresh reads the tab and the card again', (
      tester,
    ) async {
      final world = withHistory();
      final bookings = ScriptedBookings(world);
      await openTrips(tester, world: world, overrides: [bookings.provider]);
      await tester.fling(
        find.descendant(
          of: find.byType(TripsScreen),
          matching: find.byType(Scrollable),
        ),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(bookings.offsets, [0, 0]);
    });

    testWidgets('no overflow at 360 x 640 and text scale 1.3', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openTrips(tester, size: const Size(360, 640));
      await showPast(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Booking details (P-16)', () {
    testWidgets('paid, upcoming: trip, vehicle, driver, seats, fare', (
      tester,
    ) async {
      await openTrips(tester);
      await openBooking(tester, 'Madina', 'Circle');
      expect(headerChip(tester), 'Paid · Upcoming');
      expect(find.text('TS-8KQ2'), findsOneWidget);
      expect(find.text('FRI 16 OCT'), findsOneWidget);
      expect(find.text('About 40 min'), findsOneWidget);
      expect(find.text('07:15'), findsOneWidget);
      expect(find.text('~07:55'), findsOneWidget);
      expect(find.text('GR 1234-24'), findsOneWidget);
      expect(find.text('Toyota Hiace'), findsOneWidget);
      expect(find.textContaining('★ 4.'), findsOneWidget);
      expect(find.text('3 & 4'), findsOneWidget);
      expect(find.text('2 passengers'), findsOneWidget);
      expect(find.text('2 × ₵8.00'), findsOneWidget);
      expect(find.text('₵16.00'), findsOneWidget);
      expect(find.text('Service fee'), findsOneWidget);
      expect(find.text('₵1.00'), findsOneWidget);
      expect(find.text('₵17.00'), findsOneWidget);
      // Only cancelling: the ticket and tracking aren't built.
      expect(find.byType(TroskyButton), findsNothing);
      expect(link('Cancel booking'), findsOneWidget);
    });

    testWidgets('every status: its chip, its actions, its refund line', (
      tester,
    ) async {
      await openTrips(tester);
      // (from, to, Past tab, chip, main button, can cancel, refund line)
      const cases = [
        ('Achimota', 'Lapaz', false, 'Paid · On the way', null, true, null),
        (
          'Legon',
          'Osu',
          false,
          'Waiting for driver',
          'View status',
          false,
          null,
        ),
        ('Circle', 'Tema', false, 'Pending payment', 'Pay now', true, null),
        (
          'Osu',
          'Circle',
          true,
          'Cancelled',
          null,
          false,
          'Refund of ₵7.50 requested',
        ),
        ('Circle', 'Tema', true, 'Completed', null, false, null),
        ('Tema', 'Circle', true, 'Cancelled', null, false, null),
        ('Kaneshie', 'Lapaz', true, 'Cancelled', null, false, '₵5.50 refunded'),
        ('Lapaz', 'Madina', true, 'Expired', null, false, null),
      ];
      var onPast = false;
      for (final (from, to, past, chip, button, cancel, refund) in cases) {
        if (past && !onPast) {
          await showPast(tester);
          onPast = true;
        }
        await openBooking(tester, from, to);
        expect(headerChip(tester), chip, reason: '$from → $to');
        expect(
          find.byType(TroskyButton),
          button == null ? findsNothing : findsOneWidget,
          reason: '$from → $to',
        );
        if (button != null) expect(find.text(button), findsOneWidget);
        expect(
          link('Cancel booking'),
          cancel ? findsOneWidget : findsNothing,
          reason: '$from → $to',
        );
        if (refund != null) {
          expect(
            tester.widget<TroskyRefundNote>(find.byType(TroskyRefundNote)).text,
            refund,
          );
        } else {
          expect(find.byType(TroskyRefundNote), findsNothing);
        }
        await back(tester);
      }
    });

    testWidgets('Pay now and View status open Payment; back comes here', (
      tester,
    ) async {
      await openTrips(tester);
      await openBooking(tester, 'Circle', 'Tema');
      await tester.tap(find.text('Pay now'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.textContaining('Pay within'), findsOneWidget);
      await back(tester);
      expect(find.byType(BookingDetailsScreen), findsOneWidget);
      await back(tester);

      await openBooking(tester, 'Legon', 'Osu');
      await tester.tap(find.text('View status'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text('Waiting for the driver to accept'), findsOneWidget);
    });

    testWidgets('the reference copies', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openTrips(tester);
      await openBooking(tester, 'Madina', 'Circle');
      await tester.tap(find.bySemanticsLabel('Copy booking reference'));
      await tester.pump();
      expect(copied, 'TS-8KQ2');
      expect(find.text('Booking reference copied'), findsOneWidget);
    });

    testWidgets('no overflow at 360 x 640 and text scale 1.3', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openTrips(tester, size: const Size(360, 640));
      await openBooking(tester, 'Madina', 'Circle');
      expect(tester.takeException(), isNull);
      await tester.tap(link('Cancel booking'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Cancel (P-16)', () {
    Finder confirm() => find.widgetWithText(TroskyButton, 'Cancel booking');

    testWidgets(
      'paid: a reason, the refund, then cancelled; it moves to Past',
      (tester) async {
        final world = withHistory();
        final bookings = ScriptedBookings(world);
        await openTrips(tester, world: world, overrides: [bookings.provider]);
        await openBooking(tester, 'Madina', 'Circle');
        await tester.tap(link('Cancel booking'));
        await tester.pumpAndSettle();
        expect(find.text('Cancel this booking?'), findsOneWidget);
        expect(find.text('Refund: ₵17.00'), findsOneWidget);
        await tester.tap(find.text('Found another ride'));
        await tester.pump();
        await tester.tap(confirm());
        await tester.pumpAndSettle();

        expect(bookings.cancels.single.$2, 'Found another ride');
        expect(find.text('Booking cancelled'), findsOneWidget);
        expect(find.text('Your seats have been released.'), findsOneWidget);
        expect(
          tester.widget<TroskyRefundNote>(find.byType(TroskyRefundNote)).text,
          'Refund of ₵17.00 requested',
        );
        await tester.tap(find.text('Back to trips'));
        await tester.pumpAndSettle();
        expect(find.byType(BookingDetailsScreen), findsNothing);
        expect(row('Madina', 'Circle'), findsNothing);
        await showPast(tester);
        // Next to the completed Madina → Circle of three days ago.
        expect([
          for (final r in tester.widgetList<TroskyBookingRow>(
            row('Madina', 'Circle'),
          ))
            (r.when, r.status),
        ], contains(('Tomorrow, 07:15', 'Cancelled')));
      },
    );

    testWidgets('not paid: "Other" with a note; no refund; cancelled', (
      tester,
    ) async {
      final world = withHistory();
      final bookings = ScriptedBookings(world);
      await openTrips(tester, world: world, overrides: [bookings.provider]);
      await openBooking(tester, 'Circle', 'Tema');
      await tester.tap(link('Cancel booking'));
      await tester.pumpAndSettle();
      expect(find.byType(TroskyRefundBox), findsNothing);
      await tester.enterText(find.byType(TextField), 'Rain in Circle');
      await tester.pump();
      expect(
        tester
            .widget<TroskyRadioOption>(
              find.widgetWithText(TroskyRadioOption, 'Other'),
            )
            .selected,
        isTrue,
      );
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(bookings.cancels.single.$2, 'Rain in Circle');
      expect(find.text('Booking cancelled'), findsOneWidget);
      expect(find.byType(TroskyRefundNote), findsNothing);
    });

    testWidgets('the trip is under way: TroSky reviews it, nothing changes', (
      tester,
    ) async {
      await openTrips(tester);
      await openBooking(tester, 'Achimota', 'Lapaz');
      await tester.tap(link('Cancel booking'));
      await tester.pumpAndSettle();
      expect(find.text('Your trip has started'), findsOneWidget);
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(find.text('Cancellation requested'), findsOneWidget);
      await tester.tap(find.text('Back to trips'));
      await tester.pumpAndSettle();
      expect(rowOf(tester, 'Achimota', 'Lapaz').status, 'Paid · On the way');
    });

    testWidgets('a failure stays in the sheet; Keep booking closes it', (
      tester,
    ) async {
      final world = withHistory();
      final bookings = ScriptedBookings(world)
        ..cancelFailures.add(const NetworkFailure());
      await openTrips(tester, world: world, overrides: [bookings.provider]);
      await openBooking(tester, 'Madina', 'Circle');
      await tester.tap(link('Cancel booking'));
      await tester.pumpAndSettle();
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(find.text('Cancel this booking?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.style?.color == TroskyColors.red &&
                (w.data ?? '').isNotEmpty,
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep booking'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this booking?'), findsNothing);
      expect(headerChip(tester), 'Paid · Upcoming');
    });
  });
}
