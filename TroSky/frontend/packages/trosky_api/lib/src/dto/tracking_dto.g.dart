// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveLocationResponse _$LiveLocationResponseFromJson(
  Map<String, dynamic> json,
) => _LiveLocationResponse(
  tripId: json['trip_id'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  speedKmh: decimalOrNull(json['speed_kmh']),
  headingDegrees: decimalOrNull(json['heading_degrees']),
  recordedAt: DateTime.parse(json['recorded_at'] as String),
  isStale: json['is_stale'] as bool,
  tripStatus: $enumDecodeNullable(_$TripStatusEnumMap, json['trip_status']),
  liveFarePerSeat: decimalOrNull(json['live_fare_per_seat']),
  ridersCount: (json['riders_count'] as num?)?.toInt(),
);

Map<String, dynamic> _$LiveLocationResponseToJson(
  _LiveLocationResponse instance,
) => <String, dynamic>{
  'trip_id': instance.tripId,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'speed_kmh': ?instance.speedKmh,
  'heading_degrees': ?instance.headingDegrees,
  'recorded_at': instance.recordedAt.toIso8601String(),
  'is_stale': instance.isStale,
  'trip_status': ?_$TripStatusEnumMap[instance.tripStatus],
  'live_fare_per_seat': ?instance.liveFarePerSeat,
  'riders_count': ?instance.ridersCount,
};

const _$TripStatusEnumMap = {
  TripStatus.scheduled: 'scheduled',
  TripStatus.boarding: 'boarding',
  TripStatus.inProgress: 'in_progress',
  TripStatus.paused: 'paused',
  TripStatus.completed: 'completed',
  TripStatus.cancelled: 'cancelled',
};

_EtaResponse _$EtaResponseFromJson(Map<String, dynamic> json) => _EtaResponse(
  distanceKm: decimalString(json['distance_km']),
  durationMinutes: (json['duration_minutes'] as num).toInt(),
  etaAt: DateTime.parse(json['eta_at'] as String),
);

Map<String, dynamic> _$EtaResponseToJson(_EtaResponse instance) =>
    <String, dynamic>{
      'distance_km': instance.distanceKm,
      'duration_minutes': instance.durationMinutes,
      'eta_at': instance.etaAt.toIso8601String(),
    };

_NearbyVehicleResponse _$NearbyVehicleResponseFromJson(
  Map<String, dynamic> json,
) => _NearbyVehicleResponse(
  tripId: json['trip_id'] as String,
  vehicleId: json['vehicle_id'] as String,
  vehicleRegistrationNumber: json['vehicle_registration_number'] as String,
  vehicleType: $enumDecode(
    _$VehicleTypeEnumMap,
    json['vehicle_type'],
    unknownValue: VehicleType.other,
  ),
  routeId: json['route_id'] as String,
  routeName: json['route_name'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  heading: decimalOrNull(json['heading']),
  distanceM: (json['distance_m'] as num).toDouble(),
  availableSeats: (json['available_seats'] as num).toInt(),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$NearbyVehicleResponseToJson(
  _NearbyVehicleResponse instance,
) => <String, dynamic>{
  'trip_id': instance.tripId,
  'vehicle_id': instance.vehicleId,
  'vehicle_registration_number': instance.vehicleRegistrationNumber,
  'vehicle_type': _$VehicleTypeEnumMap[instance.vehicleType]!,
  'route_id': instance.routeId,
  'route_name': instance.routeName,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'heading': ?instance.heading,
  'distance_m': instance.distanceM,
  'available_seats': instance.availableSeats,
  'updated_at': instance.updatedAt.toIso8601String(),
};

const _$VehicleTypeEnumMap = {
  VehicleType.bus: 'bus',
  VehicleType.minibus: 'minibus',
  VehicleType.shuttle: 'shuttle',
  VehicleType.sedan: 'sedan',
  VehicleType.other: 'other',
};
