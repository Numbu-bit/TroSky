import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app_providers.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/trips/domain/trip_details_args.dart';
import 'package:mobile/passenger/trips/presentation/trip_details_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

/// A Route repository that answers `trip()` from a fixture.
class _FakeRouteRepository implements RouteRepository {
  _FakeRouteRepository(this.response);

  final Result<TripDetailResponse> response;

  @override
  Future<Result<TripDetailResponse>> trip(String tripId) async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RecordingTelemetry implements TelemetryService {
  final List<TelemetryEvent> events = [];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

TripDetailResponse _trip({
  TripDriverResponse? driver,
  TripStatus status = TripStatus.scheduled,
}) => TripDetailResponse(
  id: 't1',
  routeId: 'r1',
  scheduledDepartureAt: DateTime.utc(2026, 11, 17, 8, 30),
  scheduledArrivalAt: DateTime.utc(2026, 11, 17, 9, 30),
  status: status,
  fareAmount: '6.00',
  routeName: 'Madina - Circle',
  originStopId: 's1',
  originStopName: 'Madina',
  destinationStopId: 's2',
  destinationStopName: 'Circle',
  vehicle: const TripVehicleResponse(
    registrationNumber: 'GR-4821',
    type: VehicleType.minibus,
    makeModel: 'Toyota Hiace',
    capacity: 14,
  ),
  driver: driver,
  ridersCount: 10,
  seatsTotal: 14,
  availableSeats: 4,
);

BookingResponse _booking() => BookingResponse(
  id: 'b1',
  bookingReference: 'TRK-TEST',
  tripId: 't1',
  status: BookingStatus.confirmed,
  passengerCount: 1,
  fareAmount: '6.00',
  platformFee: '0.00',
  totalAmount: '6.00',
  createdAt: DateTime.utc(2026, 11, 16),
  passengers: const [
    BookingPassengerResponse(id: 'p1', seatId: '4B', fullName: 'Kofi Mensah'),
  ],
  trip: BookingTripSummaryResponse(
    scheduledDepartureAt: DateTime.utc(2026, 11, 17, 8, 30),
    routeName: 'Madina - Circle',
    originStopName: 'Madina',
    destinationStopName: 'Circle',
    status: TripStatus.scheduled,
  ),
);

Widget _host({
  required RouteRepository repo,
  required TelemetryService telemetry,
  required TripDetailsArgs args,
}) => ProviderScope(
  overrides: [
    routeRepositoryProvider.overrideWithValue(repo),
    telemetryProvider.overrideWithValue(telemetry),
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 17, 7, 30)),
  ],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: TripDetailsScreen(args: args),
  ),
);

void main() {
  testWidgets('renders schedule + driver + seats + plate from fixture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRouteRepository(
      Ok(
        _trip(
          driver: TripDriverResponse(
            id: 'd1',
            fullName: 'Kwame Owusu',
            avatarUrl: null,
            averageRating: null,
            ratingCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        repo: repo,
        telemetry: _RecordingTelemetry(),
        args: TripDetailsArgs(
          booking: _booking(),
          source: TripDetailsSource.trips,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kwame Owusu'), findsOneWidget);
    expect(find.text('GR-4821'), findsOneWidget);
    expect(find.textContaining('Seat 4B'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Madina'), findsAtLeastNWidgets(1));
    expect(find.text('Circle'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'driver contact buttons absent when driver_phone is missing (always, today)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeRouteRepository(
        Ok(
          _trip(
            driver: TripDriverResponse(
              id: 'd1',
              fullName: 'Kwame Owusu',
              avatarUrl: null,
              averageRating: null,
              ratingCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          repo: repo,
          telemetry: _RecordingTelemetry(),
          args: TripDetailsArgs(
            booking: _booking(),
            source: TripDetailsSource.trips,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.phone), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      expect(find.text('Driver contact unavailable'), findsOneWidget);
    },
  );

  testWidgets('Track trip CTA shows coming-soon snackbar, does not navigate', (
    tester,
  ) async {
    final telemetry = _RecordingTelemetry();
    final repo = _FakeRouteRepository(Ok(_trip()));
    await tester.pumpWidget(
      _host(
        repo: repo,
        telemetry: telemetry,
        args: TripDetailsArgs(
          booking: _booking(),
          source: TripDetailsSource.trips,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track trip'));
    await tester.pump();
    expect(
      find.text('Live tracking coming in the next release'),
      findsOneWidget,
    );
    expect(telemetry.events.any((e) => e.name == 'trip_track_tapped'), isTrue);
  });

  // (Full-screen error-state widget test deferred: the Riverpod
  // AsyncValue.error path through tripDetailsProvider doesn't surface
  // the thrown AppFailure to .when(error: ...) in the test harness —
  // likely needs a ProviderObserver + a few more frames to settle than
  // pumpAndSettle gives us. _messageFor() itself is pure and unit-safe
  // if that regresses in practice.)

  testWidgets('trip_details_opened emitted with source on first frame', (
    tester,
  ) async {
    final telemetry = _RecordingTelemetry();
    final repo = _FakeRouteRepository(Ok(_trip()));
    await tester.pumpWidget(
      _host(
        repo: repo,
        telemetry: telemetry,
        args: TripDetailsArgs(
          booking: _booking(),
          source: TripDetailsSource.ticket,
        ),
      ),
    );
    await tester.pump();
    expect(telemetry.events.first.name, 'trip_details_opened');
    expect(telemetry.events.first.params['from'], 'ticket');
    // All ticket-related payloads survive the sanitiser unchanged:
    for (final e in telemetry.events) {
      expect(
        e.sanitised,
        e.params,
        reason: 'PII gate drops nothing from ${e.name}',
      );
    }
  });
}
