import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/route_dto.dart';

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
}
