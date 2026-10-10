import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../helpers/fakes.dart';

/// Next to the Madina stop.
const LatLng nearMadina = LatLng(5.6735, -0.1660);

/// Kumasi: no stop near.
const LatLng kumasi = LatLng(6.6885, -1.6244);

/// The app restored as the seeded passenger (Ama Mensah): Home.
///
/// Animations are off (the phone's "remove animations"), so the pulsing
/// location dot stands still and pumpAndSettle can settle.
Future<TestWorld> openHome(
  WidgetTester tester, {
  TestWorld? world,
  Size size = const Size(360, 806),
  Env? env,
  List<Object> overrides = const [],
}) async {
  setScreenSize(tester, size);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final w = world ?? TestWorld();
  if (w.tokens.token == null) w.savePassengerSession();
  await tester.pumpWidget(testApp(world: w, env: env, overrides: overrides));
  await tester.pump(splashMinimumDuration);
  await tester.pumpAndSettle();
  return w;
}

/// Live mode (decision 14), with every repository on the mock backend
/// except vehicles, which come from [tracking].
({Env env, List<Object> overrides}) liveMode(
  TestWorld world,
  TrackingRepository tracking, {
  RouteRepository? routes,
  BookingRepository? bookings,
}) => (
  env: Env.parse(
    apiBaseUrl: 'http://localhost:8000/api/v1',
    wsBaseUrl: '',
    apiMode: 'live',
  ),
  overrides: [
    authRepositoryProvider.overrideWith(
      (ref) => MockAuthRepository(
        world.backend,
        tokens: () => ref.read(tokenManagerProvider),
      ),
    ),
    userRepositoryProvider.overrideWith(
      (ref) => MockUserRepository(
        world.backend,
        tokens: () => ref.read(tokenManagerProvider),
      ),
    ),
    routeRepositoryProvider.overrideWith(
      (ref) => routes ?? MockRouteRepository(world.backend),
    ),
    driverRepositoryProvider.overrideWith(
      (ref) => MockDriverRepository(
        world.backend,
        tokens: () => ref.read(tokenManagerProvider),
      ),
    ),
    trackingRepositoryProvider.overrideWithValue(tracking),
    bookingRepositoryProvider.overrideWith(
      (ref) =>
          bookings ??
          MockBookingRepository(
            world.backend,
            tokens: () => ref.read(tokenManagerProvider),
          ),
    ),
  ],
);

/// `GET /vehicles/nearby` answering [vehicles], or failing [failures]
/// times first.
class FakeTracking implements TrackingRepository {
  FakeTracking(this.vehicles, {this.failures = 0});

  final List<NearbyVehicleResponse> vehicles;
  int failures;
  int calls = 0;

  @override
  Future<Result<List<NearbyVehicleResponse>>> nearbyVehicles({
    required double latitude,
    required double longitude,
    required int radiusM,
    int limit = 20,
  }) async {
    calls++;
    if (failures > 0) {
      failures--;
      return const Err(NetworkFailure());
    }
    return Ok(vehicles);
  }
}

/// A vehicle a real backend could report.
NearbyVehicleResponse liveVehicle({int seats = 9}) => NearbyVehicleResponse(
  tripId: 't-live',
  vehicleId: 'v-live',
  vehicleRegistrationNumber: 'GW 5521-25',
  vehicleType: VehicleType.bus,
  routeId: 'r-live',
  routeName: 'Circle → Madina',
  latitude: 5.597,
  longitude: -0.184,
  distanceM: 230,
  availableSeats: seats,
  updatedAt: DateTime.utc(2026, 10, 1, 9),
);

/// The user repository with `listFavouriteRoutes` failing [failures] times
/// before it works.
class FlakyFavourites implements UserRepository {
  FlakyFavourites(this._inner, {this.failures = 1});

  final UserRepository _inner;
  int failures;

  @override
  Future<Result<UserResponse>> getMe() => _inner.getMe();

  @override
  Future<Result<FavouriteRouteResponse>> addFavouriteRoute(
    FavouriteRouteCreateRequest request,
  ) => _inner.addFavouriteRoute(request);

  @override
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes() async {
    if (failures > 0) {
      failures--;
      return const Err(NetworkFailure());
    }
    return _inner.listFavouriteRoutes();
  }
}

/// [UserRepository] override using [wrap] around the mock one.
Object wrapUserRepository(
  TestWorld world,
  UserRepository Function(UserRepository mock) wrap,
) => userRepositoryProvider.overrideWith(
  (ref) => wrap(
    MockUserRepository(
      world.backend,
      tokens: () => ref.read(tokenManagerProvider),
    ),
  ),
);

/// Taps the widget a screen reader calls [label].
Future<void> tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

/// Riverpod's container, to read providers in a test.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
