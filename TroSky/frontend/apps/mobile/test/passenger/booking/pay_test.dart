import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/booking/application/pay_controller.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';
import 'package:mobile/passenger/home/presentation/home_screen.dart';
import 'package:mobile/passenger/trips/presentation/trips_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../search/search_helpers.dart';
import '../seats/seat_helpers.dart';
import '../trips/trips_helpers.dart';
import 'payment_helpers.dart';

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pump();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// "Change", then the method called [title] ([detail] tells numbers apart).
Future<void> _choose(
  WidgetTester tester,
  String title, {
  String? detail,
}) async {
  await _tap(tester, 'Change');
  final option = find.byWidgetPredicate(
    (w) =>
        w is TroskyPayMethodOption &&
        w.title == title &&
        (detail == null || w.detail == detail),
  );
  await tester.tap(option);
  await tester.pumpAndSettle();
}

/// "Change", then a new MTN MoMo number.
Future<void> _addNumber(WidgetTester tester, String number) async {
  await _tap(tester, 'Change');
  await _tap(tester, '+ Add an MTN MoMo number');
  await tester.enterText(find.byType(TextField), number);
  await _tap(tester, 'Use this number');
}

TroskyPayWithCard _card(WidgetTester tester) =>
    tester.widget<TroskyPayWithCard>(find.byType(TroskyPayWithCard));

PayFlow _pay(WidgetTester tester) {
  final screen = tester.widget<PaymentScreen>(find.byType(PaymentScreen));
  return container(tester).read(payControllerProvider(screen.args));
}

const String _phone = MockBackend.passengerPhone;

void main() {
  group('the TroSky Wallet', () {
    testWidgets('pays at once: paid, Trips shows it, Home has no card', (
      tester,
    ) async {
      final (world, booking) = await acceptedPayment(tester);
      expect(_card(tester).title, 'TroSky Wallet');
      expect(_card(tester).detail, 'Balance ₵128.50');

      await _tap(tester, 'Pay ₵29.00');
      expect(_pay(tester).stage, PayStage.paid);
      expect(find.text('Payment successful'), findsOneWidget);
      expect(
        find.text(
          '₵29.00 paid from your TroSky Wallet. Your seats are booked.',
        ),
        findsOneWidget,
      );
      expect(find.text('BOOKING REFERENCE'), findsOneWidget);
      expect(find.text(booking.bookingReference), findsOneWidget);
      expect(find.text('3 & 4'), findsOneWidget);
      // Tickets come with Step 16.
      expect(find.text('View ticket'), findsNothing);
      expect(world.backend.bookingStatus(booking.id), BookingStatus.confirmed);
      expect(world.backend.walletBalance(_phone), closeTo(99.5, 1e-9));
      expect(world.payMethods.methods.values.single, 'wallet');

      await _tap(tester, 'Go to Trips');
      expect(find.byType(TripsScreen), findsOneWidget);
      expect(
        tester.widget<TroskyBookingRow>(row('Madina', 'Circle')).status,
        'Paid · Upcoming',
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TroskyHeldBookingCard), findsNothing);
    });

    testWidgets('a second tap pays once', (tester) async {
      final world = morning();
      final payments = RecordedPayments(world);
      await acceptedPayment(
        tester,
        world: world,
        overrides: [payments.provider],
      );
      await tester.tap(find.text('Pay ₵29.00'));
      await tester.tap(find.text('Pay ₵29.00'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(payments.keys, hasLength(1));
      expect(world.backend.walletBalance(_phone), closeTo(99.5, 1e-9));
      expect(find.text('Payment successful'), findsOneWidget);
    });

    testWidgets('the answer is lost: paying again sends the same key and '
        'charges once', (tester) async {
      final world = morning();
      final payments = RecordedPayments(world)..loseNextAnswer = true;
      await acceptedPayment(
        tester,
        world: world,
        overrides: [payments.provider],
      );
      await _tap(tester, 'Pay ₵29.00');
      expect(_pay(tester).stage, PayStage.idle);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Pay ₵29.00');
      expect(payments.keys, hasLength(2));
      expect(payments.keys.first, payments.keys.last);
      expect(world.backend.walletBalance(_phone), closeTo(99.5, 1e-9));
      expect(find.text('Payment successful'), findsOneWidget);
    });

    testWidgets('too little: MoMo is offered, and the sheet says why the '
        'wallet is not', (tester) async {
      final world = morning();
      world.backend.setWalletBalance(_phone, 5);
      await acceptedPayment(tester, world: world);
      expect(_card(tester).title, 'MTN MoMo');
      expect(_card(tester).detail, '024\u00A0***\u00A04567 · My MTN');

      await _tap(tester, 'Change');
      expect(find.text('Choose how to pay ₵29.00.'), findsOneWidget);
      expect(find.text('Not enough for ₵29.00'), findsOneWidget);
      // The wallet can't be chosen.
      await tester.tap(find.text('TroSky Wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Not enough for ₵29.00'), findsOneWidget);
      expect(_card(tester).title, 'MTN MoMo');
    });

    testWidgets('the balance fell meanwhile: failed, then another way', (
      tester,
    ) async {
      final (world, booking) = await acceptedPayment(tester);
      world.backend.setWalletBalance(_phone, 5);
      await _tap(tester, 'Pay ₵29.00');
      expect(_pay(tester).stage, PayStage.failed);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.textContaining(
          "Your TroSky Wallet doesn't hold ₵29.00. You haven't been charged. "
          'Your seats are held for 9:',
        ),
        findsOneWidget,
      );
      expect(world.backend.bookingStatus(booking.id), BookingStatus.pending);

      await _tap(tester, 'Change method');
      expect(find.text('Balance ₵5.00'), findsOneWidget);
      await tester.tap(find.text('024\u00A0***\u00A04567 · My MTN'));
      await tester.pumpAndSettle();
      expect(_pay(tester).stage, PayStage.idle);
      expect(_card(tester).title, 'MTN MoMo');
    });

    testWidgets('Back from a failure goes back to paying', (tester) async {
      final (world, _) = await acceptedPayment(tester);
      world.backend.setWalletBalance(_phone, 5);
      await _tap(tester, 'Pay ₵29.00');
      expect(_pay(tester).stage, PayStage.failed);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_pay(tester).stage, PayStage.idle);
      expect(find.text('PAY WITH'), findsOneWidget);
    });
  });

  group('MTN MoMo', () {
    testWidgets('approved: Approve on your phone, then paid; remembered', (
      tester,
    ) async {
      final (world, booking) = await acceptedPayment(tester);
      await _choose(tester, 'MTN MoMo');
      expect(_card(tester).detail, '024\u00A0***\u00A04567 · My MTN');
      await _tap(tester, 'Pay ₵29.00');

      expect(_pay(tester).stage, PayStage.approving);
      expect(find.text('Approve on your phone'), findsOneWidget);
      expect(
        find.text(
          'We sent a request for ₵29.00 to 024\u00A0***\u00A04567. Enter your MoMo PIN '
          'in the prompt to pay.',
        ),
        findsOneWidget,
      );
      expect(find.text('left to approve'), findsOneWidget);
      expect(find.text("I didn't get a prompt"), findsOneWidget);
      expect(
        world.backend.bookingStatus(booking.id),
        BookingStatus.paymentPending,
      );

      await waitFor(tester, world, paymentSyncEvery);
      expect(_pay(tester).stage, PayStage.paid);
      expect(
        find.text('₵29.00 paid with MTN MoMo. Your seats are booked.'),
        findsOneWidget,
      );
      expect(world.backend.bookingStatus(booking.id), BookingStatus.confirmed);
      // The wallet wasn't touched; the number is offered first next time.
      expect(world.backend.walletBalance(_phone), closeTo(128.5, 1e-9));
      expect(
        world.payMethods.methods.values.single,
        '6d2e8b14-3c5a-4f70-9a1e-2b7c4d9f0a31',
      );
    });

    testWidgets('the number used last is offered first', (tester) async {
      final world = morning();
      world.payMethods.methods['2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41'] =
          '6d2e8b14-3c5a-4f70-9a1e-2b7c4d9f0a31';
      await acceptedPayment(tester, world: world);
      expect(_card(tester).title, 'MTN MoMo');
    });

    testWidgets('a new number is checked, saved and paid with; declined '
        '(0000): Try again, then the wallet', (tester) async {
      final (world, booking) = await acceptedPayment(tester);
      await _tap(tester, 'Change');
      await _tap(tester, '+ Add an MTN MoMo number');
      await tester.enterText(find.byType(TextField), '12345');
      await _tap(tester, 'Use this number');
      expect(
        find.text('Enter a valid MTN MoMo number, like 024 123 4567.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '+233 24 000 0000');
      await _tap(tester, 'Use this number');
      expect(_card(tester).detail, '024\u00A0***\u00A00000');

      await _tap(tester, 'Pay ₵29.00');
      expect(find.textContaining('to 024\u00A0***\u00A00000.'), findsOneWidget);
      await waitFor(tester, world, paymentSyncEvery);
      expect(_pay(tester).stage, PayStage.failed);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.textContaining(
          "The payment was declined on your phone. You haven't been charged. "
          'Your seats are held for 9:',
        ),
        findsOneWidget,
      );
      // Back to be paid again (payment_service.py `_apply_provider_status`).
      expect(world.backend.bookingStatus(booking.id), BookingStatus.pending);

      await _tap(tester, 'Try again');
      expect(_pay(tester).stage, PayStage.approving);
      await waitFor(tester, world, paymentSyncEvery);
      expect(_pay(tester).stage, PayStage.failed);

      await _tap(tester, 'Change method');
      await tester.tap(find.text('TroSky Wallet'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Pay ₵29.00');
      expect(find.text('Payment successful'), findsOneWidget);
      expect(world.backend.bookingStatus(booking.id), BookingStatus.confirmed);
    });

    testWidgets('a number saved already is used, not saved twice', (
      tester,
    ) async {
      await acceptedPayment(tester);
      await _addNumber(tester, '024 123 4567');
      expect(_card(tester).detail, '024\u00A0***\u00A04567 · My MTN');
      await _tap(tester, 'Change');
      expect(find.byType(TroskyPayMethodOption), findsNWidgets(2));
    });

    testWidgets('no answer (9999): time runs out with the hold', (
      tester,
    ) async {
      final (world, booking) = await acceptedPayment(tester);
      await _addNumber(tester, '0249999999');
      await _tap(tester, 'Pay ₵29.00');
      await waitFor(tester, world, const Duration(seconds: 30));
      expect(_pay(tester).stage, PayStage.approving);

      world.now = booking.expiresAt!;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_pay(tester).stage, PayStage.timedOut);
      expect(find.text('Time ran out'), findsOneWidget);
      expect(
        find.text(
          "Your seats were released because the payment wasn't approved in "
          'time. If it still goes through, TroSky refunds it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Search again'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(world.backend.bookingStatus(booking.id), BookingStatus.expired);
      // Nothing more is asked.
      final checks = world.backend.paymentStatus(_pay(tester).payment!.id);
      expect(checks, PaymentStatus.processing);
    });

    testWidgets('approved after the hold ran out: a refund', (tester) async {
      final (world, booking) = await acceptedPayment(tester);
      await _choose(tester, 'MTN MoMo');
      await _tap(tester, 'Pay ₵29.00');
      // MTN answers just as the hold ends.
      world.backend.momoApproveAfter = booking.expiresAt!.difference(world.now);
      world.now = booking.expiresAt!;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_pay(tester).stage, PayStage.timedOut);
      expect(
        find.text(
          'The payment came through after your seats were released, so '
          'TroSky refunds ₵29.00.',
        ),
        findsOneWidget,
      );
      expect(
        world.backend.bookingStatus(booking.id),
        BookingStatus.refundPending,
      );
    });

    testWidgets("I didn't get a prompt: Check again asks now", (tester) async {
      final world = morning()
        ..backend.momoApproveAfter = const Duration(hours: 1);
      final payments = RecordedPayments(world);
      await acceptedPayment(
        tester,
        world: world,
        overrides: [payments.provider],
      );
      await _choose(tester, 'MTN MoMo');
      await _tap(tester, 'Pay ₵29.00');
      await _tap(tester, "I didn't get a prompt");
      expect(find.text('No prompt yet?'), findsOneWidget);
      expect(find.textContaining('dial *170#'), findsOneWidget);
      final before = payments.syncs;
      await _tap(tester, 'Check again');
      expect(payments.syncs, before + 1);
      expect(find.text('No prompt yet?'), findsNothing);
      expect(_pay(tester).stage, PayStage.approving);

      await _tap(tester, "I didn't get a prompt");
      await _tap(tester, 'Keep waiting');
      expect(payments.syncs, before + 1);
    });

    testWidgets('no connection: a note, and checks back off', (tester) async {
      final world = morning()
        ..backend.momoApproveAfter = const Duration(hours: 1);
      final payments = RecordedPayments(world);
      await acceptedPayment(
        tester,
        world: world,
        overrides: [payments.provider],
      );
      await _choose(tester, 'MTN MoMo');
      await _tap(tester, 'Pay ₵29.00');
      payments.syncFailures.addAll([offline, offline]);
      await waitFor(tester, world, paymentSyncEvery);
      expect(payments.syncs, 1);
      expect(find.text("No connection. We'll keep checking."), findsOneWidget);
      // 10 s, then 20 s.
      await waitFor(tester, world, const Duration(seconds: 9));
      expect(payments.syncs, 1);
      await waitFor(tester, world, const Duration(seconds: 1));
      expect(payments.syncs, 2);
      await waitFor(tester, world, const Duration(seconds: 20));
      expect(payments.syncs, 3);
      expect(find.text("No connection. We'll keep checking."), findsNothing);
    });

    testWidgets('Back while approving goes Home; its card reopens it and it '
        'carries on', (tester) async {
      final (world, booking) = await acceptedPayment(tester);
      await _choose(tester, 'MTN MoMo');
      await _tap(tester, 'Pay ₵29.00');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TroskyHeldBookingCard), findsOneWidget);

      await _tap(tester, 'View status');
      expect(_pay(tester).stage, PayStage.approving);
      // Reopened, the number isn't known.
      expect(
        find.text(
          'We sent a request for ₵29.00 to your MTN MoMo number. Enter your '
          'MoMo PIN in the prompt to pay.',
        ),
        findsOneWidget,
      );
      await waitFor(tester, world, paymentSyncEvery);
      expect(_pay(tester).stage, PayStage.paid);
      expect(world.backend.bookingStatus(booking.id), BookingStatus.confirmed);

      // Back from a reopened, paid booking goes back to Home, card gone.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TroskyHeldBookingCard), findsNothing);
    });
  });

  testWidgets('the cancel sheet says where a MoMo refund goes', (tester) async {
    final (world, _) = await acceptedPayment(tester);
    await _choose(tester, 'MTN MoMo');
    await _tap(tester, 'Pay ₵29.00');
    await waitFor(tester, world, paymentSyncEvery);
    await _tap(tester, 'Go to Trips');
    await openBooking(tester, 'Madina', 'Circle');
    await _tap(tester, 'Cancel booking');
    expect(find.text('Refund: ₵29.00'), findsOneWidget);
    expect(
      find.text(
        'Once TroSky approves the refund, our team sends it back to your MTN '
        'MoMo number or your TroSky Wallet.',
      ),
      findsOneWidget,
    );
  });

  group('360 x 640 at text scale 1.3: no overflow', () {
    testWidgets('paying, approving, paid', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (world, _) = await acceptedPayment(
        tester,
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      await _choose(tester, 'MTN MoMo');
      await _tap(tester, 'Pay ₵29.00');
      expect(tester.takeException(), isNull);
      await _tap(tester, "I didn't get a prompt");
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Keep waiting');
      await waitFor(tester, world, paymentSyncEvery);
      expect(_pay(tester).stage, PayStage.paid);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet with a new number, then failed', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (world, _) = await acceptedPayment(
        tester,
        size: const Size(360, 640),
      );
      await _tap(tester, 'Change');
      await _tap(tester, '+ Add an MTN MoMo number');
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '0240000000');
      await _tap(tester, 'Use this number');
      await _tap(tester, 'Pay ₵29.00');
      await waitFor(tester, world, paymentSyncEvery);
      expect(_pay(tester).stage, PayStage.failed);
      expect(tester.takeException(), isNull);
    });
  });
}
