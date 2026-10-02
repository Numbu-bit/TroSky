// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
