// Stops and routes, field for field as in backend/app/schemas/route.py.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_decimal.dart';
import 'tracking_dto.dart';

part 'route_dto.freezed.dart';
part 'route_dto.g.dart';

/// `StopResponse` from `GET /stops?q=`.
@freezed
abstract class StopResponse with _$StopResponse {
  const factory StopResponse({
    required String id,
    required String name,
    String? code,
    String? address,
    String? city,
    String? region,
    required double latitude,
    required double longitude,
  }) = _StopResponse;

  factory StopResponse.fromJson(Map<String, dynamic> json) =>
      _$StopResponseFromJson(json);
}

/// `TripStatus` (backend/app/models/trips.py). Search only returns
/// scheduled and boarding trips.
@JsonEnum(fieldRename: FieldRename.snake)
enum TripStatus {
  scheduled,
  boarding,
  inProgress,
  paused,
  completed,
  cancelled,
}

/// How the boarding stop of a search result was found.
@JsonEnum()
enum PickupSource {
  /// Nearest served stop to the phone's position.
  gps,

  /// The stop the passenger chose.
  manual,
}

/// `TripSearchResultResponse` from `GET /trips/search` (backend
/// app/schemas/trip.py), plus the fields proposed in backend gaps G20 and
/// G21. Those stay null until the backend sends them, and the app only
/// shows what they drive when they are there (decisions 20 and 21).
@freezed
abstract class TripSearchResultResponse with _$TripSearchResultResponse {
  const factory TripSearchResultResponse({
    required String tripId,
    required String routeId,
    required String routeName,
    required String originStopId,
    required String destinationStopId,
    required DateTime scheduledDepartureAt,
    DateTime? scheduledArrivalAt,
    int? estimatedDurationMinutes,
    @JsonKey(fromJson: decimalOrNull) double? distanceKm,

    /// The trip's fare in cedis, exactly as sent ("8.00").
    @JsonKey(fromJson: decimalString) required String fareAmount,
    @JsonKey(unknownEnumValue: TripStatus.scheduled) required TripStatus status,
    required int availableSeats,
    String? vehicleRegistrationNumber,
    @JsonKey(unknownEnumValue: VehicleType.other) VehicleType? vehicleType,
    String? pickupStopId,
    String? pickupStopName,
    double? pickupDistanceM,
    PickupSource? pickupSource,

    /// G20: the searched stretch ridden alone.
    @JsonKey(fromJson: decimalStringOrNull) String? soloFareAmount,

    /// G20: the searched stretch, shared, if booked now.
    @JsonKey(fromJson: decimalStringOrNull) String? sharedFareAmount,

    /// G21: minutes until the vehicle reaches the pickup.
    int? pickupEtaMinutes,

    /// G21: the vehicle already passed the pickup.
    bool? passedPickup,
  }) = _TripSearchResultResponse;

  factory TripSearchResultResponse.fromJson(Map<String, dynamic> json) =>
      _$TripSearchResultResponseFromJson(json);
}

/// `NearbyStopResponse` from `GET /stops/nearby`: a `StopResponse` plus how
/// far it is from the point asked about.
@freezed
abstract class NearbyStopResponse with _$NearbyStopResponse {
  const factory NearbyStopResponse({
    required String id,
    required String name,
    String? code,
    String? address,
    String? city,
    String? region,
    required double latitude,
    required double longitude,

    /// Metres from the point asked about.
    required double distanceM,
  }) = _NearbyStopResponse;

  factory NearbyStopResponse.fromJson(Map<String, dynamic> json) =>
      _$NearbyStopResponseFromJson(json);
}
