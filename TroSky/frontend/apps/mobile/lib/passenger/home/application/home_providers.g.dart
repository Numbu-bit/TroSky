// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(locationService)
final locationServiceProvider = LocationServiceProvider._();

final class LocationServiceProvider
    extends
        $FunctionalProvider<LocationService, LocationService, LocationService>
    with $Provider<LocationService> {
  LocationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationServiceHash();

  @$internal
  @override
  $ProviderElement<LocationService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocationService create(Ref ref) {
    return locationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationService>(value),
    );
  }
}

String _$locationServiceHash() => r'33637312fa510b0662eebf6c32e8e62519b7c7c3';

@ProviderFor(homeStore)
final homeStoreProvider = HomeStoreProvider._();

final class HomeStoreProvider
    extends $FunctionalProvider<HomeStore, HomeStore, HomeStore>
    with $Provider<HomeStore> {
  HomeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeStoreHash();

  @$internal
  @override
  $ProviderElement<HomeStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HomeStore create(Ref ref) {
    return homeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeStore>(value),
    );
  }
}

String _$homeStoreHash() => r'2cf080534ffa46392a8ec7c3667c7143592d7173';

/// Makes the tile source for one map. A [TileLayer] disposes its provider,
/// so every map gets a new one.
///
/// Tiles are cached on the phone (flutter_map's built-in cache) for 30 days
/// whatever the server says, up to 100 MB, for low data (Part 2).

@ProviderFor(mapTileProviderFactory)
final mapTileProviderFactoryProvider = MapTileProviderFactoryProvider._();

/// Makes the tile source for one map. A [TileLayer] disposes its provider,
/// so every map gets a new one.
///
/// Tiles are cached on the phone (flutter_map's built-in cache) for 30 days
/// whatever the server says, up to 100 MB, for low data (Part 2).

final class MapTileProviderFactoryProvider
    extends
        $FunctionalProvider<
          TileProvider Function(),
          TileProvider Function(),
          TileProvider Function()
        >
    with $Provider<TileProvider Function()> {
  /// Makes the tile source for one map. A [TileLayer] disposes its provider,
  /// so every map gets a new one.
  ///
  /// Tiles are cached on the phone (flutter_map's built-in cache) for 30 days
  /// whatever the server says, up to 100 MB, for low data (Part 2).
  MapTileProviderFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapTileProviderFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapTileProviderFactoryHash();

  @$internal
  @override
  $ProviderElement<TileProvider Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TileProvider Function() create(Ref ref) {
    return mapTileProviderFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TileProvider Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TileProvider Function()>(value),
    );
  }
}

String _$mapTileProviderFactoryHash() =>
    r'd3d31e3ba5d93b20712b338584787a3239640e89';

/// The passenger's location for Home. It never blocks the screen: until
/// it settles, and whenever it is refused, Home centres on [accra].

@ProviderFor(LocationController)
final locationControllerProvider = LocationControllerProvider._();

/// The passenger's location for Home. It never blocks the screen: until
/// it settles, and whenever it is refused, Home centres on [accra].
final class LocationControllerProvider
    extends $NotifierProvider<LocationController, LocationState> {
  /// The passenger's location for Home. It never blocks the screen: until
  /// it settles, and whenever it is refused, Home centres on [accra].
  LocationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationControllerHash();

  @$internal
  @override
  LocationController create() => LocationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationState>(value),
    );
  }
}

String _$locationControllerHash() =>
    r'9d2170661ce4dcf8bf4424600d6d7aeb05d4104b';

/// The passenger's location for Home. It never blocks the screen: until
/// it settles, and whenever it is refused, Home centres on [accra].

abstract class _$LocationController extends $Notifier<LocationState> {
  LocationState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LocationState, LocationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LocationState, LocationState>,
              LocationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The stop nearest the passenger, for the location chip; null when the
/// position is unknown or nothing is near (the chip then says "Accra").
///
/// The last answer is kept: near the same spot it is reused without a
/// request, and it covers for a failed one.

@ProviderFor(nearestStop)
final nearestStopProvider = NearestStopProvider._();

/// The stop nearest the passenger, for the location chip; null when the
/// position is unknown or nothing is near (the chip then says "Accra").
///
/// The last answer is kept: near the same spot it is reused without a
/// request, and it covers for a failed one.

final class NearestStopProvider
    extends
        $FunctionalProvider<
          AsyncValue<NearbyStopResponse?>,
          NearbyStopResponse?,
          FutureOr<NearbyStopResponse?>
        >
    with
        $FutureModifier<NearbyStopResponse?>,
        $FutureProvider<NearbyStopResponse?> {
  /// The stop nearest the passenger, for the location chip; null when the
  /// position is unknown or nothing is near (the chip then says "Accra").
  ///
  /// The last answer is kept: near the same spot it is reused without a
  /// request, and it covers for a failed one.
  NearestStopProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'nearestStopProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nearestStopHash();

  @$internal
  @override
  $FutureProviderElement<NearbyStopResponse?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NearbyStopResponse?> create(Ref ref) {
    return nearestStop(ref);
  }
}

String _$nearestStopHash() => r'1f61dc7a7aecbf720db4a82159c703a33ab7070c';

/// The signed-in passenger's favourite routes (backend gap G4). After a
/// failure it falls back to the last list saved on the phone; with none
/// saved, the error shows with a Retry.

@ProviderFor(favouriteRoutes)
final favouriteRoutesProvider = FavouriteRoutesProvider._();

/// The signed-in passenger's favourite routes (backend gap G4). After a
/// failure it falls back to the last list saved on the phone; with none
/// saved, the error shows with a Retry.

final class FavouriteRoutesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FavouriteRouteResponse>>,
          List<FavouriteRouteResponse>,
          FutureOr<List<FavouriteRouteResponse>>
        >
    with
        $FutureModifier<List<FavouriteRouteResponse>>,
        $FutureProvider<List<FavouriteRouteResponse>> {
  /// The signed-in passenger's favourite routes (backend gap G4). After a
  /// failure it falls back to the last list saved on the phone; with none
  /// saved, the error shows with a Retry.
  FavouriteRoutesProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'favouriteRoutesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favouriteRoutesHash();

  @$internal
  @override
  $FutureProviderElement<List<FavouriteRouteResponse>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FavouriteRouteResponse>> create(Ref ref) {
    return favouriteRoutes(ref);
  }
}

String _$favouriteRoutesHash() => r'9507e0150cc074ef6e9d7d372f4afb265b854f47';

/// Vehicles near [centre] for the map (decision 14): invented ones in mock
/// mode only, real ones from `GET /vehicles/nearby` in live mode.

@ProviderFor(nearbyVehicles)
final nearbyVehiclesProvider = NearbyVehiclesFamily._();

/// Vehicles near [centre] for the map (decision 14): invented ones in mock
/// mode only, real ones from `GET /vehicles/nearby` in live mode.

final class NearbyVehiclesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NearbyVehicleResponse>>,
          List<NearbyVehicleResponse>,
          FutureOr<List<NearbyVehicleResponse>>
        >
    with
        $FutureModifier<List<NearbyVehicleResponse>>,
        $FutureProvider<List<NearbyVehicleResponse>> {
  /// Vehicles near [centre] for the map (decision 14): invented ones in mock
  /// mode only, real ones from `GET /vehicles/nearby` in live mode.
  NearbyVehiclesProvider._({
    required NearbyVehiclesFamily super.from,
    required LatLng super.argument,
  }) : super(
         retry: noRetry,
         name: r'nearbyVehiclesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nearbyVehiclesHash();

  @override
  String toString() {
    return r'nearbyVehiclesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<NearbyVehicleResponse>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<NearbyVehicleResponse>> create(Ref ref) {
    final argument = this.argument as LatLng;
    return nearbyVehicles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NearbyVehiclesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nearbyVehiclesHash() => r'd3220a6ac76d56cc9204d91553dbe25ed9a6eba7';

/// Vehicles near [centre] for the map (decision 14): invented ones in mock
/// mode only, real ones from `GET /vehicles/nearby` in live mode.

final class NearbyVehiclesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<NearbyVehicleResponse>>,
          LatLng
        > {
  NearbyVehiclesFamily._()
    : super(
        retry: noRetry,
        name: r'nearbyVehiclesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Vehicles near [centre] for the map (decision 14): invented ones in mock
  /// mode only, real ones from `GET /vehicles/nearby` in live mode.

  NearbyVehiclesProvider call(LatLng centre) =>
      NearbyVehiclesProvider._(argument: centre, from: this);

  @override
  String toString() => r'nearbyVehiclesProvider';
}
