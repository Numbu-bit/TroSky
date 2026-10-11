import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/booking_dto.dart';
import '../dto/paginated.dart';
import '../dto/route_dto.dart';
import '../dto/tracking_dto.dart';

/// What to search for with `GET /trips/search`.
///
/// The pickup is [originStopId] when the passenger chose a stop, else the
/// phone's position ([pickupLatitude], [pickupLongitude]): the backend then
/// boards each trip at the nearest stop it serves, or answers 422
/// `NO_PICKUP_NEARBY` when no stop is within walking distance.
///
/// [travelDate] and the departure window are UTC, as the backend reads
/// them.
class TripSearchQuery {
  const TripSearchQuery({
    this.originStopId,
    this.destinationStopId,
    required this.travelDate,
    this.departureAfter,
    this.departureBefore,
    this.pickupLatitude,
    this.pickupLongitude,
    this.sort = SearchSort.departure,
    this.vehicleType,
    this.limit = 20,
    this.offset = 0,
  });

  final String? originStopId;
  final String? destinationStopId;

  /// The UTC date; its time is ignored.
  final DateTime travelDate;

  /// UTC time of day, e.g. 07:12.
  final Duration? departureAfter;
  final Duration? departureBefore;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final SearchSort sort;

  /// Only this kind of vehicle.
  final VehicleType? vehicleType;
  final int limit;
  final int offset;

  TripSearchQuery copyWith({int? offset}) => TripSearchQuery(
    originStopId: originStopId,
    destinationStopId: destinationStopId,
    travelDate: travelDate,
    departureAfter: departureAfter,
    departureBefore: departureBefore,
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
    sort: sort,
    vehicleType: vehicleType,
    limit: limit,
    offset: offset ?? this.offset,
  );

  /// The query string, with the backend's names and formats.
  Map<String, Object> toQueryParameters() => {
    'origin_stop_id': ?originStopId,
    'destination_stop_id': ?destinationStopId,
    'travel_date': _date(travelDate),
    if (departureAfter case final after?) 'departure_after': _time(after),
    if (departureBefore case final before?) 'departure_before': _time(before),
    'pickup_latitude': ?pickupLatitude,
    'pickup_longitude': ?pickupLongitude,
    if (sort != SearchSort.departure) 'sort': sort.name,
    'vehicle_type': ?vehicleType?.name,
    'limit': limit,
    'offset': offset,
  };

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String _time(Duration t) =>
      '${_two(t.inHours % 24)}:${_two(t.inMinutes % 60)}:'
      '${_two(t.inSeconds % 60)}';
}

/// Stops and routes (backend/app/api/v1/routes.py).
abstract interface class RouteRepository {
  /// Stops within [radiusM] of the point, nearest first. Empty when nothing
  /// is near, which is a normal answer. Without [radiusM] the backend uses
  /// its walking distance (`PICKUP_MAX_WALK_METERS`, 1 km).
  Future<Result<List<NearbyStopResponse>>> nearbyStops({
    required double latitude,
    required double longitude,
    int? radiusM,
    int? limit,
  });

  /// Stops whose name contains [query] (2 characters or more), by name.
  Future<Result<List<StopResponse>>> searchStops(
    String query, {
    int limit = 20,
  });

  /// Trips the passenger can take, one page at a time, in [TripSearchQuery.sort]
  /// order. Each carries its price from the pickup ([TripSearchResultResponse.fare]).
  Future<Result<Paginated<TripSearchResultResponse>>> searchTrips(
    TripSearchQuery query,
  );

  /// The trip vehicle's seats and which are free (public). 409 `CONFLICT`
  /// before a vehicle is assigned; 404 without a seat layout.
  Future<Result<TripSeatsResponse>> tripSeats(String tripId);

  /// What [seats] seats from [originStopId] to [destinationStopId] cost now
  /// (public): the amount `POST /bookings` would charge. Without stops, the
  /// route's start and end. 422 `STOP_NOT_ON_ROUTE`, 404 for an unknown
  /// trip.
  Future<Result<FareQuoteResponse>> fareQuote(
    String tripId, {
    String? originStopId,
    String? destinationStopId,
    int seats = 1,
  });
}

/// [RouteRepository] against the backend.
class LiveRouteRepository implements RouteRepository {
  LiveRouteRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<NearbyStopResponse>>> nearbyStops({
    required double latitude,
    required double longitude,
    int? radiusM,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/stops/nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_m': ?radiusM,
        'limit': ?limit,
      },
      // Public: stops show before the session is checked, too.
      options: publicEndpoint(),
    ),
    (data) => [
      for (final stop in data! as List)
        NearbyStopResponse.fromJson(jsonObject(stop)),
    ],
  );

  @override
  Future<Result<List<StopResponse>>> searchStops(
    String query, {
    int limit = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/stops',
      queryParameters: {'q': query.trim(), 'limit': limit},
      options: publicEndpoint(),
    ),
    (data) => Paginated.fromJson(jsonObject(data), StopResponse.fromJson).items,
  );

  @override
  Future<Result<Paginated<TripSearchResultResponse>>> searchTrips(
    TripSearchQuery query,
  ) => apiCall(
    () => _dio.get<Object?>(
      '/trips/search',
      queryParameters: query.toQueryParameters(),
      options: publicEndpoint(),
    ),
    (data) =>
        Paginated.fromJson(jsonObject(data), TripSearchResultResponse.fromJson),
  );

  @override
  Future<Result<TripSeatsResponse>> tripSeats(String tripId) => apiCall(
    () => _dio.get<Object?>('/trips/$tripId/seats', options: publicEndpoint()),
    (data) => TripSeatsResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<FareQuoteResponse>> fareQuote(
    String tripId, {
    String? originStopId,
    String? destinationStopId,
    int seats = 1,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/trips/$tripId/fare-quote',
      queryParameters: {
        'origin_stop_id': ?originStopId,
        'destination_stop_id': ?destinationStopId,
        'seats': seats,
      },
      options: publicEndpoint(),
    ),
    (data) => FareQuoteResponse.fromJson(jsonObject(data)),
  );
}
