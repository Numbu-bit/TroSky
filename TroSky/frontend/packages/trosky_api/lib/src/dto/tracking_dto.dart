// Live vehicles, field for field as in backend/app/schemas/tracking.py.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_decimal.dart';

part 'tracking_dto.freezed.dart';
part 'tracking_dto.g.dart';

/// `VehicleType` (backend/app/models/vehicles.py). A type added later reads
/// as [other].
@JsonEnum()
enum VehicleType { bus, minibus, shuttle, sedan, other }

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
