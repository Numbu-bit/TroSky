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

/// A trip as the live backend sends it: no G20 or G21 fields.
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
    return Ok(
      Paginated(
        items: trips.skip(query.offset).take(query.limit).toList(),
        total: trips.length,
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
