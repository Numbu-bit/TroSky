// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StopResponse _$StopResponseFromJson(Map<String, dynamic> json) =>
    _StopResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$StopResponseToJson(_StopResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'code': ?instance.code,
      'address': ?instance.address,
      'city': ?instance.city,
      'region': ?instance.region,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

_FareSummaryResponse _$FareSummaryResponseFromJson(Map<String, dynamic> json) =>
    _FareSummaryResponse(
      current: decimalString(json['current']),
      solo: decimalString(json['solo']),
      minimum: decimalString(json['minimum']),
      platformFee: decimalString(json['platform_fee']),
      total: decimalString(json['total']),
      currency: json['currency'] as String,
      ridersCount: (json['riders_count'] as num).toInt(),
      seats: (json['seats'] as num).toInt(),
    );

Map<String, dynamic> _$FareSummaryResponseToJson(
  _FareSummaryResponse instance,
) => <String, dynamic>{
  'current': instance.current,
  'solo': instance.solo,
  'minimum': instance.minimum,
  'platform_fee': instance.platformFee,
  'total': instance.total,
  'currency': instance.currency,
  'riders_count': instance.ridersCount,
  'seats': instance.seats,
};

_FareQuoteResponse _$FareQuoteResponseFromJson(Map<String, dynamic> json) =>
    _FareQuoteResponse(
      tripId: json['trip_id'] as String,
      originStopId: json['origin_stop_id'] as String,
      destinationStopId: json['destination_stop_id'] as String,
      current: decimalString(json['current']),
      solo: decimalString(json['solo']),
      minimum: decimalString(json['minimum']),
      platformFee: decimalString(json['platform_fee']),
      total: decimalString(json['total']),
      currency: json['currency'] as String,
      ridersCount: (json['riders_count'] as num).toInt(),
      seats: (json['seats'] as num).toInt(),
    );

Map<String, dynamic> _$FareQuoteResponseToJson(_FareQuoteResponse instance) =>
    <String, dynamic>{
      'trip_id': instance.tripId,
      'origin_stop_id': instance.originStopId,
      'destination_stop_id': instance.destinationStopId,
      'current': instance.current,
      'solo': instance.solo,
      'minimum': instance.minimum,
      'platform_fee': instance.platformFee,
      'total': instance.total,
      'currency': instance.currency,
      'riders_count': instance.ridersCount,
      'seats': instance.seats,
    };

_TripSearchResultResponse _$TripSearchResultResponseFromJson(
  Map<String, dynamic> json,
) => _TripSearchResultResponse(
  tripId: json['trip_id'] as String,
  routeId: json['route_id'] as String,
  routeName: json['route_name'] as String,
  originStopId: json['origin_stop_id'] as String,
  destinationStopId: json['destination_stop_id'] as String,
  scheduledDepartureAt: DateTime.parse(
    json['scheduled_departure_at'] as String,
  ),
  scheduledArrivalAt: json['scheduled_arrival_at'] == null
      ? null
      : DateTime.parse(json['scheduled_arrival_at'] as String),
  estimatedDurationMinutes: (json['estimated_duration_minutes'] as num?)
      ?.toInt(),
  distanceKm: decimalOrNull(json['distance_km']),
  fareAmount: decimalString(json['fare_amount']),
  status: $enumDecode(
    _$TripStatusEnumMap,
    json['status'],
    unknownValue: TripStatus.scheduled,
  ),
  availableSeats: (json['available_seats'] as num).toInt(),
  vehicleRegistrationNumber: json['vehicle_registration_number'] as String?,
  vehicleType: $enumDecodeNullable(
    _$VehicleTypeEnumMap,
    json['vehicle_type'],
    unknownValue: VehicleType.other,
  ),
  pickupStopId: json['pickup_stop_id'] as String?,
  pickupStopName: json['pickup_stop_name'] as String?,
  pickupDistanceM: (json['pickup_distance_m'] as num?)?.toDouble(),
  pickupSource: $enumDecodeNullable(
    _$PickupSourceEnumMap,
    json['pickup_source'],
  ),
  fare: json['fare'] == null
      ? null
      : FareSummaryResponse.fromJson(json['fare'] as Map<String, dynamic>),
  rideMinutes: (json['ride_minutes'] as num?)?.toInt(),
  vehicleEtaToPickupMinutes: (json['vehicle_eta_to_pickup_minutes'] as num?)
      ?.toInt(),
  hasPassedPickup: json['has_passed_pickup'] as bool? ?? false,
);

Map<String, dynamic> _$TripSearchResultResponseToJson(
  _TripSearchResultResponse instance,
) => <String, dynamic>{
  'trip_id': instance.tripId,
  'route_id': instance.routeId,
  'route_name': instance.routeName,
  'origin_stop_id': instance.originStopId,
  'destination_stop_id': instance.destinationStopId,
  'scheduled_departure_at': instance.scheduledDepartureAt.toIso8601String(),
  'scheduled_arrival_at': ?instance.scheduledArrivalAt?.toIso8601String(),
  'estimated_duration_minutes': ?instance.estimatedDurationMinutes,
  'distance_km': ?instance.distanceKm,
  'fare_amount': instance.fareAmount,
  'status': _$TripStatusEnumMap[instance.status]!,
  'available_seats': instance.availableSeats,
  'vehicle_registration_number': ?instance.vehicleRegistrationNumber,
  'vehicle_type': ?_$VehicleTypeEnumMap[instance.vehicleType],
  'pickup_stop_id': ?instance.pickupStopId,
  'pickup_stop_name': ?instance.pickupStopName,
  'pickup_distance_m': ?instance.pickupDistanceM,
  'pickup_source': ?_$PickupSourceEnumMap[instance.pickupSource],
  'fare': ?instance.fare?.toJson(),
  'ride_minutes': ?instance.rideMinutes,
  'vehicle_eta_to_pickup_minutes': ?instance.vehicleEtaToPickupMinutes,
  'has_passed_pickup': instance.hasPassedPickup,
};

const _$TripStatusEnumMap = {
  TripStatus.scheduled: 'scheduled',
  TripStatus.boarding: 'boarding',
  TripStatus.inProgress: 'in_progress',
  TripStatus.paused: 'paused',
  TripStatus.completed: 'completed',
  TripStatus.cancelled: 'cancelled',
};

const _$VehicleTypeEnumMap = {
  VehicleType.bus: 'bus',
  VehicleType.minibus: 'minibus',
  VehicleType.shuttle: 'shuttle',
  VehicleType.sedan: 'sedan',
  VehicleType.other: 'other',
};

const _$PickupSourceEnumMap = {
  PickupSource.gps: 'gps',
  PickupSource.manual: 'manual',
};

_NearbyStopResponse _$NearbyStopResponseFromJson(Map<String, dynamic> json) =>
    _NearbyStopResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceM: (json['distance_m'] as num).toDouble(),
    );

Map<String, dynamic> _$NearbyStopResponseToJson(_NearbyStopResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'code': ?instance.code,
      'address': ?instance.address,
      'city': ?instance.city,
      'region': ?instance.region,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'distance_m': instance.distanceM,
    };
