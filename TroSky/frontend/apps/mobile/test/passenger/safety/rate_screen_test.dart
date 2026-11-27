// Widget tests for P-14 Rate.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/safety/domain/safety_args.dart';
import 'package:mobile/passenger/safety/presentation/rate_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeBookings implements BookingRepository {
  final List<(String, RateBookingRequest)> ratings = [];

  @override
  Future<Result<RatingResponse>> rate(
    String bookingId,
    RateBookingRequest request,
  ) async {
    ratings.add((bookingId, request));
    return Ok(
      RatingResponse(
        id: 'r1',
        bookingId: bookingId,
        tripId: 't1',
        score: request.score,
        comment: request.comment,
        createdAt: DateTime.utc(2026, 11, 18),
      ),
    );
  }

  // Unused for this test.
  @override
  Future<Result<BookingResponse>> create(
    BookingCreateRequest request, {
    required String idempotencyKey,
  }) async => const Err(NetworkFailure());
  @override
  Future<Result<Paginated<BookingResponse>>> list({
    List<BookingStatus>? statuses,
    bool? upcoming,
    int limit = 20,
    int offset = 0,
  }) async => const Err(NetworkFailure());
  @override
  Future<Result<BookingSummaryResponse>> summary({String? month}) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<BookingResponse>> get(String bookingId) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<BookingResponse>> cancel(
    String bookingId, {
    CancelReason? reason,
  }) async => const Err(NetworkFailure());
  @override
  Future<Result<RatingResponse>> getRating(String bookingId) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<TripShareLinkResponse>> mintShareLink(String bookingId) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<void>> revokeShareLinks(String bookingId) async =>
      const Err(NetworkFailure());
}

class _Tel implements TelemetryService {
  final events = <TelemetryEvent>[];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

BookingResponse _booking() => BookingResponse(
  id: 'b1',
  bookingReference: 'TRK-TEST',
  tripId: 't1',
  status: BookingStatus.completed,
  passengerCount: 1,
  fareAmount: '12.00',
  platformFee: '0.00',
  totalAmount: '12.00',
  createdAt: DateTime.utc(2026, 11, 18),
  passengers: const [
    BookingPassengerResponse(id: 'p1', seatId: '4', fullName: 'Kofi'),
  ],
  trip: BookingTripSummaryResponse(
    scheduledDepartureAt: DateTime.utc(2026, 11, 18, 8),
    routeName: 'Madina → Circle',
    originStopName: 'Madina',
    destinationStopName: 'Circle',
    status: TripStatus.completed,
  ),
);

Widget _host({
  required BookingRepository bookings,
  required TelemetryService tel,
}) => ProviderScope(
  overrides: [
    bookingRepositoryProvider.overrideWithValue(bookings),
    telemetryProvider.overrideWithValue(tel),
  ],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: RateScreen(args: RateArgs(booking: _booking())),
  ),
);

void main() {
  testWidgets(
    'submit is disabled until a star is tapped; tapping star 4 picks 1–4',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bookings = _FakeBookings();
      final tel = _Tel();
      await tester.pumpWidget(_host(bookings: bookings, tel: tel));
      await tester.pumpAndSettle();
      // Submit while 0 stars -> no call.
      await tester.tap(find.text('Submit rating'));
      await tester.pumpAndSettle();
      expect(bookings.ratings, isEmpty);
      // Tap the 4th star.
      final stars = find.byIcon(Icons.star_border);
      expect(stars, findsNWidgets(5));
      await tester.tap(stars.at(3));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      // Submit with 4 stars.
      await tester.tap(find.text('Submit rating'));
      await tester.pumpAndSettle();
      expect(bookings.ratings.length, 1);
      expect(bookings.ratings.single.$2.score, 4);
    },
  );
}
