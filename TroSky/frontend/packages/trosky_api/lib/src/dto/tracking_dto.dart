// Live vehicles, field for field as in backend/app/schemas/tracking.py.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_decimal.dart';
import 'route_dto.dart' show TripStatus;

part 'tracking_dto.freezed.dart';
part 'tracking_dto.g.dart';

/// `VehicleType` (backend/app/models/vehicles.py). A type added later reads
/// as [other].
@JsonEnum()
enum VehicleType { bus, minibus, shuttle, sedan, other }

/// `LiveLocationResponse` from `GET /trips/{id}/location` AND each WS
/// frame published on `/ws/trips/{id}/track`. Same shape both transports.
///
/// Coordinates are bearer-sensitive location data: never log, never in
/// telemetry.
@freezed
abstract class LiveLocationResponse with _$LiveLocationResponse {
  const factory LiveLocationResponse({
    required String tripId,
    required double latitude,
    required double longitude,
    @JsonKey(fromJson: decimalOrNull) double? speedKmh,
    @JsonKey(fromJson: decimalOrNull) double? headingDegrees,
    required DateTime recordedAt,
    required bool isStale,
    @JsonKey(unknownEnumValue: null) TripStatus? tripStatus,

    /// Current per-seat fare, split across confirmed riders (PR #89).
    /// Null only from a legacy cache before the backend was deployed.
    @JsonKey(fromJson: decimalOrNull) double? liveFarePerSeat,

    /// Count of confirmed/completed bookings on this trip. Null from a
    /// legacy cache.
    int? ridersCount,
  }) = _LiveLocationResponse;

  factory LiveLocationResponse.fromJson(Map<String, dynamic> json) =>
      _$LiveLocationResponseFromJson(json);
}

/// `EtaResponse` from `GET /trips/{id}/eta`.
@freezed
abstract class EtaResponse with _$EtaResponse {
  const factory EtaResponse({
    @JsonKey(fromJson: decimalString) required String distanceKm,
    required int durationMinutes,
    required DateTime etaAt,
  }) = _EtaResponse;

  factory EtaResponse.fromJson(Map<String, dynamic> json) =>
      _$EtaResponseFromJson(json);
}

/// `NearbyVehicleResponse` from `GET /vehicles/nearby` (backend gap G16): a
/// vehicle out on a trip, at its last GPS ping.
@freezed
abstract class NearbyVehicleResponse with _$NearbyVehicleResponse {
  const factory NearbyVehicleResponse({
    required String tripId,
    required String vehicleId,
    required String vehicleRegistrationNumber,
    @JsonKey(unknownEnumValue: VehicleType.other)
    required VehicleType vehicleType,
    required String routeId,
    required String routeName,
    required double latitude,
    required double longitude,

    /// Degrees from north, when the ping had one.
    @JsonKey(fromJson: decimalOrNull) double? heading,
    required double distanceM,
    required int availableSeats,
    required DateTime updatedAt,
  }) = _NearbyVehicleResponse;

  factory NearbyVehicleResponse.fromJson(Map<String, dynamic> json) =>
      _$NearbyVehicleResponseFromJson(json);
}
