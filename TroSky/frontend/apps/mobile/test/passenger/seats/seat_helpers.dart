import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/seats/application/seat_providers.dart';
import 'package:mobile/passenger/seats/presentation/seat_selection_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';
import '../home/home_helpers.dart';
import '../search/search_helpers.dart';

/// A seat as `GET /trips/{id}/seats` sends it; its id is `seat-<number>`.
TripSeatResponse seatAt(
  String number,
  int row,
  int column, {
  bool free = true,
  SeatType type = SeatType.standard,
}) => TripSeatResponse(
  id: 'seat-$number',
  seatNumber: number,
  rowNumber: row,
  columnNumber: column,
  seatType: type,
  isAvailable: free,
);

/// P7's minibus: rows of 2 + 2, seats 13 and 14 at the back.
List<TripSeatResponse> p7Seats({Set<String> taken = const {}}) => [
  for (var i = 1; i <= 12; i++)
    seatAt(
      '$i',
      (i - 1) ~/ 4 + 1,
      (i - 1) % 4 + 1,
      free: !taken.contains('$i'),
    ),
  seatAt('13', 4, 2, free: !taken.contains('13')),
  seatAt('14', 4, 3, free: !taken.contains('14')),
];

/// A 3-across vehicle (2 + 1), three rows.
List<TripSeatResponse> threeColumnSeats({Set<String> taken = const {}}) => [
  for (var i = 1; i <= 9; i++)
    seatAt(
      '$i',
      (i - 1) ~/ 3 + 1,
      (i - 1) % 3 + 1,
      free: !taken.contains('$i'),
    ),
];

/// A bus coded with an empty aisle column (3) and a full 5-seat back bench.
List<TripSeatResponse> benchBusSeats() => [
  for (var row = 1; row <= 3; row++)
    for (final (i, column) in const [1, 2, 4, 5].indexed)
      seatAt('${(row - 1) * 4 + i + 1}', row, column),
  for (var column = 1; column <= 5; column++)
    seatAt('${12 + column}', 4, column),
];

/// The live seat map of [tripId]: no G20 fares.
TripSeatsResponse seatMap(String tripId, List<TripSeatResponse> seats) =>
    TripSeatsResponse(
      tripId: tripId,
      vehicleId: 'v1',
      totalSeats: seats.length,
      availableSeats: seats.where((s) => s.isAvailable).length,
      seats: seats,
    );

/// Search Results for the "Madina → Circle" favourite at 09:00, then the
/// trip departing at [departs]: Seat Selection. In mock mode 09:03 is P7's
/// minibus GR-4821 (5 of 14 taken), 09:45 a saloon car and 10:15 a bus
/// (3 of 21 taken).
Future<TestWorld> openSeats(
  WidgetTester tester, {
  TestWorld? world,
  Size size = const Size(360, 806),
  Env? env,
  List<Object> overrides = const [],
  String departs = '09:03',
}) async {
  final w = await openResults(
    tester,
    world: world,
    size: size,
    env: env,
    overrides: overrides,
  );
  await openTrip(tester, departs);
  return w;
}

/// On Search Results: taps the trip departing at [departs].
Future<void> openTrip(WidgetTester tester, String departs) async {
  final card = find.textContaining('Departs $departs');
  await tester.scrollUntilVisible(
    card,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
  expect(find.byType(SeatSelectionScreen), findsOneWidget);
}

/// Live mode: one trip ("t1", 09:15, ₵8.00 in the results) whose seat
/// map is [seats] and whose fare quote is [quote] a seat (default ₵6.50,
/// ₵8.00 alone, down to ₵2.00).
Future<ScriptedTrips> openLiveSeats(
  WidgetTester tester,
  TestWorld world,
  List<TripSeatResponse> seats, {
  Size size = const Size(360, 806),
  BookingRepository? bookings,
  FareSummaryResponse? quote,
}) async {
  final routes = ScriptedTrips(
    world.backend,
    [liveTrip(id: 't1', departs: DateTime(2026, 10, 1, 9, 15))],
    seatMaps: {'t1': seatMap('t1', seats)},
  );
  routes.quotes['t1'] = quote ?? fareOf('6.50', solo: '8.00');
  final live = liveMode(
    world,
    FakeTracking(const []),
    routes: routes,
    bookings: bookings,
  );
  await openResults(
    tester,
    world: world,
    size: size,
    env: live.env,
    overrides: live.overrides,
  );
  await openTrip(tester, '09:15');
  return routes;
}

/// The trip on Seat Selection.
String openTripId(WidgetTester tester) => tester
    .widget<SeatSelectionScreen>(find.byType(SeatSelectionScreen))
    .args
    .trip
    .tripId;

/// The seat numbered [number] on the map.
Finder seat(String number) => find.byWidgetPredicate(
  (w) => w is TroskySeat && w.number == number,
  description: 'seat $number',
);

TroskySeatState seatState(WidgetTester tester, String number) =>
    tester.widget<TroskySeat>(seat(number)).state;

Future<void> tapSeat(WidgetTester tester, String number) async {
  await tester.ensureVisible(seat(number));
  await tester.pumpAndSettle();
  await tester.tap(seat(number));
  await tester.pumpAndSettle();
}

/// The fare panel's button.
TroskyButton reserveButton(WidgetTester tester) => tester.widget<TroskyButton>(
  find.byWidgetPredicate(
    (w) => w is TroskyButton && w.variant == TroskyButtonVariant.seatCta,
  ),
);

Future<void> tapReserve(WidgetTester tester) async {
  final button = find.byWidgetPredicate(
    (w) => w is TroskyButton && w.variant == TroskyButtonVariant.seatCta,
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// [seatRefreshEvery] passes on the clock and on the timers: the map is
/// fetched again (and on a mock minibus, another rider books).
Future<void> nextRefresh(WidgetTester tester, TestWorld world) async {
  world.now = world.now.add(seatRefreshEvery);
  await tester.pump(seatRefreshEvery);
  await tester.pumpAndSettle();
}

/// The current SnackBar's text.
String? snackBarText(WidgetTester tester) {
  final bar = find.byType(SnackBar);
  if (bar.evaluate().isEmpty) return null;
  return (tester.widget<SnackBar>(bar.last).content as Text).data;
}

/// Bookings on the mock backend, recording each `POST /bookings` and its
/// idempotency key; [failures] answer the next creates first, in order.
class RecordingBookings implements BookingRepository {
  RecordingBookings({List<AppFailure> failures = const []})
    : failures = [...failures];

  late BookingRepository _inner;
  final List<AppFailure> failures;
  final List<(BookingCreateRequest, String)> created = [];
  final List<String> cancelled = [];

  /// Puts this on [world]'s mock backend.
  Object providerFor(TestWorld world) =>
      bookingRepositoryProvider.overrideWith((ref) {
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
  }) async {
    created.add((request, idempotencyKey));
    if (failures.isNotEmpty) return Err(failures.removeAt(0));
    return _inner.create(request, idempotencyKey: idempotencyKey);
  }

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
  Future<Result<BookingResponse>> get(String bookingId) =>
      _inner.get(bookingId);

  @override
  Future<Result<BookingResponse>> cancel(String bookingId, {String? reason}) {
    cancelled.add(bookingId);
    return _inner.cancel(bookingId, reason: reason);
  }
}

/// The app's [ProviderContainer], to read what the screens see.
ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
