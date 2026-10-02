import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../app/app_providers.dart';
import '../data/home_store.dart';
import '../data/location_service.dart';

part 'home_providers.g.dart';

/// Where the map centres without the passenger's position: the middle of
/// the area P5's map embeds (bbox -0.23,5.55 → -0.14,5.64).
const LatLng accra = LatLng(5.595, -0.185);

/// The Home map's zoom: Accra's neighbourhoods, as in the design.
const double homeMapZoom = 13;

/// Vehicles are fetched this far out: the corners of the map at
/// [homeMapZoom].
const int vehiclesRadiusM = 4000;

/// A stop found for a point is reused within this distance, so standing
/// still costs no data.
const double nearbyStopReuseMeters = 200;

/// A saved stop answers for a day; after that it is asked again.
const Duration nearbyStopMaxAge = Duration(days: 1);

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => const GeolocatorLocationService();

@Riverpod(keepAlive: true)
HomeStore homeStore(Ref ref) =>
    SharedPreferencesHomeStore(SharedPreferencesAsync());

/// Makes the tile source for one map. A [TileLayer] disposes its provider,
/// so every map gets a new one.
///
/// Tiles are cached on the phone (flutter_map's built-in cache) for 30 days
/// whatever the server says, up to 100 MB, for low data (Part 2).
@Riverpod(keepAlive: true)
TileProvider Function() mapTileProviderFactory(Ref ref) =>
    () => NetworkTileProvider(
      cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: 100 * 1000 * 1000,
        overrideFreshAge: const Duration(days: 30),
      ),
    );

/// How far Home got with the phone's location.
enum LocationAccess {
  /// Asking the phone what is allowed.
  checking,

  /// Never asked: Home explains, then asks (once).
  notAsked,
  granted,
  denied,
  deniedForever,

  /// Allowed, but the phone's location is switched off.
  serviceOff,
}

/// What the my-location button found.
enum LocateOutcome { located, notFound, denied, blocked, serviceOff }

@immutable
class LocationState {
  const LocationState(this.access, {this.position, this.locating = false});

  final LocationAccess access;

  /// The passenger's position, once known.
  final LatLng? position;

  /// Waiting for a fix.
  final bool locating;

  /// Whether the map can stop waiting for a position.
  bool get settled =>
      access != LocationAccess.checking && !(locating && position == null);
}

/// The passenger's location for Home. It never blocks the screen: until
/// it settles, and whenever it is refused, Home centres on [accra].
@Riverpod(keepAlive: true)
class LocationController extends _$LocationController {
  @override
  LocationState build() {
    unawaited(_start());
    return const LocationState(LocationAccess.checking);
  }

  LocationService get _service => ref.read(locationServiceProvider);
  HomeStore get _store => ref.read(homeStoreProvider);

  Future<void> _start() async {
    switch (await _service.checkPermission()) {
      case LocationPermissionStatus.granted:
        await _locate();
      case LocationPermissionStatus.denied:
        state = LocationState(
          await _store.locationAsked()
              ? LocationAccess.denied
              : LocationAccess.notAsked,
        );
      case LocationPermissionStatus.deniedForever:
        state = const LocationState(LocationAccess.deniedForever);
    }
  }

  /// "Allow location" on Home's explanation: the phone's dialog next.
  Future<void> allow() async {
    await _store.markLocationAsked();
    await _request();
  }

  /// "Not now", or the explanation dismissed: Home stays on Accra.
  Future<void> notNow() async {
    await _store.markLocationAsked();
    state = const LocationState(LocationAccess.denied);
  }

  /// The my-location button: a fresh fix, asking for permission first if
  /// the passenger refused before (they asked for it now).
  Future<LocateOutcome> locate() async {
    switch (state.access) {
      case LocationAccess.checking:
        return LocateOutcome.notFound;
      case LocationAccess.granted || LocationAccess.serviceOff:
        return _locate();
      case LocationAccess.notAsked || LocationAccess.denied:
        await _store.markLocationAsked();
        return _request();
      case LocationAccess.deniedForever:
        return LocateOutcome.blocked;
    }
  }

  Future<LocateOutcome> _request() async {
    switch (await _service.requestPermission()) {
      case LocationPermissionStatus.granted:
        return _locate();
      case LocationPermissionStatus.denied:
        state = const LocationState(LocationAccess.denied);
        return LocateOutcome.denied;
      case LocationPermissionStatus.deniedForever:
        state = const LocationState(LocationAccess.deniedForever);
        return LocateOutcome.blocked;
    }
  }

  /// The last fix at once, then a fresh one.
  Future<LocateOutcome> _locate() async {
    if (!await _service.serviceEnabled()) {
      state = const LocationState(LocationAccess.serviceOff);
      return LocateOutcome.serviceOff;
    }
    final before = state.position;
    state = LocationState(
      LocationAccess.granted,
      position: before,
      locating: true,
    );
    final last = await _service.lastKnownPosition();
    if (last != null && before == null) {
      state = LocationState(
        LocationAccess.granted,
        position: last,
        locating: true,
      );
    }
    final current = await _service.currentPosition();
    final position = current ?? state.position;
    state = LocationState(LocationAccess.granted, position: position);
    return current != null || last != null
        ? LocateOutcome.located
        : LocateOutcome.notFound;
  }
}

/// The stop nearest the passenger, for the location chip; null when the
/// position is unknown or nothing is near (the chip then says "Accra").
///
/// The last answer is kept: near the same spot it is reused without a
/// request, and it covers for a failed one.
@Riverpod(retry: noRetry)
Future<NearbyStopResponse?> nearestStop(Ref ref) async {
  final position = ref.watch(
    locationControllerProvider.select((s) => s.position),
  );
  if (position == null) return null;
  final store = ref.read(homeStoreProvider);
  final now = ref.read(clockProvider)();
  const distance = Distance();

  final cached = await store.readNearbyStop();
  final near =
      cached != null &&
      distance(cached.position, position) <= nearbyStopReuseMeters;
  if (near && now.difference(cached.savedAt) < nearbyStopMaxAge) {
    return cached.stop;
  }

  final result = await ref
      .read(routeRepositoryProvider)
      .nearbyStops(
        latitude: position.latitude,
        longitude: position.longitude,
        limit: 1,
      );
  switch (result) {
    case Ok(:final value):
      final stop = value.firstOrNull;
      await store.writeNearbyStop(
        CachedNearbyStop(position: position, stop: stop, savedAt: now),
      );
      return stop;
    case Err():
      // Offline or failing: an older answer for this spot beats "Accra".
      return near ? cached.stop : null;
  }
}

/// The signed-in passenger's favourite routes (backend gap G4). After a
/// failure it falls back to the last list saved on the phone; with none
/// saved, the error shows with a Retry.
@Riverpod(retry: noRetry)
Future<List<FavouriteRouteResponse>> favouriteRoutes(Ref ref) async {
  // Fetch again when the session comes back online (decision 9).
  final signedIn = ref.watch(
    sessionControllerProvider.select(
      (session) => switch (session.value) {
        SessionAuthenticated(:final user, :final offline) => (user.id, offline),
        _ => null,
      },
    ),
  );
  if (signedIn == null) return const [];
  final (userId, _) = signedIn;
  final store = ref.read(homeStoreProvider);
  final result = await ref.read(userRepositoryProvider).listFavouriteRoutes();
  switch (result) {
    case Ok(:final value):
      await store.writeFavourites(userId, value);
      return value;
    case Err(:final failure):
      final saved = await store.readFavourites(userId);
      if (saved != null) return saved;
      throw failure;
  }
}

/// Vehicles near [centre] for the map (decision 14): invented ones in mock
/// mode only, real ones from `GET /vehicles/nearby` in live mode.
@Riverpod(retry: noRetry)
Future<List<NearbyVehicleResponse>> nearbyVehicles(
  Ref ref,
  LatLng centre,
) async {
  final result = await ref
      .read(trackingRepositoryProvider)
      .nearbyVehicles(
        latitude: centre.latitude,
        longitude: centre.longitude,
        radiusM: vehiclesRadiusM,
      );
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}
