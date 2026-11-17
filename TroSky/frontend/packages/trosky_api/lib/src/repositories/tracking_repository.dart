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

  /// `GET /trips/{id}/location`: one location point (polling fallback for
  /// the WebSocket).
  Future<Result<LiveLocationResponse>> tripLocation(String tripId);

  /// `GET /trips/{id}/eta`: how far and how long to [destinationStopId]
  /// (default: the trip's destination).
  Future<Result<EtaResponse>> tripEta(
    String tripId, {
    String? destinationStopId,
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

  @override
  Future<Result<LiveLocationResponse>> tripLocation(String tripId) => apiCall(
    () => _dio.get<Object?>('/trips/$tripId/location'),
    (data) => LiveLocationResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<EtaResponse>> tripEta(
    String tripId, {
    String? destinationStopId,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/trips/$tripId/eta',
      queryParameters: destinationStopId == null
          ? null
          : {'destination_stop_id': destinationStopId},
    ),
    (data) => EtaResponse.fromJson(jsonObject(data)),
  );
}
