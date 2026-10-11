import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';
import 'package:mobile/passenger/home/presentation/home_screen.dart';
import 'package:mobile/passenger/search/presentation/search_results_screen.dart';
import 'package:mobile/passenger/seats/presentation/seat_selection_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';
import '../home/home_helpers.dart';
import '../search/search_helpers.dart';
import 'seat_helpers.dart';

/// P7's minibus with seat 4 (and [more]) reserved: Payment.
Future<(TestWorld, BookingResponse)> _reserved(
  WidgetTester tester, {
  List<String> more = const [],
  Size size = const Size(360, 806),
}) async {
  final world = morning();
  await openSeats(tester, world: world, size: size);
  for (final number in ['4', ...more]) {
    await tapSeat(tester, number);
  }
  await tapReserve(tester);
  expect(find.byType(PaymentScreen), findsOneWidget);
  return (world, _booking(tester));
}

BookingResponse _booking(WidgetTester tester) =>
    tester.widget<PaymentScreen>(find.byType(PaymentScreen)).args.booking;

Text _countdown(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining('Seats held for'));

/// The app closed and started again on the same phone and backend.
Future<void> _restart(WidgetTester tester, TestWorld world) async {
  await tester.pumpWidget(const SizedBox());
  await openHome(tester, world: world);
  await tester.pumpAndSettle();
}

void main() {
  group('the hold', () {
    testWidgets('counts down to expires_at, red in the last minute', (
      tester,
    ) async {
      final (world, _) = await _reserved(tester);
      expect(_countdown(tester).data, 'Seats held for 10:00');
      expect(_countdown(tester).style?.color, TroskyColors.green);

      world.now = world.now.add(const Duration(minutes: 4, seconds: 15));
      await tester.pump(const Duration(seconds: 1));
      expect(_countdown(tester).data, 'Seats held for 05:45');

      world.now = world.now.add(const Duration(minutes: 5, seconds: 15));
      await tester.pump(const Duration(seconds: 1));
      expect(_countdown(tester).data, 'Seats held for 00:30');
      expect(_countdown(tester).style?.color, TroskyColors.red);
    });

    testWidgets('at zero: expired, back to the seat map to choose again', (
      tester,
    ) async {
      final (world, booking) = await _reserved(tester, more: ['5']);
      // The seat map underneath doesn't refresh meanwhile, so nothing is
      // "just taken" over Payment.
      await nextRefresh(tester, world);
      expect(find.byType(SnackBar), findsNothing);

      world.now = booking.expiresAt!;
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
      expect(reserveButton(tester).label, 'Select Seats to Continue');
    });
  });

  testWidgets('Cancel booking: the seats are released, back to the results', (
    tester,
  ) async {
    final (world, booking) = await _reserved(tester);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    expect(world.backend.bookingStatus(booking.id), BookingStatus.cancelled);
    expect(find.byType(PaymentScreen), findsNothing);
    expect(find.byType(SeatSelectionScreen), findsNothing);
    expect(find.byType(SearchResultsScreen), findsOneWidget);
    expect(
      snackBarText(tester),
      'Booking cancelled. Your seats are free again.',
    );
  });

  testWidgets('Cancel booking after the server expired it: expired', (
    tester,
  ) async {
    final (world, booking) = await _reserved(tester);
    // The hold lapsed on the server a moment before the phone's clock.
    world.backend.bookingStatus(booking.id);
    world.now = booking.expiresAt!;
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.byType(SeatSelectionScreen), findsOneWidget);
    expect(
      snackBarText(tester),
      'Your seat hold has expired. Choose your seats again.',
    );
  });

  testWidgets('Back asks first: keep the seats, or release them and choose '
      'again', (tester) async {
    final (world, booking) = await _reserved(tester, more: ['5']);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Change your seats?'), findsOneWidget);
    await tester.tap(find.text('Keep these seats'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(world.backend.bookingStatus(booking.id), BookingStatus.pending);

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
    expect(reserveButton(tester).label, 'Reserve 2 Seats · ₵28.00');
  });

  group('a held booking after the app restarts', () {
    testWidgets('Home reopens it, once', (tester) async {
      final (world, booking) = await _reserved(tester, more: ['1']);
      world.now = world.now.add(const Duration(minutes: 3));

      await _restart(tester, world);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(_booking(tester).id, booking.id);
      expect(_countdown(tester).data, 'Seats held for 07:00');
      // The seat numbers come from the seat map.
      expect(find.text('1, 4'), findsOneWidget);

      // Back leaves it held, and Home doesn't reopen it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(world.backend.bookingStatus(booking.id), BookingStatus.pending);
    });

    testWidgets('one that expired while closed is not reopened', (
      tester,
    ) async {
      final (world, booking) = await _reserved(tester);
      world.now = booking.expiresAt!.add(const Duration(seconds: 1));
      await _restart(tester, world);
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('reopened, then expired: back on Home', (tester) async {
      final (world, booking) = await _reserved(tester);
      await _restart(tester, world);
      world.now = booking.expiresAt!;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(snackBarText(tester), 'Your seat hold has expired.');
    });

    testWidgets('reopened, then cancelled: back on Home', (tester) async {
      final (world, booking) = await _reserved(tester);
      await _restart(tester, world);
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(world.backend.bookingStatus(booking.id), BookingStatus.cancelled);
    });
  });

  testWidgets('360 x 640 at text scale 1.3: no overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _reserved(tester, more: ['1', '5'], size: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });
}
