// Widget tests for P-11. The real WS/polling pipe is replaced by a
// mock TripTrackingService so the test runs offline and deterministic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/tracking/application/tracking_providers.dart';
import 'package:mobile/passenger/tracking/data/trip_tracking_service.dart';
import 'package:mobile/passenger/tracking/domain/track_trip_args.dart';
import 'package:mobile/passenger/tracking/presentation/track_trip_screen.dart';
import 'package:trosky_api/trosky_api.dart';

class _MockService implements TripTrackingService {
  _MockService(this._updates);
  final List<TripTrackingUpdate> _updates;
  final _controller = StreamController<TripTrackingUpdate>.broadcast();

  int pauseCount = 0;
  int resumeCount = 0;

  @override
  Stream<TripTrackingUpdate> start(String tripId) {
    // Emit as a microtask so listeners attach first.
    scheduleMicrotask(() {
      for (final u in _updates) {
        _controller.add(u);
      }
    });
    return _controller.stream;
  }

  @override
  void pause() => pauseCount++;

  @override
  void resume() => resumeCount++;

  @override
  void dispose() {
    _controller.close();
  }
}

class _RecordingTelemetry implements TelemetryService {
  final events = <TelemetryEvent>[];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

BookingResponse _booking() => BookingResponse(
  id: 'b1',
  bookingReference: 'TRK-TEST',
  tripId: 't1',
  status: BookingStatus.confirmed,
  passengerCount: 1,
  fareAmount: '6.00',
  platformFee: '0.00',
  totalAmount: '6.00',
  createdAt: DateTime.utc(2026, 11, 17),
  passengers: const [
    BookingPassengerResponse(id: 'p1', seatId: '4', fullName: 'Kofi Mensah'),
  ],
  trip: BookingTripSummaryResponse(
    scheduledDepartureAt: DateTime.utc(2026, 11, 17, 8, 30),
    routeName: 'Madina → Circle',
    originStopName: 'Madina',
    destinationStopName: 'Circle',
    status: TripStatus.inProgress,
  ),
);

TripDetailResponse _trip() => TripDetailResponse(
  id: 't1',
  routeId: 'r1',
  scheduledDepartureAt: DateTime.utc(2026, 11, 17, 8, 30),
  status: TripStatus.inProgress,
  fareAmount: '12.00',
  routeName: 'Madina - Circle',
  originStopId: 's1',
  originStopName: 'Madina',
  destinationStopId: 's2',
  destinationStopName: 'Circle',
  vehicle: const TripVehicleResponse(
    registrationNumber: 'GR-4821',
    type: VehicleType.minibus,
    makeModel: 'Toyota Hiace',
    capacity: 15,
  ),
  driver: TripDriverResponse(
    id: 'd1',
    fullName: 'Kofi Mensah',
    avatarUrl: null,
    averageRating: 4.8,
    ratingCount: 112,
  ),
  ridersCount: 7,
  seatsTotal: 15,
  availableSeats: 8,
  stops: const [
    StopResponse(id: 's1', name: 'Madina', latitude: 5.66, longitude: -0.17),
    StopResponse(id: 's2', name: 'Circle', latitude: 5.56, longitude: -0.20),
  ],
);

Widget _host({
  required _MockService service,
  required TelemetryService telemetry,
  bool disableAnimations = false,
}) => ProviderScope(
  overrides: [
    tripTrackingServiceProvider('t1').overrideWithValue(service),
    telemetryProvider.overrideWithValue(telemetry),
  ],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: TrackTripScreen(
        args: TrackTripArgs(booking: _booking(), trip: _trip()),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders bottom-card elements from fixture', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final telemetry = _RecordingTelemetry();
    final service = _MockService([
      TripTrackingUpdate(
        location: LiveLocationResponse(
          tripId: 't1',
          latitude: 5.60,
          longitude: -0.19,
          recordedAt: DateTime.utc(2026, 11, 17, 8, 0),
          isStale: false,
          liveFarePerSeat: 11.50,
          ridersCount: 7,
          tripStatus: TripStatus.inProgress,
        ),
        source: TripTrackingSource.webSocket,
      ),
    ]);
    await tester.pumpWidget(_host(service: service, telemetry: telemetry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // Driver row.
    expect(find.text('Kofi Mensah'), findsOneWidget);
    // Three info tiles.
    expect(find.text('Live fare'), findsOneWidget);
    expect(find.text('Riders'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('7 / 15'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
    // Share + SOS buttons.
    expect(find.text('Share Trip'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    // Analytics event fires on open.
    expect(telemetry.events.any((e) => e.name == 'track_trip_opened'), isTrue);
  });

  testWidgets('SOS button opens the placeholder sheet with Call 191', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final telemetry = _RecordingTelemetry();
    final service = _MockService(const []);
    await tester.pumpWidget(_host(service: service, telemetry: telemetry));
    await tester.pump();
    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Call 191'), findsOneWidget);
    expect(
      telemetry.events.any((e) => e.name == 'track_trip_sos_tapped'),
      isTrue,
    );
  });

  test('analytics events contain no PII (schema assertion)', () {
    final events = [
      TelemetryEvent('track_trip_opened'),
      TelemetryEvent('track_trip_ws_connected'),
      TelemetryEvent('track_trip_ws_fallback_to_poll', {'after_seconds': 5}),
      TelemetryEvent('track_trip_recenter_tapped'),
      TelemetryEvent('track_trip_share_tapped'),
      TelemetryEvent('track_trip_sos_tapped'),
      TelemetryEvent('track_trip_call_driver_tapped'),
      TelemetryEvent('track_trip_message_driver_tapped'),
    ];
    for (final e in events) {
      expect(e.sanitised, e.params, reason: '${e.name} loses no field');
      // Explicit allowed-key check: nothing that smells like PII.
      for (final k in e.params.keys) {
        expect(
          RegExp(
            r'token|phone|name|email|lat|lng|coord|address',
          ).hasMatch(k.toLowerCase()),
          isFalse,
          reason: '${e.name}.$k',
        );
      }
    }
  });
}
