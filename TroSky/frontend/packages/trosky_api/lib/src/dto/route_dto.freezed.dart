// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StopResponse {

 String get id; String get name; String? get code; String? get address; String? get city; String? get region; double get latitude; double get longitude;
/// Create a copy of StopResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StopResponseCopyWith<StopResponse> get copyWith => _$StopResponseCopyWithImpl<StopResponse>(this as StopResponse, _$identity);

  /// Serializes this StopResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StopResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,code,address,city,region,latitude,longitude);

@override
String toString() {
  return 'StopResponse(id: $id, name: $name, code: $code, address: $address, city: $city, region: $region, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $StopResponseCopyWith<$Res>  {
  factory $StopResponseCopyWith(StopResponse value, $Res Function(StopResponse) _then) = _$StopResponseCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? code, String? address, String? city, String? region, double latitude, double longitude
});




}
/// @nodoc
class _$StopResponseCopyWithImpl<$Res>
    implements $StopResponseCopyWith<$Res> {
  _$StopResponseCopyWithImpl(this._self, this._then);

  final StopResponse _self;
  final $Res Function(StopResponse) _then;

/// Create a copy of StopResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? code = freezed,Object? address = freezed,Object? city = freezed,Object? region = freezed,Object? latitude = null,Object? longitude = null,}) {
  return _then(StopResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [StopResponse].
extension StopResponsePatterns on StopResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StopResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StopResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StopResponse value)  $default,){
final _that = this;
switch (_that) {
case _StopResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StopResponse value)?  $default,){
final _that = this;
switch (_that) {
case _StopResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? code,  String? address,  String? city,  String? region,  double latitude,  double longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StopResponse() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.address,_that.city,_that.region,_that.latitude,_that.longitude);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? code,  String? address,  String? city,  String? region,  double latitude,  double longitude)  $default,) {final _that = this;
switch (_that) {
case _StopResponse():
return $default(_that.id,_that.name,_that.code,_that.address,_that.city,_that.region,_that.latitude,_that.longitude);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? code,  String? address,  String? city,  String? region,  double latitude,  double longitude)?  $default,) {final _that = this;
switch (_that) {
case _StopResponse() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.address,_that.city,_that.region,_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StopResponse implements StopResponse {
  const _StopResponse({required this.id, required this.name, this.code, this.address, this.city, this.region, required this.latitude, required this.longitude});
  factory _StopResponse.fromJson(Map<String, dynamic> json) => _$StopResponseFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? code;
@override final  String? address;
@override final  String? city;
@override final  String? region;
@override final  double latitude;
@override final  double longitude;

/// Create a copy of StopResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StopResponseCopyWith<_StopResponse> get copyWith => __$StopResponseCopyWithImpl<_StopResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StopResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StopResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,code,address,city,region,latitude,longitude);

@override
String toString() {
  return 'StopResponse(id: $id, name: $name, code: $code, address: $address, city: $city, region: $region, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$StopResponseCopyWith<$Res> implements $StopResponseCopyWith<$Res> {
  factory _$StopResponseCopyWith(_StopResponse value, $Res Function(_StopResponse) _then) = __$StopResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? code, String? address, String? city, String? region, double latitude, double longitude
});




}
/// @nodoc
class __$StopResponseCopyWithImpl<$Res>
    implements _$StopResponseCopyWith<$Res> {
  __$StopResponseCopyWithImpl(this._self, this._then);

  final _StopResponse _self;
  final $Res Function(_StopResponse) _then;

/// Create a copy of StopResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? code = freezed,Object? address = freezed,Object? city = freezed,Object? region = freezed,Object? latitude = null,Object? longitude = null,}) {
  return _then(_StopResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$TripSearchResultResponse {

 String get tripId; String get routeId; String get routeName; String get originStopId; String get destinationStopId; DateTime get scheduledDepartureAt; DateTime? get scheduledArrivalAt; int? get estimatedDurationMinutes;@JsonKey(fromJson: decimalOrNull) double? get distanceKm;/// The trip's fare in cedis, exactly as sent ("8.00").
@JsonKey(fromJson: decimalString) String get fareAmount;@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus get status; int get availableSeats; String? get vehicleRegistrationNumber;@JsonKey(unknownEnumValue: VehicleType.other) VehicleType? get vehicleType; String? get pickupStopId; String? get pickupStopName; double? get pickupDistanceM; PickupSource? get pickupSource;/// G20: the searched stretch ridden alone.
@JsonKey(fromJson: decimalStringOrNull) String? get soloFareAmount;/// G20: the searched stretch, shared, if booked now.
@JsonKey(fromJson: decimalStringOrNull) String? get sharedFareAmount;/// G21: minutes until the vehicle reaches the pickup.
 int? get pickupEtaMinutes;/// G21: the vehicle already passed the pickup.
 bool? get passedPickup;
/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripSearchResultResponseCopyWith<TripSearchResultResponse> get copyWith => _$TripSearchResultResponseCopyWithImpl<TripSearchResultResponse>(this as TripSearchResultResponse, _$identity);

  /// Serializes this TripSearchResultResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripSearchResultResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.scheduledArrivalAt, scheduledArrivalAt) || other.scheduledArrivalAt == scheduledArrivalAt)&&(identical(other.estimatedDurationMinutes, estimatedDurationMinutes) || other.estimatedDurationMinutes == estimatedDurationMinutes)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.pickupStopId, pickupStopId) || other.pickupStopId == pickupStopId)&&(identical(other.pickupStopName, pickupStopName) || other.pickupStopName == pickupStopName)&&(identical(other.pickupDistanceM, pickupDistanceM) || other.pickupDistanceM == pickupDistanceM)&&(identical(other.pickupSource, pickupSource) || other.pickupSource == pickupSource)&&(identical(other.soloFareAmount, soloFareAmount) || other.soloFareAmount == soloFareAmount)&&(identical(other.sharedFareAmount, sharedFareAmount) || other.sharedFareAmount == sharedFareAmount)&&(identical(other.pickupEtaMinutes, pickupEtaMinutes) || other.pickupEtaMinutes == pickupEtaMinutes)&&(identical(other.passedPickup, passedPickup) || other.passedPickup == passedPickup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,tripId,routeId,routeName,originStopId,destinationStopId,scheduledDepartureAt,scheduledArrivalAt,estimatedDurationMinutes,distanceKm,fareAmount,status,availableSeats,vehicleRegistrationNumber,vehicleType,pickupStopId,pickupStopName,pickupDistanceM,pickupSource,soloFareAmount,sharedFareAmount,pickupEtaMinutes,passedPickup]);

@override
String toString() {
  return 'TripSearchResultResponse(tripId: $tripId, routeId: $routeId, routeName: $routeName, originStopId: $originStopId, destinationStopId: $destinationStopId, scheduledDepartureAt: $scheduledDepartureAt, scheduledArrivalAt: $scheduledArrivalAt, estimatedDurationMinutes: $estimatedDurationMinutes, distanceKm: $distanceKm, fareAmount: $fareAmount, status: $status, availableSeats: $availableSeats, vehicleRegistrationNumber: $vehicleRegistrationNumber, vehicleType: $vehicleType, pickupStopId: $pickupStopId, pickupStopName: $pickupStopName, pickupDistanceM: $pickupDistanceM, pickupSource: $pickupSource, soloFareAmount: $soloFareAmount, sharedFareAmount: $sharedFareAmount, pickupEtaMinutes: $pickupEtaMinutes, passedPickup: $passedPickup)';
}


}

/// @nodoc
abstract mixin class $TripSearchResultResponseCopyWith<$Res>  {
  factory $TripSearchResultResponseCopyWith(TripSearchResultResponse value, $Res Function(TripSearchResultResponse) _then) = _$TripSearchResultResponseCopyWithImpl;
@useResult
$Res call({
 String tripId, String routeId, String routeName, String originStopId, String destinationStopId, DateTime scheduledDepartureAt, DateTime? scheduledArrivalAt, int? estimatedDurationMinutes,@JsonKey(fromJson: decimalOrNull) double? distanceKm,@JsonKey(fromJson: decimalString) String fareAmount,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status, int availableSeats, String? vehicleRegistrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType? vehicleType, String? pickupStopId, String? pickupStopName, double? pickupDistanceM, PickupSource? pickupSource,@JsonKey(fromJson: decimalStringOrNull) String? soloFareAmount,@JsonKey(fromJson: decimalStringOrNull) String? sharedFareAmount, int? pickupEtaMinutes, bool? passedPickup
});




}
/// @nodoc
class _$TripSearchResultResponseCopyWithImpl<$Res>
    implements $TripSearchResultResponseCopyWith<$Res> {
  _$TripSearchResultResponseCopyWithImpl(this._self, this._then);

  final TripSearchResultResponse _self;
  final $Res Function(TripSearchResultResponse) _then;

/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tripId = null,Object? routeId = null,Object? routeName = null,Object? originStopId = null,Object? destinationStopId = null,Object? scheduledDepartureAt = null,Object? scheduledArrivalAt = freezed,Object? estimatedDurationMinutes = freezed,Object? distanceKm = freezed,Object? fareAmount = null,Object? status = null,Object? availableSeats = null,Object? vehicleRegistrationNumber = freezed,Object? vehicleType = freezed,Object? pickupStopId = freezed,Object? pickupStopName = freezed,Object? pickupDistanceM = freezed,Object? pickupSource = freezed,Object? soloFareAmount = freezed,Object? sharedFareAmount = freezed,Object? pickupEtaMinutes = freezed,Object? passedPickup = freezed,}) {
  return _then(TripSearchResultResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,scheduledDepartureAt: null == scheduledDepartureAt ? _self.scheduledDepartureAt : scheduledDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledArrivalAt: freezed == scheduledArrivalAt ? _self.scheduledArrivalAt : scheduledArrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,estimatedDurationMinutes: freezed == estimatedDurationMinutes ? _self.estimatedDurationMinutes : estimatedDurationMinutes // ignore: cast_nullable_to_non_nullable
as int?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,fareAmount: null == fareAmount ? _self.fareAmount : fareAmount // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TripStatus,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,vehicleRegistrationNumber: freezed == vehicleRegistrationNumber ? _self.vehicleRegistrationNumber : vehicleRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String?,vehicleType: freezed == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType?,pickupStopId: freezed == pickupStopId ? _self.pickupStopId : pickupStopId // ignore: cast_nullable_to_non_nullable
as String?,pickupStopName: freezed == pickupStopName ? _self.pickupStopName : pickupStopName // ignore: cast_nullable_to_non_nullable
as String?,pickupDistanceM: freezed == pickupDistanceM ? _self.pickupDistanceM : pickupDistanceM // ignore: cast_nullable_to_non_nullable
as double?,pickupSource: freezed == pickupSource ? _self.pickupSource : pickupSource // ignore: cast_nullable_to_non_nullable
as PickupSource?,soloFareAmount: freezed == soloFareAmount ? _self.soloFareAmount : soloFareAmount // ignore: cast_nullable_to_non_nullable
as String?,sharedFareAmount: freezed == sharedFareAmount ? _self.sharedFareAmount : sharedFareAmount // ignore: cast_nullable_to_non_nullable
as String?,pickupEtaMinutes: freezed == pickupEtaMinutes ? _self.pickupEtaMinutes : pickupEtaMinutes // ignore: cast_nullable_to_non_nullable
as int?,passedPickup: freezed == passedPickup ? _self.passedPickup : passedPickup // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [TripSearchResultResponse].
extension TripSearchResultResponsePatterns on TripSearchResultResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripSearchResultResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripSearchResultResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripSearchResultResponse value)  $default,){
final _that = this;
switch (_that) {
case _TripSearchResultResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripSearchResultResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TripSearchResultResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tripId,  String routeId,  String routeName,  String originStopId,  String destinationStopId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  int? estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull)  double? distanceKm, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  int availableSeats,  String? vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType? vehicleType,  String? pickupStopId,  String? pickupStopName,  double? pickupDistanceM,  PickupSource? pickupSource, @JsonKey(fromJson: decimalStringOrNull)  String? soloFareAmount, @JsonKey(fromJson: decimalStringOrNull)  String? sharedFareAmount,  int? pickupEtaMinutes,  bool? passedPickup)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripSearchResultResponse() when $default != null:
return $default(_that.tripId,_that.routeId,_that.routeName,_that.originStopId,_that.destinationStopId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.estimatedDurationMinutes,_that.distanceKm,_that.fareAmount,_that.status,_that.availableSeats,_that.vehicleRegistrationNumber,_that.vehicleType,_that.pickupStopId,_that.pickupStopName,_that.pickupDistanceM,_that.pickupSource,_that.soloFareAmount,_that.sharedFareAmount,_that.pickupEtaMinutes,_that.passedPickup);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tripId,  String routeId,  String routeName,  String originStopId,  String destinationStopId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  int? estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull)  double? distanceKm, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  int availableSeats,  String? vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType? vehicleType,  String? pickupStopId,  String? pickupStopName,  double? pickupDistanceM,  PickupSource? pickupSource, @JsonKey(fromJson: decimalStringOrNull)  String? soloFareAmount, @JsonKey(fromJson: decimalStringOrNull)  String? sharedFareAmount,  int? pickupEtaMinutes,  bool? passedPickup)  $default,) {final _that = this;
switch (_that) {
case _TripSearchResultResponse():
return $default(_that.tripId,_that.routeId,_that.routeName,_that.originStopId,_that.destinationStopId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.estimatedDurationMinutes,_that.distanceKm,_that.fareAmount,_that.status,_that.availableSeats,_that.vehicleRegistrationNumber,_that.vehicleType,_that.pickupStopId,_that.pickupStopName,_that.pickupDistanceM,_that.pickupSource,_that.soloFareAmount,_that.sharedFareAmount,_that.pickupEtaMinutes,_that.passedPickup);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tripId,  String routeId,  String routeName,  String originStopId,  String destinationStopId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  int? estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull)  double? distanceKm, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  int availableSeats,  String? vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType? vehicleType,  String? pickupStopId,  String? pickupStopName,  double? pickupDistanceM,  PickupSource? pickupSource, @JsonKey(fromJson: decimalStringOrNull)  String? soloFareAmount, @JsonKey(fromJson: decimalStringOrNull)  String? sharedFareAmount,  int? pickupEtaMinutes,  bool? passedPickup)?  $default,) {final _that = this;
switch (_that) {
case _TripSearchResultResponse() when $default != null:
return $default(_that.tripId,_that.routeId,_that.routeName,_that.originStopId,_that.destinationStopId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.estimatedDurationMinutes,_that.distanceKm,_that.fareAmount,_that.status,_that.availableSeats,_that.vehicleRegistrationNumber,_that.vehicleType,_that.pickupStopId,_that.pickupStopName,_that.pickupDistanceM,_that.pickupSource,_that.soloFareAmount,_that.sharedFareAmount,_that.pickupEtaMinutes,_that.passedPickup);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripSearchResultResponse implements TripSearchResultResponse {
  const _TripSearchResultResponse({required this.tripId, required this.routeId, required this.routeName, required this.originStopId, required this.destinationStopId, required this.scheduledDepartureAt, this.scheduledArrivalAt, this.estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull) this.distanceKm, @JsonKey(fromJson: decimalString) required this.fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled) required this.status, required this.availableSeats, this.vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other) this.vehicleType, this.pickupStopId, this.pickupStopName, this.pickupDistanceM, this.pickupSource, @JsonKey(fromJson: decimalStringOrNull) this.soloFareAmount, @JsonKey(fromJson: decimalStringOrNull) this.sharedFareAmount, this.pickupEtaMinutes, this.passedPickup});
  factory _TripSearchResultResponse.fromJson(Map<String, dynamic> json) => _$TripSearchResultResponseFromJson(json);

@override final  String tripId;
@override final  String routeId;
@override final  String routeName;
@override final  String originStopId;
@override final  String destinationStopId;
@override final  DateTime scheduledDepartureAt;
@override final  DateTime? scheduledArrivalAt;
@override final  int? estimatedDurationMinutes;
@override@JsonKey(fromJson: decimalOrNull) final  double? distanceKm;
/// The trip's fare in cedis, exactly as sent ("8.00").
@override@JsonKey(fromJson: decimalString) final  String fareAmount;
@override@JsonKey(unknownEnumValue: TripStatus.scheduled) final  TripStatus status;
@override final  int availableSeats;
@override final  String? vehicleRegistrationNumber;
@override@JsonKey(unknownEnumValue: VehicleType.other) final  VehicleType? vehicleType;
@override final  String? pickupStopId;
@override final  String? pickupStopName;
@override final  double? pickupDistanceM;
@override final  PickupSource? pickupSource;
/// G20: the searched stretch ridden alone.
@override@JsonKey(fromJson: decimalStringOrNull) final  String? soloFareAmount;
/// G20: the searched stretch, shared, if booked now.
@override@JsonKey(fromJson: decimalStringOrNull) final  String? sharedFareAmount;
/// G21: minutes until the vehicle reaches the pickup.
@override final  int? pickupEtaMinutes;
/// G21: the vehicle already passed the pickup.
@override final  bool? passedPickup;

/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripSearchResultResponseCopyWith<_TripSearchResultResponse> get copyWith => __$TripSearchResultResponseCopyWithImpl<_TripSearchResultResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripSearchResultResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripSearchResultResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.scheduledArrivalAt, scheduledArrivalAt) || other.scheduledArrivalAt == scheduledArrivalAt)&&(identical(other.estimatedDurationMinutes, estimatedDurationMinutes) || other.estimatedDurationMinutes == estimatedDurationMinutes)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.pickupStopId, pickupStopId) || other.pickupStopId == pickupStopId)&&(identical(other.pickupStopName, pickupStopName) || other.pickupStopName == pickupStopName)&&(identical(other.pickupDistanceM, pickupDistanceM) || other.pickupDistanceM == pickupDistanceM)&&(identical(other.pickupSource, pickupSource) || other.pickupSource == pickupSource)&&(identical(other.soloFareAmount, soloFareAmount) || other.soloFareAmount == soloFareAmount)&&(identical(other.sharedFareAmount, sharedFareAmount) || other.sharedFareAmount == sharedFareAmount)&&(identical(other.pickupEtaMinutes, pickupEtaMinutes) || other.pickupEtaMinutes == pickupEtaMinutes)&&(identical(other.passedPickup, passedPickup) || other.passedPickup == passedPickup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,tripId,routeId,routeName,originStopId,destinationStopId,scheduledDepartureAt,scheduledArrivalAt,estimatedDurationMinutes,distanceKm,fareAmount,status,availableSeats,vehicleRegistrationNumber,vehicleType,pickupStopId,pickupStopName,pickupDistanceM,pickupSource,soloFareAmount,sharedFareAmount,pickupEtaMinutes,passedPickup]);

@override
String toString() {
  return 'TripSearchResultResponse(tripId: $tripId, routeId: $routeId, routeName: $routeName, originStopId: $originStopId, destinationStopId: $destinationStopId, scheduledDepartureAt: $scheduledDepartureAt, scheduledArrivalAt: $scheduledArrivalAt, estimatedDurationMinutes: $estimatedDurationMinutes, distanceKm: $distanceKm, fareAmount: $fareAmount, status: $status, availableSeats: $availableSeats, vehicleRegistrationNumber: $vehicleRegistrationNumber, vehicleType: $vehicleType, pickupStopId: $pickupStopId, pickupStopName: $pickupStopName, pickupDistanceM: $pickupDistanceM, pickupSource: $pickupSource, soloFareAmount: $soloFareAmount, sharedFareAmount: $sharedFareAmount, pickupEtaMinutes: $pickupEtaMinutes, passedPickup: $passedPickup)';
}


}

/// @nodoc
abstract mixin class _$TripSearchResultResponseCopyWith<$Res> implements $TripSearchResultResponseCopyWith<$Res> {
  factory _$TripSearchResultResponseCopyWith(_TripSearchResultResponse value, $Res Function(_TripSearchResultResponse) _then) = __$TripSearchResultResponseCopyWithImpl;
@override @useResult
$Res call({
 String tripId, String routeId, String routeName, String originStopId, String destinationStopId, DateTime scheduledDepartureAt, DateTime? scheduledArrivalAt, int? estimatedDurationMinutes,@JsonKey(fromJson: decimalOrNull) double? distanceKm,@JsonKey(fromJson: decimalString) String fareAmount,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status, int availableSeats, String? vehicleRegistrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType? vehicleType, String? pickupStopId, String? pickupStopName, double? pickupDistanceM, PickupSource? pickupSource,@JsonKey(fromJson: decimalStringOrNull) String? soloFareAmount,@JsonKey(fromJson: decimalStringOrNull) String? sharedFareAmount, int? pickupEtaMinutes, bool? passedPickup
});




}
/// @nodoc
class __$TripSearchResultResponseCopyWithImpl<$Res>
    implements _$TripSearchResultResponseCopyWith<$Res> {
  __$TripSearchResultResponseCopyWithImpl(this._self, this._then);

  final _TripSearchResultResponse _self;
  final $Res Function(_TripSearchResultResponse) _then;

/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tripId = null,Object? routeId = null,Object? routeName = null,Object? originStopId = null,Object? destinationStopId = null,Object? scheduledDepartureAt = null,Object? scheduledArrivalAt = freezed,Object? estimatedDurationMinutes = freezed,Object? distanceKm = freezed,Object? fareAmount = null,Object? status = null,Object? availableSeats = null,Object? vehicleRegistrationNumber = freezed,Object? vehicleType = freezed,Object? pickupStopId = freezed,Object? pickupStopName = freezed,Object? pickupDistanceM = freezed,Object? pickupSource = freezed,Object? soloFareAmount = freezed,Object? sharedFareAmount = freezed,Object? pickupEtaMinutes = freezed,Object? passedPickup = freezed,}) {
  return _then(_TripSearchResultResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,scheduledDepartureAt: null == scheduledDepartureAt ? _self.scheduledDepartureAt : scheduledDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledArrivalAt: freezed == scheduledArrivalAt ? _self.scheduledArrivalAt : scheduledArrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,estimatedDurationMinutes: freezed == estimatedDurationMinutes ? _self.estimatedDurationMinutes : estimatedDurationMinutes // ignore: cast_nullable_to_non_nullable
as int?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,fareAmount: null == fareAmount ? _self.fareAmount : fareAmount // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TripStatus,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,vehicleRegistrationNumber: freezed == vehicleRegistrationNumber ? _self.vehicleRegistrationNumber : vehicleRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String?,vehicleType: freezed == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType?,pickupStopId: freezed == pickupStopId ? _self.pickupStopId : pickupStopId // ignore: cast_nullable_to_non_nullable
as String?,pickupStopName: freezed == pickupStopName ? _self.pickupStopName : pickupStopName // ignore: cast_nullable_to_non_nullable
as String?,pickupDistanceM: freezed == pickupDistanceM ? _self.pickupDistanceM : pickupDistanceM // ignore: cast_nullable_to_non_nullable
as double?,pickupSource: freezed == pickupSource ? _self.pickupSource : pickupSource // ignore: cast_nullable_to_non_nullable
as PickupSource?,soloFareAmount: freezed == soloFareAmount ? _self.soloFareAmount : soloFareAmount // ignore: cast_nullable_to_non_nullable
as String?,sharedFareAmount: freezed == sharedFareAmount ? _self.sharedFareAmount : sharedFareAmount // ignore: cast_nullable_to_non_nullable
as String?,pickupEtaMinutes: freezed == pickupEtaMinutes ? _self.pickupEtaMinutes : pickupEtaMinutes // ignore: cast_nullable_to_non_nullable
as int?,passedPickup: freezed == passedPickup ? _self.passedPickup : passedPickup // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$NearbyStopResponse {

 String get id; String get name; String? get code; String? get address; String? get city; String? get region; double get latitude; double get longitude;/// Metres from the point asked about.
 double get distanceM;
/// Create a copy of NearbyStopResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NearbyStopResponseCopyWith<NearbyStopResponse> get copyWith => _$NearbyStopResponseCopyWithImpl<NearbyStopResponse>(this as NearbyStopResponse, _$identity);

  /// Serializes this NearbyStopResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NearbyStopResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.distanceM, distanceM) || other.distanceM == distanceM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,code,address,city,region,latitude,longitude,distanceM);

@override
String toString() {
  return 'NearbyStopResponse(id: $id, name: $name, code: $code, address: $address, city: $city, region: $region, latitude: $latitude, longitude: $longitude, distanceM: $distanceM)';
}


}

/// @nodoc
abstract mixin class $NearbyStopResponseCopyWith<$Res>  {
  factory $NearbyStopResponseCopyWith(NearbyStopResponse value, $Res Function(NearbyStopResponse) _then) = _$NearbyStopResponseCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? code, String? address, String? city, String? region, double latitude, double longitude, double distanceM
});




}
/// @nodoc
class _$NearbyStopResponseCopyWithImpl<$Res>
    implements $NearbyStopResponseCopyWith<$Res> {
  _$NearbyStopResponseCopyWithImpl(this._self, this._then);

  final NearbyStopResponse _self;
  final $Res Function(NearbyStopResponse) _then;

/// Create a copy of NearbyStopResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? code = freezed,Object? address = freezed,Object? city = freezed,Object? region = freezed,Object? latitude = null,Object? longitude = null,Object? distanceM = null,}) {
  return _then(NearbyStopResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [NearbyStopResponse].
extension NearbyStopResponsePatterns on NearbyStopResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NearbyStopResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NearbyStopResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NearbyStopResponse value)  $default,){
final _that = this;
switch (_that) {
case _NearbyStopResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NearbyStopResponse value)?  $default,){
final _that = this;
switch (_that) {
case _NearbyStopResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? code,  String? address,  String? city,  String? region,  double latitude,  double longitude,  double distanceM)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NearbyStopResponse() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.address,_that.city,_that.region,_that.latitude,_that.longitude,_that.distanceM);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? code,  String? address,  String? city,  String? region,  double latitude,  double longitude,  double distanceM)  $default,) {final _that = this;
switch (_that) {
case _NearbyStopResponse():
return $default(_that.id,_that.name,_that.code,_that.address,_that.city,_that.region,_that.latitude,_that.longitude,_that.distanceM);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? code,  String? address,  String? city,  String? region,  double latitude,  double longitude,  double distanceM)?  $default,) {final _that = this;
switch (_that) {
case _NearbyStopResponse() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.address,_that.city,_that.region,_that.latitude,_that.longitude,_that.distanceM);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NearbyStopResponse implements NearbyStopResponse {
  const _NearbyStopResponse({required this.id, required this.name, this.code, this.address, this.city, this.region, required this.latitude, required this.longitude, required this.distanceM});
  factory _NearbyStopResponse.fromJson(Map<String, dynamic> json) => _$NearbyStopResponseFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? code;
@override final  String? address;
@override final  String? city;
@override final  String? region;
@override final  double latitude;
@override final  double longitude;
/// Metres from the point asked about.
@override final  double distanceM;

/// Create a copy of NearbyStopResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NearbyStopResponseCopyWith<_NearbyStopResponse> get copyWith => __$NearbyStopResponseCopyWithImpl<_NearbyStopResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NearbyStopResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NearbyStopResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.distanceM, distanceM) || other.distanceM == distanceM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,code,address,city,region,latitude,longitude,distanceM);

@override
String toString() {
  return 'NearbyStopResponse(id: $id, name: $name, code: $code, address: $address, city: $city, region: $region, latitude: $latitude, longitude: $longitude, distanceM: $distanceM)';
}


}

/// @nodoc
abstract mixin class _$NearbyStopResponseCopyWith<$Res> implements $NearbyStopResponseCopyWith<$Res> {
  factory _$NearbyStopResponseCopyWith(_NearbyStopResponse value, $Res Function(_NearbyStopResponse) _then) = __$NearbyStopResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? code, String? address, String? city, String? region, double latitude, double longitude, double distanceM
});




}
/// @nodoc
class __$NearbyStopResponseCopyWithImpl<$Res>
    implements _$NearbyStopResponseCopyWith<$Res> {
  __$NearbyStopResponseCopyWithImpl(this._self, this._then);

  final _NearbyStopResponse _self;
  final $Res Function(_NearbyStopResponse) _then;

/// Create a copy of NearbyStopResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? code = freezed,Object? address = freezed,Object? city = freezed,Object? region = freezed,Object? latitude = null,Object? longitude = null,Object? distanceM = null,}) {
  return _then(_NearbyStopResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
