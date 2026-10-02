import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/tracking_dto.dart';

/// Live positions (backend/app/api/v1/tracking.py).
abstract interface class TrackingRepository {
  /// Vehicles out on a trip within [radiusM] (50–20 000) of the point,
  /// nearest first, from GPS pings at most 5 minutes old (backend gap G16).
  Future<Result<List<NearbyVehicleResponse>>> nearbyVehicles({
    required double latitude,
    required double longitude,
    required int radiusM,
    int limit = 20,
  });
}

/// [TrackingRepository] against the backend.
class LiveTrackingRepository implements TrackingRepository {
  LiveTrackingRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<NearbyVehicleResponse>>> nearbyVehicles({
    required double latitude,
    required double longitude,
    required int radiusM,
    int limit = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/vehicles/nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_m': radiusM,
        'limit': limit,
      },
    ),
    (data) => [
      for (final vehicle in data! as List)
        NearbyVehicleResponse.fromJson(jsonObject(vehicle)),
    ],
  );
}
