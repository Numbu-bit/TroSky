// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchHistoryStore)
final searchHistoryStoreProvider = SearchHistoryStoreProvider._();

final class SearchHistoryStoreProvider
    extends
        $FunctionalProvider<
          SearchHistoryStore,
          SearchHistoryStore,
          SearchHistoryStore
        >
    with $Provider<SearchHistoryStore> {
  SearchHistoryStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchHistoryStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchHistoryStoreHash();

  @$internal
  @override
  $ProviderElement<SearchHistoryStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SearchHistoryStore create(Ref ref) {
    return searchHistoryStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchHistoryStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchHistoryStore>(value),
    );
  }
}

String _$searchHistoryStoreHash() =>
    r'ba4c2f4ba0f832887af82019773ad0e5b15e4f83';

/// The last [SearchHistoryStore.max] searches, newest first.

@ProviderFor(SearchHistory)
final searchHistoryProvider = SearchHistoryProvider._();

/// The last [SearchHistoryStore.max] searches, newest first.
final class SearchHistoryProvider
    extends $AsyncNotifierProvider<SearchHistory, List<RecentSearch>> {
  /// The last [SearchHistoryStore.max] searches, newest first.
  SearchHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchHistoryHash();

  @$internal
  @override
  SearchHistory create() => SearchHistory();
}

String _$searchHistoryHash() => r'8387b8d240235c57add23c2383fe1412283579b5';

/// The last [SearchHistoryStore.max] searches, newest first.

abstract class _$SearchHistory extends $AsyncNotifier<List<RecentSearch>> {
  FutureOr<List<RecentSearch>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<RecentSearch>>, List<RecentSearch>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<RecentSearch>>, List<RecentSearch>>,
              AsyncValue<List<RecentSearch>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Stops whose name contains [query] (`GET /stops?q=`). The screen waits
/// [stopSearchDebounce] before asking.

@ProviderFor(stopSearch)
final stopSearchProvider = StopSearchFamily._();

/// Stops whose name contains [query] (`GET /stops?q=`). The screen waits
/// [stopSearchDebounce] before asking.

final class StopSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StopResponse>>,
          List<StopResponse>,
          FutureOr<List<StopResponse>>
        >
    with
        $FutureModifier<List<StopResponse>>,
        $FutureProvider<List<StopResponse>> {
  /// Stops whose name contains [query] (`GET /stops?q=`). The screen waits
  /// [stopSearchDebounce] before asking.
  StopSearchProvider._({
    required StopSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: noRetry,
         name: r'stopSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$stopSearchHash();

  @override
  String toString() {
    return r'stopSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<StopResponse>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StopResponse>> create(Ref ref) {
    final argument = this.argument as String;
    return stopSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StopSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$stopSearchHash() => r'e6996747a1a2d5f318ea376d5a9cdd2632fdb439';

/// Stops whose name contains [query] (`GET /stops?q=`). The screen waits
/// [stopSearchDebounce] before asking.

final class StopSearchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<StopResponse>>, String> {
  StopSearchFamily._()
    : super(
        retry: noRetry,
        name: r'stopSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stops whose name contains [query] (`GET /stops?q=`). The screen waits
  /// [stopSearchDebounce] before asking.

  StopSearchProvider call(String query) =>
      StopSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'stopSearchProvider';
}

/// Stops within walking distance of the passenger, to choose a pickup.

@ProviderFor(nearbyStopList)
final nearbyStopListProvider = NearbyStopListProvider._();

/// Stops within walking distance of the passenger, to choose a pickup.

final class NearbyStopListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NearbyStopResponse>>,
          List<NearbyStopResponse>,
          FutureOr<List<NearbyStopResponse>>
        >
    with
        $FutureModifier<List<NearbyStopResponse>>,
        $FutureProvider<List<NearbyStopResponse>> {
  /// Stops within walking distance of the passenger, to choose a pickup.
  NearbyStopListProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'nearbyStopListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nearbyStopListHash();

  @$internal
  @override
  $FutureProviderElement<List<NearbyStopResponse>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<NearbyStopResponse>> create(Ref ref) {
    return nearbyStopList(ref);
  }
}

String _$nearbyStopListHash() => r'58040ebb09a6f4a6094e5f6b60ec40f008919ef0';

/// The results of a [ResultsRequest] (`GET /trips/search`), a page at a
/// time.
///
/// Fails with an [AppFailure] (e.g. 422 `NO_PICKUP_NEARBY`) or
/// [LocationUnavailable].

@ProviderFor(TripResultsController)
final tripResultsControllerProvider = TripResultsControllerFamily._();

/// The results of a [ResultsRequest] (`GET /trips/search`), a page at a
/// time.
///
/// Fails with an [AppFailure] (e.g. 422 `NO_PICKUP_NEARBY`) or
/// [LocationUnavailable].
final class TripResultsControllerProvider
    extends $AsyncNotifierProvider<TripResultsController, TripResults> {
  /// The results of a [ResultsRequest] (`GET /trips/search`), a page at a
  /// time.
  ///
  /// Fails with an [AppFailure] (e.g. 422 `NO_PICKUP_NEARBY`) or
  /// [LocationUnavailable].
  TripResultsControllerProvider._({
    required TripResultsControllerFamily super.from,
    required ResultsRequest super.argument,
  }) : super(
         retry: noRetry,
         name: r'tripResultsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tripResultsControllerHash();

  @override
  String toString() {
    return r'tripResultsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TripResultsController create() => TripResultsController();

  @override
  bool operator ==(Object other) {
    return other is TripResultsControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tripResultsControllerHash() =>
    r'a0cf78cafbdfcbe1ec5a0bcf4f6f8b395fce3c61';

/// The results of a [ResultsRequest] (`GET /trips/search`), a page at a
/// time.
///
/// Fails with an [AppFailure] (e.g. 422 `NO_PICKUP_NEARBY`) or
/// [LocationUnavailable].

final class TripResultsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TripResultsController,
          AsyncValue<TripResults>,
          TripResults,
          FutureOr<TripResults>,
          ResultsRequest
        > {
  TripResultsControllerFamily._()
    : super(
        retry: noRetry,
        name: r'tripResultsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The results of a [ResultsRequest] (`GET /trips/search`), a page at a
  /// time.
  ///
  /// Fails with an [AppFailure] (e.g. 422 `NO_PICKUP_NEARBY`) or
  /// [LocationUnavailable].

  TripResultsControllerProvider call(ResultsRequest request) =>
      TripResultsControllerProvider._(argument: request, from: this);

  @override
  String toString() => r'tripResultsControllerProvider';
}

/// The results of a [ResultsRequest] (`GET /trips/search`), a page at a
/// time.
///
/// Fails with an [AppFailure] (e.g. 422 `NO_PICKUP_NEARBY`) or
/// [LocationUnavailable].

abstract class _$TripResultsController extends $AsyncNotifier<TripResults> {
  late final _$args = ref.$arg as ResultsRequest;
  ResultsRequest get request => _$args;

  FutureOr<TripResults> build(ResultsRequest request);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TripResults>, TripResults>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TripResults>, TripResults>,
              AsyncValue<TripResults>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
