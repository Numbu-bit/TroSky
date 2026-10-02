import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../app/app_providers.dart';
import '../../home/application/home_providers.dart';
import '../data/search_history_store.dart';
import '../domain/journey.dart';

part 'search_providers.g.dart';

/// Wait this long after the last keystroke before searching stops.
const Duration stopSearchDebounce = Duration(milliseconds: 300);

/// Stop names are searched from this many characters (the backend's
/// minimum).
const int stopSearchMinLength = 2;

/// Trips per page of results.
const int tripsPageSize = 20;

@Riverpod(keepAlive: true)
SearchHistoryStore searchHistoryStore(Ref ref) =>
    SharedPreferencesSearchHistoryStore(SharedPreferencesAsync());

/// The last [SearchHistoryStore.max] searches, newest first.
@Riverpod(keepAlive: true)
class SearchHistory extends _$SearchHistory {
  @override
  Future<List<RecentSearch>> build() =>
      ref.watch(searchHistoryStoreProvider).read();

  /// Puts [search] first, without repeats.
  Future<void> add(RecentSearch search) async {
    final current = await future;
    final next = [
      search,
      ...current.where((s) => s != search),
    ].take(SearchHistoryStore.max).toList();
    state = AsyncData(next);
    await ref.read(searchHistoryStoreProvider).write(next);
  }
}

/// Stops whose name contains [query] (`GET /stops?q=`). The screen waits
/// [stopSearchDebounce] before asking.
@Riverpod(retry: noRetry)
Future<List<StopResponse>> stopSearch(Ref ref, String query) async =>
    switch (await ref.read(routeRepositoryProvider).searchStops(query)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };

/// Stops within walking distance of the passenger, to choose a pickup.
@Riverpod(retry: noRetry)
Future<List<NearbyStopResponse>> nearbyStopList(Ref ref) async {
  final position = ref.watch(
    locationControllerProvider.select((s) => s.position),
  );
  if (position == null) return const [];
  final result = await ref
      .read(routeRepositoryProvider)
      .nearbyStops(
        latitude: position.latitude,
        longitude: position.longitude,
        limit: 5,
      );
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

/// The phone gave no position for a "Current location" search.
class LocationUnavailable implements Exception {
  const LocationUnavailable();
}

/// The loaded part of a search's results.
@immutable
class TripResults {
  const TripResults({
    required this.trips,
    required this.total,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// In the backend's order: earliest departure first.
  final List<TripSearchResultResponse> trips;
  final int total;
  final bool loadingMore;
  final AppFailure? loadMoreError;

  bool get hasMore => trips.length < total;

  TripResults copyWith({bool? loadingMore, AppFailure? loadMoreError}) =>
      TripResults(
        trips: trips,
        total: total,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// The results of [search] (`GET /trips/search`), a page at a time.
///
/// Fails with an [AppFailure] (e.g. 422 `NO_PICKUP_NEARBY`) or
/// [LocationUnavailable].
@Riverpod(retry: noRetry)
class TripResultsController extends _$TripResultsController {
  late TripSearchQuery _query;

  @override
  Future<TripResults> build(JourneySearch search) async {
    _query = await _queryFor(search);
    final result = await ref.read(routeRepositoryProvider).searchTrips(_query);
    return switch (result) {
      Ok(:final value) => TripResults(trips: value.items, total: value.total),
      Err(:final failure) => throw failure,
    };
  }

  /// The next page, after the loaded ones. A failure stays on the state
  /// ([TripResults.loadMoreError]); calling again retries.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    final result = await ref
        .read(routeRepositoryProvider)
        .searchTrips(_query.copyWith(offset: current.trips.length));
    // A refresh meanwhile started over: this page belongs to the old list.
    if (!ref.mounted || !identical(state.value?.trips, current.trips)) return;
    state = AsyncData(switch (result) {
      Ok(:final value) => TripResults(
        trips: [...current.trips, ...value.items],
        total: value.total,
      ),
      Err(:final failure) => current.copyWith(loadMoreError: failure),
    });
  }

  Future<TripSearchQuery> _queryFor(JourneySearch search) async {
    final at = (search.when.at ?? ref.read(clockProvider)()).toUtc();
    double? latitude;
    double? longitude;
    String? originStopId;
    switch (search.origin) {
      case StopOrigin(:final stop):
        originStopId = stop.id;
      case CurrentLocationOrigin():
        var position = ref.read(locationControllerProvider).position;
        if (position == null) {
          await ref.read(locationControllerProvider.notifier).locate();
          position = ref.read(locationControllerProvider).position;
        }
        if (position == null) throw const LocationUnavailable();
        latitude = position.latitude;
        longitude = position.longitude;
    }
    return TripSearchQuery(
      originStopId: originStopId,
      destinationStopId: search.destination.id,
      travelDate: DateTime.utc(at.year, at.month, at.day),
      departureAfter: Duration(hours: at.hour, minutes: at.minute),
      pickupLatitude: latitude,
      pickupLongitude: longitude,
      limit: tripsPageSize,
    );
  }
}
