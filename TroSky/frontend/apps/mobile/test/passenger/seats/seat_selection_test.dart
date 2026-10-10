import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/auth/presentation/verify_code_screen.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';
import 'package:mobile/passenger/home/data/location_service.dart';
import 'package:mobile/passenger/search/presentation/search_results_screen.dart';
import 'package:mobile/passenger/seats/presentation/seat_selection_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../home/home_helpers.dart';
import '../search/search_helpers.dart';
import 'seat_helpers.dart';

/// The id `GET /trips/{id}/seats` gave the seat numbered [number].
String _seatId(WidgetTester tester, String number) =>
    (tester.widget<TroskySeat>(seat(number)).key! as ValueKey<String>).value;

(int, int) _counter(WidgetTester tester) {
  final counter = tester.widget<TroskyBookedCounter>(
    find.byType(TroskyBookedCounter),
  );
  return (counter.booked, counter.total);
}

String _price(WidgetTester tester) =>
    tester.widget<TroskyPriceFlash>(find.byType(TroskyPriceFlash)).value;

Rect _rect(WidgetTester tester, String number) => tester.getRect(seat(number));

void main() {
  group('P7 in mock mode', () {
    testWidgets('header, booked counter, legend, the map and the fare panel', (
      tester,
    ) async {
      await openSeats(tester, world: morning());

      expect(find.text('Choose Your Seat'), findsOneWidget);
      expect(
        find.text('Madina → Circle · GR-4821 · Departs 09:03'),
        findsOneWidget,
      );
      expect(_counter(tester), (5, 14));
      expect(find.textContaining(RegExp(r'^5.?/14 booked$')), findsOneWidget);
      for (final label in ['Available', 'Taken', 'Selected']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('GR-4821'), findsOneWidget);
      expect(
        [for (var i = 1; i <= 14; i++) seatState(tester, '$i')],
        [
          for (var i = 1; i <= 14; i++)
            const {2, 6, 9, 11, 12}.contains(i)
                ? TroskySeatState.taken
                : TroskySeatState.available,
        ],
      );
      // Decision 24, mock: the live shared fare, the solo fare crossed out
      // and where it can drop to.
      expect(find.text('You pay now'), findsOneWidget);
      expect(_price(tester), '₵14.00');
      expect(find.text('₵38.00'), findsOneWidget);
      expect(find.text('↓ Drops to ₵6.00'), findsOneWidget);
      expect(find.text('as more riders join'), findsOneWidget);
      expect(find.text('Estimated'), findsNothing);
      expect(reserveButton(tester).label, 'Select Seats to Continue');
      expect(reserveButton(tester).onPressed, isNull);
    });

    testWidgets('select and deselect: the strip, the price and the button', (
      tester,
    ) async {
      await openSeats(tester, world: morning());

      await tapSeat(tester, '4');
      expect(seatState(tester, '4'), TroskySeatState.selected);
      expect(find.text('1 seat selected'), findsOneWidget);
      expect(find.text('Seats: 4'), findsOneWidget);
      expect(reserveButton(tester).label, 'Reserve Seat 4');

      await tapSeat(tester, '1');
      expect(find.text('2 seats selected (group booking)'), findsOneWidget);
      expect(find.text('Seats: 1, 4'), findsOneWidget);
      expect(find.text('₵14.00 × 2 seats'), findsOneWidget);
      expect(_price(tester), '₵28.00');
      expect(find.text('₵76.00'), findsOneWidget);
      expect(reserveButton(tester).label, 'Reserve 2 Seats · ₵28.00');

      await tapSeat(tester, '4');
      expect(seatState(tester, '4'), TroskySeatState.available);
      expect(reserveButton(tester).label, 'Reserve Seat 1');

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(seatState(tester, '1'), TroskySeatState.available);
      expect(find.text('1 seat selected'), findsNothing);
      expect(reserveButton(tester).label, 'Select Seats to Continue');
      expect(reserveButton(tester).onPressed, isNull);
    });

    testWidgets('taken seats cannot be chosen', (tester) async {
      await openSeats(tester, world: morning());
      expect(tester.widget<TroskySeat>(seat('2')).onPressed, isNull);
      await tester.tap(seat('2'));
      await tester.pumpAndSettle();
      expect(seatState(tester, '2'), TroskySeatState.taken);
      expect(reserveButton(tester).label, 'Select Seats to Continue');
    });

    testWidgets('at most 10 seats in one booking', (tester) async {
      // The 10:15 bus: seats 1 to 3 taken, 4 to 21 free, ₵10.00 a seat.
      await openSeats(tester, world: morning(), departs: '10:15');
      for (var i = 4; i <= 13; i++) {
        await tapSeat(tester, '$i');
      }
      expect(reserveButton(tester).label, 'Reserve 10 Seats · ₵100.00');

      await tapSeat(tester, '14');
      expect(seatState(tester, '14'), TroskySeatState.available);
      expect(snackBarText(tester), 'You can book up to 10 seats at once.');
      expect(reserveButton(tester).label, 'Reserve 10 Seats · ₵100.00');
    });

    testWidgets('every 10 s the map refreshes: a chosen seat someone takes is '
        'unchosen, and the fare drops with a flash', (tester) async {
      final world = morning();
      await openSeats(tester, world: world);
      await tapSeat(tester, '7');
      await tapSeat(tester, '4');
      expect(_price(tester), '₵28.00');

      // Nothing before the 10 s are up.
      await tester.pump(const Duration(seconds: 9));
      expect(seatState(tester, '7'), TroskySeatState.selected);

      // The next rider in the mock takes seat 7. (The flash itself is
      // tested in trosky_ui; these tests run without animations.)
      world.now = world.now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(seatState(tester, '7'), TroskySeatState.taken);
      expect(seatState(tester, '4'), TroskySeatState.selected);
      expect(
        snackBarText(tester),
        'Seat 7 was just taken. Choose another seat.',
      );
      expect(_counter(tester), (6, 14));
      expect(reserveButton(tester).label, 'Reserve Seat 4');
      expect(_price(tester), '₵7.33');
    });
  });

  group('reserving', () {
    testWidgets('the booking request (decision 23), then Payment with the '
        'hold', (tester) async {
      final world = morning();
      final bookings = RecordingBookings();
      await openSeats(
        tester,
        world: world,
        overrides: [bookings.providerFor(world)],
      );
      final tripId = openTripId(tester);
      final seat1 = _seatId(tester, '1');
      final seat4 = _seatId(tester, '4');
      await tapSeat(tester, '4');
      await tapSeat(tester, '1');
      await tapReserve(tester);

      final (request, key) = bookings.created.single;
      expect(request.tripId, tripId);
      expect(request.originStopId, MockBackend.stops['Madina']!.id);
      expect(request.destinationStopId, MockBackend.stops['Circle']!.id);
      expect((request.pickupLatitude, request.pickupLongitude), (null, null));
      expect(
        [
          for (final p in request.passengers)
            (p.seatId, p.fullName, p.phoneNumber),
        ],
        [
          (seat1, 'Ama Mensah', '+233241234567'),
          (seat4, "Ama's guest 2", null),
        ],
      );
      expect(key, matches(RegExp(r'^[0-9a-f-]{36}$')));

      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text('Seats held for 10:00'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Booking TS-')), findsOneWidget);
      expect(find.text('Madina → Circle · GR-4821'), findsOneWidget);
      expect(find.text('1, 4'), findsOneWidget);
      expect(find.text('₵28.00'), findsOneWidget);
      expect(find.text('₵1.00'), findsOneWidget);
      expect(find.text('₵29.00'), findsOneWidget);
      final booking = tester
          .widget<PaymentScreen>(find.byType(PaymentScreen))
          .args
          .booking;
      expect(world.backend.bookingStatus(booking.id), BookingStatus.pending);
    });

    testWidgets("a search from the phone's position sends it, not a stop", (
      tester,
    ) async {
      final world = morning();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = nearMadina;
      final bookings = RecordingBookings();
      await openSearch(
        tester,
        world: world,
        overrides: [bookings.providerFor(world)],
      );
      await typeStop(tester, 'to', 'Circle');
      await chooseStop(tester, 'Circle');
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      await openTrip(tester, '09:03');
      await tapSeat(tester, '4');
      await tapReserve(tester);

      final (request, _) = bookings.created.single;
      expect(request.originStopId, isNull);
      expect(
        (request.pickupLatitude, request.pickupLongitude),
        (nearMadina.latitude, nearMadina.longitude),
      );
      expect(find.byType(PaymentScreen), findsOneWidget);
    });

    testWidgets('SEAT_NOT_AVAILABLE: that seat is unchosen, the others stay', (
      tester,
    ) async {
      final world = morning();
      await openSeats(tester, world: world);
      await tapSeat(tester, '4');
      await tapSeat(tester, '5');
      world.backend.takeSeat(openTripId(tester), '4');

      await tapReserve(tester);
      expect(find.byType(SeatSelectionScreen), findsOneWidget);
      expect(find.byType(PaymentScreen), findsNothing);
      expect(
        snackBarText(tester),
        'Seat 4 was just taken. Choose another seat.',
      );
      expect(seatState(tester, '4'), TroskySeatState.taken);
      expect(seatState(tester, '5'), TroskySeatState.selected);
      expect(reserveButton(tester).label, 'Reserve Seat 5');

      await tapReserve(tester);
      expect(find.byType(PaymentScreen), findsOneWidget);
    });

    testWidgets('ACCOUNT_NOT_VERIFIED: the code screen, then the booking', (
      tester,
    ) async {
      final world = morning();
      await openSeats(tester, world: world);
      world.backend.markUnverified('0241234567');
      await tapSeat(tester, '4');
      await tapReserve(tester);

      expect(find.byType(VerifyCodeScreen), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(VerifyCodeScreen),
          matching: find.byType(TextField),
        ),
        MockBackend.otpCode,
      );
      await tester.pumpAndSettle();

      // Back on the seats, and reserved without another tap.
      expect(find.byType(VerifyCodeScreen), findsNothing);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('ACCOUNT_NOT_VERIFIED, and the code screen left: no booking', (
      tester,
    ) async {
      final world = morning();
      final bookings = RecordingBookings();
      await openSeats(
        tester,
        world: world,
        overrides: [bookings.providerFor(world)],
      );
      world.backend.markUnverified('0241234567');
      await tapSeat(tester, '4');
      await tapReserve(tester);
      expect(find.byType(VerifyCodeScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SeatSelectionScreen), findsOneWidget);
      expect(seatState(tester, '4'), TroskySeatState.selected);
      expect(bookings.created, hasLength(1));
    });

    testWidgets('TRIP_NOT_BOOKABLE: said, Reserve off, back to the results', (
      tester,
    ) async {
      final world = morning();
      await openSeats(tester, world: world);
      world.backend.closeTrip(openTripId(tester));
      await tapSeat(tester, '4');
      await tapReserve(tester);

      expect(
        find.text('This trip can no longer be booked. Choose another one.'),
        findsOneWidget,
      );
      expect(reserveButton(tester).onPressed, isNull);
      await tester.tap(find.text('Back to results'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchResultsScreen), findsOneWidget);
      expect(find.byType(SeatSelectionScreen), findsNothing);
    });

    for (final (name, failure, message, closed)
        in <(String, AppFailure, String, bool)>[
          (
            'STOP_NOT_ON_ROUTE',
            const ValidationFailure(
              code: 'STOP_NOT_ON_ROUTE',
              message: 'That stop is not on this route.',
              statusCode: 422,
            ),
            'This trip no longer stops where you chose. Choose another one.',
            true,
          ),
          (
            'PICKUP_ALREADY_PASSED',
            const ConflictFailure(
              code: 'PICKUP_ALREADY_PASSED',
              message: 'This vehicle has already passed your pickup.',
              statusCode: 409,
            ),
            'This vehicle has already passed your pickup. Choose another one.',
            true,
          ),
          (
            'another validation error',
            const ValidationFailure(
              code: 'VALIDATION_ERROR',
              message: 'Invalid request.',
              statusCode: 422,
            ),
            'Something went wrong. Try again.',
            false,
          ),
          (
            'the rate limit',
            const RateLimitedFailure(
              code: 'RATE_LIMIT_EXCEEDED',
              message: 'Too many requests.',
              statusCode: 429,
              retryAfter: Duration(seconds: 30),
            ),
            'Too many tries. Wait 30 s and try again.',
            false,
          ),
          (
            'offline',
            const NetworkFailure(),
            'No connection. Check your internet and try again.',
            false,
          ),
        ]) {
      testWidgets('$name: said on the panel, the choice kept', (tester) async {
        final world = morning();
        final bookings = RecordingBookings(failures: [failure]);
        await openSeats(
          tester,
          world: world,
          overrides: [bookings.providerFor(world)],
        );
        await tapSeat(tester, '4');
        await tapReserve(tester);

        expect(find.text(message), findsOneWidget);
        expect(seatState(tester, '4'), TroskySeatState.selected);
        expect(find.byType(PaymentScreen), findsNothing);
        expect(reserveButton(tester).onPressed == null, closed);
        if (!closed) {
          // Trying again works, as one booking.
          await tapReserve(tester);
          expect(find.byType(PaymentScreen), findsOneWidget);
          expect(bookings.created[0].$2, bookings.created[1].$2);
        }
      });
    }

    testWidgets('a new choice is a new booking: a new idempotency key', (
      tester,
    ) async {
      final world = morning();
      final bookings = RecordingBookings(
        failures: const [NetworkFailure(), NetworkFailure()],
      );
      await openSeats(
        tester,
        world: world,
        overrides: [bookings.providerFor(world)],
      );
      await tapSeat(tester, '4');
      await tapReserve(tester);
      await tapReserve(tester);
      await tapSeat(tester, '5');
      await tapReserve(tester);

      final keys = [for (final (_, key) in bookings.created) key];
      expect(keys, hasLength(3));
      expect(keys[1], keys[0]);
      expect(keys[2], isNot(keys[0]));
      expect(find.byType(PaymentScreen), findsOneWidget);
    });
  });

  group('live mode (decision 24)', () {
    testWidgets("the trip's fare × seats, marked Estimated; no solo fare or "
        '"Drops to"', (tester) async {
      await openLiveSeats(tester, morning(), p7Seats(taken: {'2', '6'}));

      expect(
        find.text('Madina → Circle · GT 4402-26 · Departs 09:15'),
        findsOneWidget,
      );
      expect(_counter(tester), (2, 14));
      expect(find.text('You pay now'), findsOneWidget);
      expect(_price(tester), '₵8.00');
      expect(find.text('Estimated'), findsOneWidget);
      expect(find.textContaining('Drops to'), findsNothing);
      expect(find.text('as more riders join'), findsNothing);

      await tapSeat(tester, '4');
      await tapSeat(tester, '5');
      expect(find.text('₵8.00 × 2 seats'), findsOneWidget);
      expect(_price(tester), '₵16.00');
      expect(find.text('₵76.00'), findsNothing);
      expect(reserveButton(tester).label, 'Reserve 2 Seats · ₵16.00');
    });

    testWidgets('no vehicle or seat layout yet: said, with Retry', (
      tester,
    ) async {
      final world = morning();
      final routes = await openLiveSeats(tester, world, p7Seats());
      routes.seatMaps.remove('t1');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      // A failed refresh keeps the map on screen.
      expect(seat('4'), findsOneWidget);

      // Opened afresh: the message.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await openTrip(tester, '09:15');
      expect(
        find.text(
          "This trip has no vehicle yet, so its seats can't be chosen.",
        ),
        findsOneWidget,
      );
      routes.seatMaps['t1'] = seatMap('t1', p7Seats());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(seat('4'), findsOneWidget);
    });
  });

  group('layouts from data (decision 25)', () {
    // Wide enough that nothing is scaled down.
    const wide = Size(600, 1000);

    testWidgets('4 across (P7): 8 px between seats, a 20 px aisle after '
        'column 2, the back bench centred on it', (tester) async {
      await openSeats(tester, world: morning(), size: wide);
      expect(_rect(tester, '1').size, const Size(56, 60));
      expect(_rect(tester, '2').left - _rect(tester, '1').right, 8);
      expect(_rect(tester, '3').left - _rect(tester, '2').right, 8 + 20 + 8);
      expect(_rect(tester, '4').left - _rect(tester, '3').right, 8);
      expect(_rect(tester, '5').top - _rect(tester, '1').bottom, 10);
      // The bench: 4 px further down, centred under the aisle.
      expect(_rect(tester, '13').top - _rect(tester, '9').bottom, 14);
      expect(
        (_rect(tester, '13').left + _rect(tester, '14').right) / 2,
        (_rect(tester, '2').right + _rect(tester, '3').left) / 2,
      );
    });

    testWidgets('3 across: 2 + 1, the aisle after column 2', (tester) async {
      await openLiveSeats(tester, morning(), threeColumnSeats(), size: wide);
      expect(_rect(tester, '2').left - _rect(tester, '1').right, 8);
      expect(_rect(tester, '3').left - _rect(tester, '2').right, 36);
      expect(_rect(tester, '4').left, _rect(tester, '1').left);
    });

    testWidgets('an empty aisle column, and a full back bench across it', (
      tester,
    ) async {
      // The 10:15 bus: 2 + 2 with column 3 empty, then 5 seats at the back.
      await openSeats(tester, world: morning(), size: wide, departs: '10:15');
      // The aisle column is as wide as a seat, so the bench lines up.
      expect(_rect(tester, '3').left - _rect(tester, '2').right, 8 + 56 + 8);
      expect(
        _rect(tester, '19').center.dx,
        (_rect(tester, '2').right + _rect(tester, '3').left) / 2,
      );
      expect(_rect(tester, '17').left, _rect(tester, '1').left);
      expect(_rect(tester, '21').right, _rect(tester, '4').right);
    });

    testWidgets('a wide vehicle shrinks to fit a narrow phone', (tester) async {
      await openSeats(tester, world: morning(), departs: '10:15');
      expect(tester.takeException(), isNull);
      final left = _rect(tester, '17').left;
      final right = _rect(tester, '21').right;
      expect(right - left, lessThan(5 * 56 + 4 * 8));
      expect(left, greaterThanOrEqualTo(0));
      expect(right, lessThanOrEqualTo(360));
    });
  });

  group('layout and screen readers', () {
    testWidgets('360 x 640 at text scale 1.3: no overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openSeats(tester, world: morning(), size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      await tapSeat(tester, '4');
      await tapSeat(tester, '5');
      expect(tester.takeException(), isNull);
      await tapReserve(tester);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Change your seats?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360 x 640 at text scale 1.3, live: no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openLiveSeats(
        tester,
        morning(),
        p7Seats(),
        size: const Size(360, 640),
      );
      await tapSeat(tester, '4');
      await tapSeat(tester, '5');
      expect(tester.takeException(), isNull);
    });

    testWidgets('seats say their number and state; the counter its count', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openSeats(tester, world: morning());
      await tapSeat(tester, '4');
      expect(find.bySemanticsLabel('Seat 4, selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Seat 2, taken'), findsOneWidget);
      expect(find.bySemanticsLabel('Seat 1'), findsOneWidget);
      expect(find.bySemanticsLabel('5 of 14 seats booked'), findsOneWidget);
      semantics.dispose();
    });
  });
}
