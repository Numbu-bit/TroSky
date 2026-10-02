// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
