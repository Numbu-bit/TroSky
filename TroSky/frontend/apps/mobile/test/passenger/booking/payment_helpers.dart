import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/booking/application/booking_watch.dart';
import 'package:mobile/passenger/booking/presentation/payment_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';
import '../search/search_helpers.dart';
import '../seats/seat_helpers.dart';

/// Mock mode at 09:00: P7's minibus (09:03, Madina → Circle, GR-4821) with
/// [seats] reserved. Payment opens, waiting for the driver.
Future<(TestWorld, BookingResponse)> reserve(
  WidgetTester tester, {
  TestWorld? world,
  List<String> seats = const ['3', '4'],
  Size size = const Size(360, 806),
  List<Object> overrides = const [],
}) async {
  final w = world ?? morning();
  await openSeats(tester, world: w, size: size, overrides: overrides);
  for (final number in seats) {
    await tapSeat(tester, number);
  }
  await tapReserve(tester);
  expect(find.byType(PaymentScreen), findsOneWidget);
  return (w, paymentBooking(tester));
}

/// The booking Payment opened with.
BookingResponse paymentBooking(WidgetTester tester) =>
    tester.widget<PaymentScreen>(find.byType(PaymentScreen)).args.booking;

/// [time] passes on the phone's and the backend's clocks, a second at a
/// time: the countdown ticks and the polls that fall due run.
Future<void> waitFor(
  WidgetTester tester,
  TestWorld world,
  Duration time,
) async {
  var left = time;
  while (left > Duration.zero) {
    final step = left < const Duration(seconds: 1)
        ? left
        : const Duration(seconds: 1);
    world.now = world.now.add(step);
    await tester.pump(step);
    left -= step;
  }
  await tester.pump();
}

/// Until the next poll ([bookingPollEvery]) has run.
Future<void> nextPoll(WidgetTester tester, TestWorld world) =>
    waitFor(tester, world, bookingPollEvery);

/// The driver doesn't answer by [booking]'s deadline: the backend moves it
/// to another vehicle (or ends it), and the next poll finds out.
Future<void> letDeadlinePass(
  WidgetTester tester,
  TestWorld world,
  BookingResponse booking,
) async {
  world.now = booking.expiresAt!;
  await nextPoll(tester, world);
}

/// The waiting countdown's time ("1:42").
String countdownTime(WidgetTester tester) =>
    tester.widget<TroskyCountdown>(find.byType(TroskyCountdown)).time;

/// Bookings on [TestWorld.backend] that count `GET /bookings/{id}` (the
/// polls) and answer the next ones with [failures] first.
class PolledBookings implements BookingRepository {
  PolledBookings(this.world);

  final TestWorld world;
  late final BookingRepository _inner;
  final List<AppFailure> failures = [];
  int gets = 0;
  final List<String> cancelled = [];

  /// Puts this in place of the app's booking repository.
  Object get provider => bookingRepositoryProvider.overrideWith((ref) {
    _inner = MockBookingRepository(
      world.backend,
      tokens: () => ref.read(tokenManagerProvider),
    );
    return this;
  });

  @override
  Future<Result<BookingResponse>> create(
    BookingCreateRequest request, {
    required String idempotencyKey,
  }) => _inner.create(request, idempotencyKey: idempotencyKey);

  @override
  Future<Result<Paginated<BookingResponse>>> list({
    List<BookingStatus>? statuses,
    bool? upcoming,
    int limit = 20,
    int offset = 0,
  }) => _inner.list(
    statuses: statuses,
    upcoming: upcoming,
    limit: limit,
    offset: offset,
  );

  @override
  Future<Result<BookingSummaryResponse>> summary({String? month}) =>
      _inner.summary(month: month);

  @override
  Future<Result<BookingResponse>> get(String bookingId) async {
    gets++;
    if (failures.isNotEmpty) return Err(failures.removeAt(0));
    return _inner.get(bookingId);
  }

  @override
  Future<Result<BookingResponse>> cancel(String bookingId, {String? reason}) {
    cancelled.add(bookingId);
    return _inner.cancel(bookingId, reason: reason);
  }
}

/// No connection, as Dio reports it.
const AppFailure offline = NetworkFailure();

/// What Payment shows now.
BookingWatch watchShown(WidgetTester tester) {
  final screen = tester.widget<PaymentScreen>(find.byType(PaymentScreen));
  return container(tester).read(bookingWatchControllerProvider(screen.args));
}

/// The [PaymentStage] Payment shows now.
PaymentStage stageShown(WidgetTester tester) => watchShown(tester).stage;

/// [reserve], then the driver accepts: Payment shows how to pay.
Future<(TestWorld, BookingResponse)> acceptedPayment(
  WidgetTester tester, {
  TestWorld? world,
  List<String> seats = const ['3', '4'],
  Size size = const Size(360, 806),
  List<Object> overrides = const [],
}) async {
  final (w, booking) = await reserve(
    tester,
    world: world,
    seats: seats,
    size: size,
    overrides: overrides,
  );
  w.backend.acceptBooking(booking.id);
  await nextPoll(tester, w);
  await tester.pumpAndSettle();
  return (w, watchShown(tester).booking);
}

/// Payments on [TestWorld.backend] that keep each idempotency key sent,
/// count the status checks, and can lose the next answer to pay or fail
/// the next checks.
class RecordedPayments implements PaymentRepository {
  RecordedPayments(this.world);

  final TestWorld world;
  late final PaymentRepository _inner;

  /// The next `POST /bookings/{id}/pay` reaches the server, but its answer
  /// is lost (no connection).
  bool loseNextAnswer = false;
  final List<String> keys = [];
  final List<AppFailure> syncFailures = [];
  int syncs = 0;

  /// Puts this in place of the app's payment repository.
  Object get provider => paymentRepositoryProvider.overrideWith((ref) {
    _inner = MockPaymentRepository(
      world.backend,
      tokens: () => ref.read(tokenManagerProvider),
    );
    return this;
  });

  @override
  Future<Result<PaymentResponse>> pay(
    String bookingId,
    PayBookingRequest request, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    final result = await _inner.pay(
      bookingId,
      request,
      idempotencyKey: idempotencyKey,
    );
    if (loseNextAnswer) {
      loseNextAnswer = false;
      return const Err(offline);
    }
    return result;
  }

  @override
  Future<Result<PaymentResponse>> sync(String paymentId) async {
    syncs++;
    if (syncFailures.isNotEmpty) return Err(syncFailures.removeAt(0));
    return _inner.sync(paymentId);
  }

  @override
  Future<Result<Paginated<PaymentResponse>>> list({
    int limit = 20,
    int offset = 0,
  }) => _inner.list(limit: limit, offset: offset);

  @override
  Future<Result<WalletResponse>> wallet() => _inner.wallet();

  @override
  Future<Result<List<PaymentMethodResponse>>> methods() => _inner.methods();

  @override
  Future<Result<PaymentMethodResponse>> addMethod(
    PaymentMethodCreateRequest request,
  ) => _inner.addMethod(request);
}
