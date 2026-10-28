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

/// The order of `GET /trips/search` (`?sort=`). Vehicles that already
/// passed the pickup always come last.
@JsonEnum()
enum SearchSort {
  /// Soonest departure first (the backend's default).
  departure,

  /// Lowest current fare first.
  cheapest,

  /// Shortest scheduled ride first.
  fastest,
}

/// `FareSummaryResponse` (backend app/schemas/trip.py): what a seat costs
/// from one pickup to one drop-off, as the vehicle stands now. Amounts are
/// in [currency], exactly as sent ("14.00").
///
/// A passenger's fare is fixed when they book; later riders lower it only
/// for those who book after them.
@freezed
abstract class FareSummaryResponse with _$FareSummaryResponse {
  const factory FareSummaryResponse({
    /// Per seat right now, before TroSky's platform fee.
    @JsonKey(fromJson: decimalString) required String current,

    /// Per seat with nobody to share the trip: the crossed-out price.
    @JsonKey(fromJson: decimalString) required String solo,

    /// The lowest the per-seat price can reach if every free seat fills.
    @JsonKey(fromJson: decimalString) required String minimum,

    /// TroSky's fee for all [seats].
    @JsonKey(fromJson: decimalString) required String platformFee,

    /// What booking [seats] costs now: [current] × [seats] + [platformFee].
    @JsonKey(fromJson: decimalString) required String total,
    required String currency,

    /// Seats already taken on the trip.
    required int ridersCount,
    required int seats,
  }) = _FareSummaryResponse;

  factory FareSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$FareSummaryResponseFromJson(json);
}

/// `FareQuoteResponse` from `GET /trips/{id}/fare-quote`: a
/// [FareSummaryResponse] for the stops and seats asked about. [total] is
/// what `POST /bookings` would charge now.
@freezed
abstract class FareQuoteResponse with _$FareQuoteResponse {
  const factory FareQuoteResponse({
    required String tripId,
    required String originStopId,
    required String destinationStopId,
    @JsonKey(fromJson: decimalString) required String current,
    @JsonKey(fromJson: decimalString) required String solo,
    @JsonKey(fromJson: decimalString) required String minimum,
    @JsonKey(fromJson: decimalString) required String platformFee,
    @JsonKey(fromJson: decimalString) required String total,
    required String currency,
    required int ridersCount,
    required int seats,
  }) = _FareQuoteResponse;

  const FareQuoteResponse._();

  factory FareQuoteResponse.fromJson(Map<String, dynamic> json) =>
      _$FareQuoteResponseFromJson(json);

  /// The price part, as search results carry it.
  FareSummaryResponse get summary => FareSummaryResponse(
    current: current,
    solo: solo,
    minimum: minimum,
    platformFee: platformFee,
    total: total,
    currency: currency,
    ridersCount: ridersCount,
    seats: seats,
  );
}

/// `TripSearchResultResponse` from `GET /trips/search` (backend
/// app/schemas/trip.py).
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

    /// The price of one seat from the pickup to the searched destination
    /// (G20, backend 0.13.0). Null only from an older backend.
    FareSummaryResponse? fare,

    /// Scheduled minutes from the pickup to the destination.
    int? rideMinutes,

    /// Minutes until a vehicle already on the road reaches the pickup (0:
    /// there now). Null for trips that haven't set off (G21).
    int? vehicleEtaToPickupMinutes,

    /// The vehicle already passed the pickup and can't be booked from it.
    @Default(false) bool hasPassedPickup,
  }) = _TripSearchResultResponse;

  factory TripSearchResultResponse.fromJson(Map<String, dynamic> json) =>
      _$TripSearchResultResponseFromJson(json);
}

/// `TripVehicleResponse`: the vehicle assigned to a trip.
@freezed
abstract class TripVehicleResponse with _$TripVehicleResponse {
  const factory TripVehicleResponse({
    required String registrationNumber,
    @JsonKey(unknownEnumValue: VehicleType.other) required VehicleType type,

    /// "Toyota Hiace".
    String? makeModel,
    int? capacity,
  }) = _TripVehicleResponse;

  factory TripVehicleResponse.fromJson(Map<String, dynamic> json) =>
      _$TripVehicleResponseFromJson(json);
}

/// `TripDriverResponse`: the driver assigned to a trip.
@freezed
abstract class TripDriverResponse with _$TripDriverResponse {
  const factory TripDriverResponse({
    required String id,
    String? fullName,
    String? avatarUrl,

    /// 1-5, null until rated.
    @JsonKey(fromJson: decimalOrNull) double? averageRating,
    required int ratingCount,
  }) = _TripDriverResponse;

  factory TripDriverResponse.fromJson(Map<String, dynamic> json) =>
      _$TripDriverResponseFromJson(json);
}

/// `TripDetailResponse` from `GET /trips/{id}`: a trip with its route,
/// vehicle, driver and how full it is.
@freezed
abstract class TripDetailResponse with _$TripDetailResponse {
  const factory TripDetailResponse({
    required String id,
    required String routeId,
    required DateTime scheduledDepartureAt,

    /// At the end of the route.
    DateTime? scheduledArrivalAt,
    DateTime? actualDepartureAt,
    DateTime? actualArrivalAt,
    @JsonKey(unknownEnumValue: TripStatus.scheduled) required TripStatus status,
    @JsonKey(fromJson: decimalString) required String fareAmount,
    required String routeName,
    required String originStopId,
    required String originStopName,
    required String destinationStopId,
    required String destinationStopName,
    TripVehicleResponse? vehicle,
    TripDriverResponse? driver,
    required int ridersCount,
    required int seatsTotal,
    required int availableSeats,
  }) = _TripDetailResponse;

  factory TripDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$TripDetailResponseFromJson(json);
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
