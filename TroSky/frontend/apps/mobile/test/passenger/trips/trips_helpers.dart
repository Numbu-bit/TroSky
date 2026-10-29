import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/trips/presentation/booking_details_screen.dart';
import 'package:mobile/passenger/trips/application/trips_providers.dart';
import 'package:mobile/passenger/trips/presentation/trips_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';
import '../home/home_helpers.dart';

/// Wednesday 15 Oct 2026, 10:00, with Ama Mensah's week of bookings
/// (MockBackend.bookingHistory): ahead, paid TS-8KQ2 (Madina → Circle,
/// tomorrow 07:15, seats 3 and 4), waiting TS-4HBN (Legon → Osu), pending
/// TS-Q7RD (Circle → Tema), and TS-C2MX on a trip under way (Achimota →
/// Lapaz); behind, completed, cancelled, refunded, a refund waiting and an
/// expired one.
TestWorld withHistory() =>
    TestWorld(bookingHistory: true)..now = DateTime(2026, 10, 15, 10);

/// Signed in, on the Trips tab.
Future<TestWorld> openTrips(
  WidgetTester tester, {
  TestWorld? world,
  Size size = const Size(360, 806),
  List<Object> overrides = const [],
}) async {
  final w = await openHome(
    tester,
    world: world ?? withHistory(),
    size: size,
    overrides: overrides,
  );
  // The tab bar's label; the Trips screen isn't built yet.
  await tester.tap(find.text('Trips'));
  await tester.pumpAndSettle();
  expect(find.byType(TripsScreen), findsOneWidget);
  return w;
}

/// Shows the Past tab.
Future<void> showPast(WidgetTester tester) async {
  await tester.tap(find.text('Past'));
  await tester.pumpAndSettle();
}

/// The row of the booking from [from] to [to].
Finder row(String from, String to) => find.byWidgetPredicate(
  (w) => w is TroskyBookingRow && w.route == '$from → $to',
);

/// Opens the booking from [from] to [to] on the current tab.
Future<void> openBooking(WidgetTester tester, String from, String to) async {
  await tester.scrollUntilVisible(
    row(from, to),
    200,
    scrollable: find.descendant(
      of: find.byType(TripsScreen),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(row(from, to));
  await tester.pumpAndSettle();
  expect(find.byType(BookingDetailsScreen), findsOneWidget);
}

/// Back from Booking details to Trips.
Future<void> back(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Back').last);
  await tester.pumpAndSettle();
}

/// The status chip in Booking details' header.
String headerChip(WidgetTester tester) => tester
    .widget<TroskyStatusChip>(
      find.descendant(
        of: find.byType(TroskyPageHeader),
        matching: find.byType(TroskyStatusChip),
      ),
    )
    .label;

/// Bookings on [TestWorld.backend] that fail the next calls on cue and
/// record each cancel's reason.
class ScriptedBookings implements BookingRepository {
  ScriptedBookings(this.world);

  final TestWorld world;
  late BookingRepository _inner;

  /// Answers Trip History's next pages, in order.
  final List<AppFailure> listFailures = [];

  /// Answers the next `POST /bookings/{id}/cancel`, in order.
  final List<AppFailure> cancelFailures = [];
  final List<(String, String?)> cancels = [];

  /// Trip History's pages asked for (20 a page; Home's held-booking check,
  /// 5 a page, isn't counted).
  final List<int> offsets = [];

  /// When set, `GET /bookings` pages through these instead.
  List<BookingResponse>? served;

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
  }) async {
    final page = limit == bookingsPageSize;
    if (page) offsets.add(offset);
    if (page && listFailures.isNotEmpty) return Err(listFailures.removeAt(0));
    if (served case final all? when page) {
      return Ok(
        Paginated(
          items: all.skip(offset).take(limit).toList(),
          total: all.length,
          limit: limit,
          offset: offset,
        ),
      );
    }
    return _inner.list(
      statuses: statuses,
      upcoming: upcoming,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Result<BookingSummaryResponse>> summary({String? month}) =>
      _inner.summary(month: month);

  @override
  Future<Result<BookingResponse>> get(String bookingId) =>
      _inner.get(bookingId);

  @override
  Future<Result<BookingResponse>> cancel(
    String bookingId, {
    String? reason,
  }) async {
    cancels.add((bookingId, reason));
    if (cancelFailures.isNotEmpty) return Err(cancelFailures.removeAt(0));
    return _inner.cancel(bookingId, reason: reason);
  }
}
