import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/search/presentation/search_results_screen.dart';
import 'package:mobile/passenger/search/presentation/search_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';
import '../home/home_helpers.dart';

/// Home, then the search bar: Search (P-02).
Future<TestWorld> openSearch(
  WidgetTester tester, {
  TestWorld? world,
  Size size = const Size(360, 806),
  Env? env,
  List<Object> overrides = const [],
}) async {
  final w = await openHome(
    tester,
    world: world,
    size: size,
    env: env,
    overrides: overrides,
  );
  await tapLabel(tester, 'Where are you going?, Now');
  expect(find.byType(SearchScreen), findsOneWidget);
  return w;
}

/// The From (`from`) or To (`to`) field.
Finder searchField(String field) => find.byKey(ValueKey('search-$field'));

/// Types [text] into the From (`from`) or To (`to`) field and waits out the
/// debounce.
Future<void> typeStop(WidgetTester tester, String field, String text) async {
  await tester.enterText(searchField(field), text);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Taps the stop [name] in the list under the fields (its row reads
/// "Circle, Accra" or "Madina, 50 m away").
Future<void> chooseStop(WidgetTester tester, String name) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^${RegExp.escape(name)}, ')));
  await tester.pumpAndSettle();
}

/// Taps the filter pill [label], scrolling the pill bar to it first.
Future<void> tapPill(WidgetTester tester, String label) async {
  final pill = find.widgetWithText(TroskyFilterPill, label);
  await tester.ensureVisible(pill);
  await tester.pumpAndSettle();
  await tester.tap(pill);
  await tester.pumpAndSettle();
}

/// Search with [from] and [to] chosen by name: Search Results.
Future<TestWorld> searchFor(
  WidgetTester tester,
  String from,
  String to, {
  TestWorld? world,
  List<Object> overrides = const [],
}) async {
  final w = await openSearch(
    tester,
    world: world ?? morning(),
    overrides: overrides,
  );
  await tester.tap(searchField('from'));
  await tester.pumpAndSettle();
  await typeStop(tester, 'from', from);
  await chooseStop(tester, from);
  await typeStop(tester, 'to', to);
  await chooseStop(tester, to);
  await tester.tap(find.text('Search').last);
  await tester.pumpAndSettle();
  return w;
}

/// A world at 09:00 on 1 Oct 2026, signed in as the seeded passenger.
TestWorld morning() => TestWorld()..now = DateTime(2026, 10, 1, 9);

/// The `fare` of a search result: [current] a seat, [solo] riding alone
/// (default: the same, no saving), the platform fee per seat.
FareSummaryResponse fareOf(
  String current, {
  String? solo,
  String minimum = '2.00',
  int seats = 1,
}) {
  final fee = 0.5 * seats;
  return FareSummaryResponse(
    current: current,
    solo: solo ?? current,
    minimum: minimum,
    platformFee: fee.toStringAsFixed(2),
    total: (double.parse(current) * seats + fee).toStringAsFixed(2),
    currency: 'GHS',
    ridersCount: 0,
    seats: seats,
  );
}

/// A trip as the live backend (0.13.0) sends it: [fare] for one seat with
/// no saving unless [solo] is given, not on the road yet.
TripSearchResultResponse liveTrip({
  required String id,
  required DateTime departs,
  int minutes = 45,
  String fare = '8.00',
  int seats = 12,
  VehicleType type = VehicleType.minibus,
  String plate = 'GT 4402-26',
  String? pickup = 'Accra Madina',
  double? walk = 350,
  String? solo,
}) => TripSearchResultResponse(
  tripId: id,
  routeId: 'r1',
  routeName: 'Madina - Circle',
  originStopId: 's1',
  destinationStopId: 's4',
  scheduledDepartureAt: departs.toUtc(),
  estimatedDurationMinutes: minutes,
  fareAmount: fare,
  status: TripStatus.scheduled,
  availableSeats: seats,
  vehicleRegistrationNumber: plate,
  vehicleType: type,
  pickupStopId: pickup == null ? null : 's1',
  pickupStopName: pickup,
  pickupDistanceM: walk,
  pickupSource: pickup == null ? null : PickupSource.gps,
  fare: fareOf(fare, solo: solo),
  rideMinutes: minutes,
);

/// `GET /trips/search` answering pages of [trips] (or failing [failures]
/// times first, or with [failure] every time), and recording the queries.
/// Stops come from the mock backend.
class ScriptedTrips implements RouteRepository {
  ScriptedTrips(
    this._backend,
    this.trips, {
    this.failures = 0,
    this.failure,
    Map<String, TripSeatsResponse>? seatMaps,
  }) : seatMaps = seatMaps ?? {};

  final MockBackend _backend;
  final List<TripSearchResultResponse> trips;
  int failures;
  final AppFailure? failure;
  final List<TripSearchQuery> queries = [];

  /// `GET /trips/{id}/seats` by trip id; change an entry to change what the
  /// next refresh sees.
  final Map<String, TripSeatsResponse> seatMaps;
  int seatRequests = 0;

  /// `GET /trips/{id}/fare-quote` by trip id: the [FareSummaryResponse] for
  /// one seat, scaled to the seats asked for. Without an entry, or with
  /// [quoteFailure], it fails.
  final Map<String, FareSummaryResponse> quotes = {};
  AppFailure? quoteFailure;
  final List<(String, String?, String?, int)> quoteRequests = [];

  @override
  Future<Result<Paginated<TripSearchResultResponse>>> searchTrips(
    TripSearchQuery query,
  ) async {
    queries.add(query);
    if (failure case final failure?) return Err(failure);
    if (failures > 0) {
      failures--;
      return const Err(NetworkFailure());
    }
    // As the backend: only [TripSearchQuery.vehicleType], in
    // [TripSearchQuery.sort] order, vehicles that passed the pickup last.
    final shown = [
      for (final (i, trip) in trips.indexed)
        if (query.vehicleType == null || trip.vehicleType == query.vehicleType)
          (i, trip),
    ];
    int key(TripSearchResultResponse a, TripSearchResultResponse b) =>
        switch (query.sort) {
          SearchSort.departure => 0,
          SearchSort.cheapest => double.parse(
            a.fare?.current ?? a.fareAmount,
          ).compareTo(double.parse(b.fare?.current ?? b.fareAmount)),
          SearchSort.fastest => (a.rideMinutes ?? 0).compareTo(
            b.rideMinutes ?? 0,
          ),
        };
    shown.sort((a, b) {
      if (a.$2.hasPassedPickup != b.$2.hasPassedPickup) {
        return a.$2.hasPassedPickup ? 1 : -1;
      }
      final byKey = key(a.$2, b.$2);
      return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
    });
    final ordered = [for (final (_, trip) in shown) trip];
    return Ok(
      Paginated(
        items: ordered.skip(query.offset).take(query.limit).toList(),
        total: ordered.length,
        limit: query.limit,
        offset: query.offset,
      ),
    );
  }

  @override
  Future<Result<List<StopResponse>>> searchStops(
    String query, {
    int limit = 20,
  }) async => _backend.searchStops(query, limit: limit);

  @override
  Future<Result<List<NearbyStopResponse>>> nearbyStops({
    required double latitude,
    required double longitude,
    int? radiusM,
    int? limit,
  }) async => _backend.nearbyStops(
    latitude: latitude,
    longitude: longitude,
    radiusM: radiusM,
    limit: limit,
  );

  @override
  Future<Result<FareQuoteResponse>> fareQuote(
    String tripId, {
    String? originStopId,
    String? destinationStopId,
    int seats = 1,
  }) async {
    quoteRequests.add((tripId, originStopId, destinationStopId, seats));
    if (quoteFailure case final failure?) return Err(failure);
    final fare = quotes[tripId];
    if (fare == null) {
      return const Err(
        NotFoundFailure(code: 'NOT_FOUND', message: 'Trip not found.'),
      );
    }
    final one = fareOf(
      fare.current,
      solo: fare.solo,
      minimum: fare.minimum,
      seats: seats,
    );
    return Ok(
      FareQuoteResponse(
        tripId: tripId,
        originStopId: originStopId ?? 's1',
        destinationStopId: destinationStopId ?? 's4',
        current: one.current,
        solo: one.solo,
        minimum: one.minimum,
        platformFee: one.platformFee,
        total: one.total,
        currency: one.currency,
        ridersCount: fare.ridersCount,
        seats: seats,
      ),
    );
  }

  @override
  Future<Result<TripDetailResponse>> trip(String tripId) async =>
      _backend.tripDetail(tripId);

  @override
  Future<Result<TripSeatsResponse>> tripSeats(String tripId) async {
    seatRequests++;
    return switch (seatMaps[tripId]) {
      final map? => Ok(map),
      null => const Err(
        NotFoundFailure(code: 'NOT_FOUND', message: 'Trip not found.'),
      ),
    };
  }
}

/// The mock's stop search, counting the requests.
class CountingStops extends ScriptedTrips {
  CountingStops(MockBackend backend) : super(backend, const []);

  final List<String> stopQueries = [];

  @override
  Future<Result<List<StopResponse>>> searchStops(
    String query, {
    int limit = 20,
  }) {
    stopQueries.add(query);
    return super.searchStops(query, limit: limit);
  }
}

/// Home → the "Madina → Circle" favourite: Search Results at once.
Future<TestWorld> openResults(
  WidgetTester tester, {
  TestWorld? world,
  Size size = const Size(360, 806),
  Env? env,
  List<Object> overrides = const [],
  String chip = 'Madina → Circle',
}) async {
  final w = await openHome(
    tester,
    world: world ?? morning(),
    size: size,
    env: env,
    overrides: overrides,
  );
  await tester.tap(find.text(chip));
  await tester.pumpAndSettle();
  expect(find.byType(SearchResultsScreen), findsOneWidget);
  return w;
}

/// Live mode with [routes] answering the search.
Future<TestWorld> openLiveResults(
  WidgetTester tester,
  TestWorld world,
  ScriptedTrips routes, {
  Size size = const Size(360, 806),
}) {
  final live = liveMode(world, FakeTracking(const []), routes: routes);
  return openResults(
    tester,
    world: world,
    size: size,
    env: live.env,
    overrides: live.overrides,
  );
}
