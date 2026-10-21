import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/booking/application/booking_watch.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';
import 'package:mobile/passenger/home/presentation/home_screen.dart';
import 'package:mobile/passenger/search/presentation/search_results_screen.dart';
import 'package:mobile/passenger/search/presentation/search_screen.dart';
import 'package:mobile/passenger/seats/presentation/seat_selection_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';
import '../home/home_helpers.dart';
import '../search/search_helpers.dart';
import '../seats/seat_helpers.dart';
import 'payment_helpers.dart';

/// The app closed and started again on the same phone and backend.
Future<void> _restart(WidgetTester tester, TestWorld world) async {
  await tester.pumpWidget(const SizedBox());
  await openHome(tester, world: world);
  await tester.pumpAndSettle();
}

/// The phone puts the app in the background, or brings it back.
Future<void> _background(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

Future<void> _foreground(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// The trip card's facts, label then value.
void _expectFacts(String vehicle, String seats, String total) {
  for (final text in ['Vehicle', vehicle, 'Seats', seats, 'Total', total]) {
    expect(find.text(text), findsOneWidget, reason: text);
  }
}

void main() {
  group('waiting for the driver', () {
    testWidgets('the trip, and a countdown from expires_at with the '
        '2-minute window', (tester) async {
      final (world, booking) = await reserve(tester);
      expect(booking.status, BookingStatus.awaitingAcceptance);
      expect(stageShown(tester), PaymentStage.waiting);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Review and confirm your booking'), findsOneWidget);
      for (final text in ['Madina', 'Circle', 'Today', '09:03']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      _expectFacts('GR-4821', '3 & 4', '₵29.00');
      expect(find.text('Waiting for the driver to accept'), findsOneWidget);
      expect(
        find.text(
          "Your seats are held. You'll pay only after the driver accepts.",
        ),
        findsOneWidget,
      );
      expect(countdownTime(tester), '2:00');
      expect(find.text('2-minute response window'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);

      await waitFor(tester, world, const Duration(seconds: 18));
      expect(countdownTime(tester), '1:42');
      await waitFor(tester, world, const Duration(seconds: 101));
      expect(countdownTime(tester), '0:01');
      expect(stageShown(tester), PaymentStage.waiting);
    });

    testWidgets('three or more seats: "1, 3 & 4"', (tester) async {
      await reserve(tester, seats: ['1', '3', '4']);
      expect(find.text('1, 3 & 4'), findsOneWidget);
    });

    testWidgets('it asks every 5 s; the answer comes with the next poll, '
        'then the polls stop', (tester) async {
      final world = morning();
      final bookings = PolledBookings(world);
      final (_, booking) = await reserve(
        tester,
        world: world,
        overrides: [bookings.provider],
      );
      expect(bookings.gets, 0);
      await waitFor(tester, world, const Duration(seconds: 4));
      expect(bookings.gets, 0);
      await waitFor(tester, world, const Duration(seconds: 1));
      expect(bookings.gets, 1);
      await waitFor(tester, world, const Duration(seconds: 5));
      expect(bookings.gets, 2);

      world.backend.acceptBooking(booking.id);
      await nextPoll(tester, world);
      expect(bookings.gets, 3);
      expect(stageShown(tester), PaymentStage.accepted);
      await waitFor(tester, world, const Duration(seconds: 30));
      expect(bookings.gets, 3);
    });

    testWidgets('no polls in the background; back in the app it asks at '
        'once', (tester) async {
      final world = morning();
      final bookings = PolledBookings(world);
      final (_, booking) = await reserve(
        tester,
        world: world,
        overrides: [bookings.provider],
      );
      await _background(tester);
      await waitFor(tester, world, const Duration(seconds: 30));
      expect(bookings.gets, 0);

      world.backend.acceptBooking(booking.id);
      await _foreground(tester);
      expect(bookings.gets, 1);
      expect(stageShown(tester), PaymentStage.accepted);
      expect(find.text('Driver accepted your booking'), findsOneWidget);
    });

    testWidgets('offline: a message, and the polls back off to 10, 20 and '
        '30 s; once through, they are every 5 s again', (tester) async {
      final world = morning();
      final bookings = PolledBookings(world)
        ..failures.addAll([offline, offline, offline]);
      await reserve(tester, world: world, overrides: [bookings.provider]);
      const message = "No connection. We'll keep checking.";

      await waitFor(tester, world, bookingPollEvery);
      expect(bookings.gets, 1);
      expect(find.text(message), findsOneWidget);
      var asked = 1;
      for (final gap in const [10, 20, 30]) {
        await waitFor(tester, world, Duration(seconds: gap - 1));
        expect(bookings.gets, asked, reason: 'not before $gap s');
        await waitFor(tester, world, const Duration(seconds: 1));
        expect(bookings.gets, ++asked, reason: 'after $gap s');
      }
      expect(find.text(message), findsNothing);
      expect(stageShown(tester), PaymentStage.waiting);
      await waitFor(tester, world, bookingPollEvery);
      expect(bookings.gets, 5);
    });

    testWidgets('closing Payment stops the polls', (tester) async {
      final world = morning();
      final bookings = PolledBookings(world);
      await reserve(tester, world: world, overrides: [bookings.provider]);
      await waitFor(tester, world, bookingPollEvery);
      expect(bookings.gets, 1);
      await _tap(tester, 'Cancel request');
      expect(find.byType(PaymentScreen), findsNothing);
      await waitFor(tester, world, const Duration(seconds: 30));
      expect(bookings.gets, 1);
    });
  });

  group('the driver accepts', () {
    testWidgets('a banner, and the time to pay from the new expires_at', (
      tester,
    ) async {
      final (world, booking) = await reserve(tester);
      await waitFor(tester, world, const Duration(seconds: 20));
      world.backend.acceptBooking(booking.id);
      await nextPoll(tester, world);

      expect(stageShown(tester), PaymentStage.accepted);
      expect(find.text('Driver accepted your booking'), findsOneWidget);
      expect(find.text('Pay within'), findsOneWidget);
      // Accepted at 20 s, read at 25 s: 10 minutes from the acceptance.
      expect(find.text('9:55'), findsOneWidget);
      expect(
        find.text(
          'Paying in the app is coming soon. Your seats stay held until the '
          'timer ends.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel booking'), findsOneWidget);
      expect(find.text('Waiting for the driver to accept'), findsNothing);
      _expectFacts('GR-4821', '3 & 4', '₵29.00');
    });

    testWidgets('the time to pay runs out: expired, back to the seat map', (
      tester,
    ) async {
      final (world, booking) = await reserve(tester);
      world.backend.acceptBooking(booking.id);
      await nextPoll(tester, world);
      world.now = world.now.add(MockBackend.seatHold);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(SeatSelectionScreen), findsOneWidget);
      expect(
        snackBarText(tester),
        'Your seat hold has expired. Choose your seats again.',
      );
      expect(world.backend.bookingStatus(booking.id), BookingStatus.expired);
      expect(seatState(tester, '4'), TroskySeatState.available);
    });
  });

  group('moved to another vehicle', () {
    testWidgets('nobody answered: the new vehicle, its time and seats, and a '
        'new countdown', (tester) async {
      final (world, booking) = await reserve(tester);
      await letDeadlinePass(tester, world, booking);

      expect(stageShown(tester), PaymentStage.moved);
      final movedTo = world.backend.bookingTripId(booking.id);
      expect(movedTo, isNot(booking.tripId));
      expect(
        find.text(
          "The driver didn't respond, so we moved you to another vehicle.",
        ),
        findsOneWidget,
      );
      expect(find.text('NEW VEHICLE ASSIGNED'), findsOneWidget);
      final old = tester.widget<Text>(find.text('09:03'));
      expect(old.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('Waiting for the new driver to accept'), findsOneWidget);
      expect(
        find.text(
          'Your seats are held while the new driver reviews your booking.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel booking'), findsOneWidget);
      // A new two minutes, from the old deadline; read 5 s later.
      expect(countdownTime(tester), '1:55');
      expect(find.text('2-minute response window'), findsOneWidget);
      // Not the minibus any more; the price is as booked.
      expect(find.text('GR-4821'), findsNothing);
      expect(find.text('₵29.00'), findsOneWidget);
      final card = tester.widget<TroskyTripSummaryCard>(
        find.byType(TroskyTripSummaryCard),
      );
      expect(card.highlighted, isTrue);
      expect(card.previousTime, '09:03');
      expect(card.time, isNot('09:03'));
      expect(card.facts[1].value, isNot('…'));
    });

    testWidgets('the driver declined: moved at once, and it says so', (
      tester,
    ) async {
      final (world, booking) = await reserve(tester);
      await waitFor(tester, world, const Duration(seconds: 30));
      world.backend.declineBooking(booking.id);
      await nextPoll(tester, world);
      expect(stageShown(tester), PaymentStage.moved);
      expect(
        find.text(
          "The driver couldn't take your booking, so we moved you to another "
          'vehicle.',
        ),
        findsOneWidget,
      );
      expect(countdownTime(tester), '1:55');
    });

    testWidgets('moved, then the new driver accepts', (tester) async {
      final (world, booking) = await reserve(tester);
      await letDeadlinePass(tester, world, booking);
      world.backend.acceptBooking(booking.id);
      await nextPoll(tester, world);
      expect(stageShown(tester), PaymentStage.accepted);
      expect(find.text('Driver accepted your booking'), findsOneWidget);
      expect(find.text('NEW VEHICLE ASSIGNED'), findsNothing);
    });
  });

  group('no driver accepted', () {
    testWidgets('declined, no other vehicle: Search again starts over from '
        'the same stops', (tester) async {
      final (world, booking) = await reserve(tester);
      world.backend.declineBooking(booking.id, move: false);
      await nextPoll(tester, world);

      expect(stageShown(tester), PaymentStage.notAccepted);
      expect(find.text('No driver accepted your booking'), findsOneWidget);
      expect(
        find.text("You haven't been charged. Your seats have been released."),
        findsOneWidget,
      );
      expect(find.text('Cancel request'), findsNothing);
      _expectFacts('GR-4821', '3 & 4', '₵29.00');

      // Search, prefilled with the same stops, searches straight away (as for
      // a favourite route): fresh results from Madina to Circle, over Home.
      await _tap(tester, 'Search again');
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(SearchResultsScreen), findsOneWidget);
      final search = tester
          .widget<SearchResultsScreen>(find.byType(SearchResultsScreen))
          .search;
      expect(search.destination.name, 'Circle');
      while (find.byType(HomeScreen).hitTestable().evaluate().isEmpty) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(find.byType(SearchScreen), findsNothing);
    });

    testWidgets('nobody answered, three moves: not accepted; Back to Home', (
      tester,
    ) async {
      final (world, booking) = await reserve(tester);
      for (var i = 0; i <= MockBackend.bookingMaxMoves; i++) {
        world.now = watchShown(tester).booking.expiresAt!;
        await nextPoll(tester, world);
      }
      expect(world.backend.bookingStatus(booking.id), BookingStatus.expired);
      expect(stageShown(tester), PaymentStage.notAccepted);
      await _tap(tester, 'Back to Home');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PaymentScreen), findsNothing);
    });

    testWidgets('Back leaves without asking: nothing is held', (tester) async {
      final (world, booking) = await reserve(tester);
      world.backend.declineBooking(booking.id, move: false);
      await nextPoll(tester, world);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Change your seats?'), findsNothing);
      expect(find.byType(SeatSelectionScreen), findsOneWidget);
      expect(seatState(tester, '4'), TroskySeatState.available);
    });
  });

  group('cancel', () {
    testWidgets('Cancel request: cancelled on the server, back to the '
        'results', (tester) async {
      final (world, booking) = await reserve(tester);
      await _tap(tester, 'Cancel request');
      expect(world.backend.bookingStatus(booking.id), BookingStatus.cancelled);
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(SeatSelectionScreen), findsNothing);
      expect(find.byType(SearchResultsScreen), findsOneWidget);
      expect(
        snackBarText(tester),
        'Booking cancelled. Your seats are free again.',
      );
    });

    testWidgets('Cancel booking after a move', (tester) async {
      final (world, booking) = await reserve(tester);
      await letDeadlinePass(tester, world, booking);
      await _tap(tester, 'Cancel booking');
      expect(world.backend.bookingStatus(booking.id), BookingStatus.cancelled);
      expect(find.byType(SearchResultsScreen), findsOneWidget);
    });

    testWidgets('Cancel booking once accepted', (tester) async {
      final (world, booking) = await reserve(tester);
      world.backend.acceptBooking(booking.id);
      await nextPoll(tester, world);
      await _tap(tester, 'Cancel booking');
      expect(world.backend.bookingStatus(booking.id), BookingStatus.cancelled);
      expect(find.byType(SearchResultsScreen), findsOneWidget);
    });

    testWidgets('the server ended it first: Payment shows how', (tester) async {
      final world = morning();
      final bookings = PolledBookings(world);
      final (_, booking) = await reserve(
        tester,
        world: world,
        overrides: [bookings.provider],
      );
      world.backend.declineBooking(booking.id, move: false);
      await _tap(tester, 'Cancel request');
      expect(bookings.cancelled, [booking.id]);
      expect(stageShown(tester), PaymentStage.notAccepted);
      expect(find.text('No driver accepted your booking'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('Back asks first: keep the seats, or release them and choose '
      'again', (tester) async {
    final (world, booking) = await reserve(tester, seats: ['4', '5']);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Change your seats?'), findsOneWidget);
    await tester.tap(find.text('Keep these seats'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(
      world.backend.bookingStatus(booking.id),
      BookingStatus.awaitingAcceptance,
    );

    // The back button on the screen asks the same.
    final semantics = tester.ensureSemantics();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    semantics.dispose();
    await tester.tap(find.text('Release seats'));
    await tester.pumpAndSettle();
    expect(world.backend.bookingStatus(booking.id), BookingStatus.cancelled);
    expect(find.byType(SeatSelectionScreen), findsOneWidget);
    expect(snackBarText(tester), 'Seats released. Choose again.');
    // Free again, and still chosen.
    expect(seatState(tester, '4'), TroskySeatState.selected);
    expect(seatState(tester, '5'), TroskySeatState.selected);
  });

  group('after the app restarts', () {
    testWidgets('Home reopens a booking still waiting for the driver, once', (
      tester,
    ) async {
      final (world, booking) = await reserve(tester, seats: ['1', '4']);
      world.now = world.now.add(const Duration(seconds: 30));

      await _restart(tester, world);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(paymentBooking(tester).id, booking.id);
      expect(stageShown(tester), PaymentStage.waiting);
      expect(countdownTime(tester), '1:30');
      // The answer window isn't known for a reopened booking.
      expect(find.textContaining('response window'), findsNothing);
      // The seat numbers come from the seat map.
      expect(find.text('1 & 4'), findsOneWidget);

      // Back leaves it waiting, and Home doesn't reopen it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        world.backend.bookingStatus(booking.id),
        BookingStatus.awaitingAcceptance,
      );
    });

    testWidgets('accepted while closed: ready to pay, without the banner', (
      tester,
    ) async {
      final (world, booking) = await reserve(tester);
      world.backend.acceptBooking(booking.id);
      await _restart(tester, world);
      expect(stageShown(tester), PaymentStage.accepted);
      expect(find.text('Pay within'), findsOneWidget);
      expect(find.text('Driver accepted your booking'), findsNothing);
    });

    testWidgets('ended while closed: not reopened', (tester) async {
      final (world, booking) = await reserve(tester);
      world.backend.declineBooking(booking.id, move: false);
      await _restart(tester, world);
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  testWidgets('360 x 640 at text scale 1.3: no overflow in any state', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (world, booking) = await reserve(
      tester,
      seats: ['1', '3', '4'],
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    await letDeadlinePass(tester, world, booking);
    expect(stageShown(tester), PaymentStage.moved);
    expect(tester.takeException(), isNull);
    world.backend.acceptBooking(booking.id);
    await nextPoll(tester, world);
    expect(stageShown(tester), PaymentStage.accepted);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 x 640 at text scale 1.3: not accepted, no overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (world, booking) = await reserve(tester, size: const Size(360, 640));
    world.backend.declineBooking(booking.id, move: false);
    await nextPoll(tester, world);
    expect(stageShown(tester), PaymentStage.notAccepted);
    expect(tester.takeException(), isNull);
  });
}
