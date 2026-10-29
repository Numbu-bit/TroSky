import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

/// Paying in mock mode must answer like backend/app/services/
/// payment_service.py with the sandbox provider (Step 15 Part A): the
/// wallet at once, mobile money approved after a delay, numbers ending 0000
/// declined, numbers ending 9999 never answered.
void main() {
  late DateTime now;
  late MockBackend backend;
  late String token;
  late BookingResponse booking;
  const phone = MockBackend.passengerPhone;

  String? code<T>(Result<T> result) => result.failureOrNull?.code;

  /// Ama Mensah's seats 3 and 4 on P7's minibus, accepted: ₵29.00 to pay.
  BookingResponse accepted() {
    final trip = backend
        .searchTrips(
          TripSearchQuery(
            originStopId: MockBackend.stops['Madina']!.id,
            destinationStopId: MockBackend.stops['Circle']!.id,
            travelDate: now,
            departureAfter: Duration(hours: now.hour, minutes: now.minute),
          ),
        )
        .valueOrNull!
        .items
        .firstWhere((t) => t.vehicleRegistrationNumber == 'GR-4821');
    final seats = backend.tripSeats(trip.tripId).valueOrNull!.seats;
    String seat(String number) =>
        seats.firstWhere((s) => s.seatNumber == number).id;
    final made = backend
        .createBooking(
          token,
          BookingCreateRequest(
            tripId: trip.tripId,
            passengers: [
              PassengerInput(seatId: seat('3'), fullName: 'Ama Mensah'),
              PassengerInput(seatId: seat('4'), fullName: 'Kwabena Mensah'),
            ],
          ),
        )
        .valueOrNull!;
    backend.acceptBooking(made.id);
    return backend.getBooking(token, made.id).valueOrNull!;
  }

  BookingStatus status() => backend.bookingStatus(booking.id);

  setUp(() {
    now = DateTime.utc(2026, 10, 1, 9);
    backend = MockBackend(clock: () => now)..simulateRiders = false;
    token = backend
        .login(
          const LoginRequest(
            identifier: '0241234567',
            password: MockBackend.seedPassword,
          ),
        )
        .valueOrNull!
        .accessToken;
    booking = accepted();
  });

  group('the wallet', () {
    test('₵128.50, as P-07 shows it; paying debits it and confirms', () {
      expect(backend.getWallet(token).valueOrNull!.balance, '128.50');
      expect(booking.totalAmount, '29.00');
      final payment = backend
          .payBooking(
            token,
            booking.id,
            const PayBookingRequest(channel: PaymentChannel.wallet),
          )
          .valueOrNull!;
      expect(payment.status, PaymentStatus.successful);
      expect(payment.amount, '29.00');
      expect(payment.channel, PaymentChannel.wallet);
      expect(status(), BookingStatus.confirmed);
      expect(backend.getWallet(token).valueOrNull!.balance, '99.50');
    });

    test('too little: 402, nothing changes', () {
      backend.setWalletBalance(phone, 28.99);
      final result = backend.payBooking(
        token,
        booking.id,
        const PayBookingRequest(channel: PaymentChannel.wallet),
      );
      expect(code(result), 'INSUFFICIENT_WALLET_BALANCE');
      expect(result.failureOrNull!.statusCode, 402);
      expect(status(), BookingStatus.pending);
      expect(backend.walletBalance(phone), 28.99);
    });

    test('the same idempotency key gives the same payment, paid once', () {
      Result<PaymentResponse> pay() => backend.payBooking(
        token,
        booking.id,
        const PayBookingRequest(channel: PaymentChannel.wallet),
        idempotencyKey: 'k1',
      );
      final first = pay().valueOrNull!;
      final again = pay().valueOrNull!;
      expect(again.id, first.id);
      expect(backend.walletBalance(phone), closeTo(99.5, 1e-9));
    });

    test('a booking not awaiting payment: 409 BOOKING_NOT_PAYABLE', () {
      backend.payBooking(
        token,
        booking.id,
        const PayBookingRequest(channel: PaymentChannel.wallet),
      );
      final again = backend.payBooking(
        token,
        booking.id,
        const PayBookingRequest(channel: PaymentChannel.wallet),
      );
      expect(code(again), 'BOOKING_NOT_PAYABLE');
      expect(again.failureOrNull!.statusCode, 409);
    });

    test('a method id or a channel, not both', () {
      final result = backend.payBooking(
        token,
        booking.id,
        const PayBookingRequest(
          paymentMethodId: '6d2e8b14-3c5a-4f70-9a1e-2b7c4d9f0a31',
          channel: PaymentChannel.wallet,
        ),
      );
      expect(code(result), 'VALIDATION_ERROR');
    });
  });

  group('MTN MoMo', () {
    PaymentResponse pay(String number) => backend
        .payBooking(
          token,
          booking.id,
          PayBookingRequest(
            channel: PaymentChannel.mtnMomo,
            payerPhoneNumber: number,
          ),
        )
        .valueOrNull!;

    PaymentResponse sync(PaymentResponse payment) =>
        backend.syncPayment(token, payment.id).valueOrNull!;

    test('processing, then approved after momoApproveAfter', () {
      final payment = pay(phone);
      expect(payment.status, PaymentStatus.processing);
      expect(status(), BookingStatus.paymentPending);
      now = now.add(const Duration(seconds: 4));
      expect(sync(payment).status, PaymentStatus.processing);
      now = now.add(const Duration(seconds: 1));
      expect(sync(payment).status, PaymentStatus.successful);
      expect(status(), BookingStatus.confirmed);
      expect(backend.walletBalance(phone), 128.5);
    });

    test('a saved number by its id', () {
      final payment = backend
          .payBooking(
            token,
            booking.id,
            const PayBookingRequest(
              paymentMethodId: '6d2e8b14-3c5a-4f70-9a1e-2b7c4d9f0a31',
            ),
          )
          .valueOrNull!;
      expect(payment.channel, PaymentChannel.mtnMomo);
      expect(payment.status, PaymentStatus.processing);
    });

    test('ending 0000: declined at the first check; the booking can be '
        'paid again', () {
      final payment = pay('+233240000000');
      final declined = sync(payment);
      expect(declined.status, PaymentStatus.failed);
      expect(declined.failureReason, 'Customer declined the payment prompt.');
      expect(status(), BookingStatus.pending);
      expect(pay(phone).status, PaymentStatus.processing);
    });

    test('ending 9999: never answers; the hold still runs out', () {
      final payment = pay('+233249999999');
      now = now.add(const Duration(minutes: 9));
      expect(sync(payment).status, PaymentStatus.processing);
      expect(status(), BookingStatus.paymentPending);
      now = booking.expiresAt!;
      expect(sync(payment).status, PaymentStatus.processing);
      expect(status(), BookingStatus.expired);
    });

    test('approved after the hold ran out: waits for a refund', () {
      final payment = pay(phone);
      // Approved a minute after the hold ran out (within the token's life).
      backend.momoApproveAfter =
          booking.expiresAt!.difference(now) + const Duration(minutes: 1);
      now = booking.expiresAt!;
      expect(sync(payment).status, PaymentStatus.processing);
      expect(status(), BookingStatus.expired);
      now = now.add(const Duration(minutes: 1));
      expect(sync(payment).status, PaymentStatus.successful);
      expect(status(), BookingStatus.refundPending);
    });

    test('GET /payments lists them newest first', () {
      final declined = pay('+233240000000');
      sync(declined);
      now = now.add(const Duration(seconds: 1));
      final second = pay(phone);
      final items = backend.listPayments(token).valueOrNull!.items;
      expect(items.map((p) => p.id), [second.id, declined.id]);
      expect(items.last.status, PaymentStatus.failed);
    });
  });

  group('saved numbers', () {
    test('Ama has her MTN number, masked like the backend', () {
      final methods = backend.listPaymentMethods(token).valueOrNull!;
      expect(methods.single.maskedNumber, '+23324•••4567');
      expect(methods.single.isDefault, isTrue);
      expect(methods.single.label, 'My MTN');
    });

    test('a new number is normalised and saved; twice is a conflict', () {
      final added = backend
          .addPaymentMethod(
            token,
            const PaymentMethodCreateRequest(
              channel: PaymentChannel.mtnMomo,
              phoneNumber: '055 123 4567',
            ),
          )
          .valueOrNull!;
      expect(added.maskedNumber, '+23355•••4567');
      expect(added.isDefault, isFalse);
      final again = backend.addPaymentMethod(
        token,
        const PaymentMethodCreateRequest(
          channel: PaymentChannel.mtnMomo,
          phoneNumber: '+233551234567',
        ),
      );
      expect(code(again), 'CONFLICT');
      expect(again.failureOrNull!.statusCode, 409);
      expect(backend.listPaymentMethods(token).valueOrNull!, hasLength(2));
    });

    test('not a number: 422 "Enter a valid mobile money number."', () {
      final result = backend.addPaymentMethod(
        token,
        const PaymentMethodCreateRequest(
          channel: PaymentChannel.mtnMomo,
          phoneNumber: '12345',
        ),
      );
      expect(code(result), 'VALIDATION_ERROR');
      expect(
        result.failureOrNull!.message,
        'Enter a valid mobile money number.',
      );
    });
  });

  test('the history: wallet and MoMo payments for the paid bookings', () {
    final history = MockBackend(
      clock: () => DateTime.utc(2026, 10, 15, 10),
      bookingHistory: true,
    );
    final ama = history
        .login(
          const LoginRequest(
            identifier: '0241234567',
            password: MockBackend.seedPassword,
          ),
        )
        .valueOrNull!
        .accessToken;
    final payments = history.listPayments(ama, limit: 50).valueOrNull!.items;
    expect(payments, hasLength(7));
    expect(
      payments.where((p) => p.channel == PaymentChannel.wallet),
      hasLength(4),
    );
    expect(
      payments.where((p) => p.status == PaymentStatus.refunded),
      hasLength(1),
    );
  });
}
