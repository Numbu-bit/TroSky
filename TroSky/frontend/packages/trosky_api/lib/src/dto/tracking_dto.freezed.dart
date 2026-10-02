// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tracking_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NearbyVehicleResponse {

 String get tripId; String get vehicleId; String get vehicleRegistrationNumber;@JsonKey(unknownEnumValue: VehicleType.other) VehicleType get vehicleType; String get routeId; String get routeName; double get latitude; double get longitude;/// Degrees from north, when the ping had one.
@JsonKey(fromJson: decimalOrNull) double? get heading; double get distanceM; int get availableSeats; DateTime get updatedAt;
/// Create a copy of NearbyVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NearbyVehicleResponseCopyWith<NearbyVehicleResponse> get copyWith => _$NearbyVehicleResponseCopyWithImpl<NearbyVehicleResponse>(this as NearbyVehicleResponse, _$identity);

  /// Serializes this NearbyVehicleResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NearbyVehicleResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.distanceM, distanceM) || other.distanceM == distanceM)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,vehicleId,vehicleRegistrationNumber,vehicleType,routeId,routeName,latitude,longitude,heading,distanceM,availableSeats,updatedAt);

@override
String toString() {
  return 'NearbyVehicleResponse(tripId: $tripId, vehicleId: $vehicleId, vehicleRegistrationNumber: $vehicleRegistrationNumber, vehicleType: $vehicleType, routeId: $routeId, routeName: $routeName, latitude: $latitude, longitude: $longitude, heading: $heading, distanceM: $distanceM, availableSeats: $availableSeats, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $NearbyVehicleResponseCopyWith<$Res>  {
  factory $NearbyVehicleResponseCopyWith(NearbyVehicleResponse value, $Res Function(NearbyVehicleResponse) _then) = _$NearbyVehicleResponseCopyWithImpl;
@useResult
$Res call({
 String tripId, String vehicleId, String vehicleRegistrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType vehicleType, String routeId, String routeName, double latitude, double longitude,@JsonKey(fromJson: decimalOrNull) double? heading, double distanceM, int availableSeats, DateTime updatedAt
});




}
/// @nodoc
class _$NearbyVehicleResponseCopyWithImpl<$Res>
    implements $NearbyVehicleResponseCopyWith<$Res> {
  _$NearbyVehicleResponseCopyWithImpl(this._self, this._then);

  final NearbyVehicleResponse _self;
  final $Res Function(NearbyVehicleResponse) _then;

/// Create a copy of NearbyVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tripId = null,Object? vehicleId = null,Object? vehicleRegistrationNumber = null,Object? vehicleType = null,Object? routeId = null,Object? routeName = null,Object? latitude = null,Object? longitude = null,Object? heading = freezed,Object? distanceM = null,Object? availableSeats = null,Object? updatedAt = null,}) {
  return _then(NearbyVehicleResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String,vehicleRegistrationNumber: null == vehicleRegistrationNumber ? _self.vehicleRegistrationNumber : vehicleRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [NearbyVehicleResponse].
extension NearbyVehicleResponsePatterns on NearbyVehicleResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NearbyVehicleResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NearbyVehicleResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NearbyVehicleResponse value)  $default,){
final _that = this;
switch (_that) {
case _NearbyVehicleResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NearbyVehicleResponse value)?  $default,){
final _that = this;
switch (_that) {
case _NearbyVehicleResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tripId,  String vehicleId,  String vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType vehicleType,  String routeId,  String routeName,  double latitude,  double longitude, @JsonKey(fromJson: decimalOrNull)  double? heading,  double distanceM,  int availableSeats,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NearbyVehicleResponse() when $default != null:
return $default(_that.tripId,_that.vehicleId,_that.vehicleRegistrationNumber,_that.vehicleType,_that.routeId,_that.routeName,_that.latitude,_that.longitude,_that.heading,_that.distanceM,_that.availableSeats,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tripId,  String vehicleId,  String vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType vehicleType,  String routeId,  String routeName,  double latitude,  double longitude, @JsonKey(fromJson: decimalOrNull)  double? heading,  double distanceM,  int availableSeats,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _NearbyVehicleResponse():
return $default(_that.tripId,_that.vehicleId,_that.vehicleRegistrationNumber,_that.vehicleType,_that.routeId,_that.routeName,_that.latitude,_that.longitude,_that.heading,_that.distanceM,_that.availableSeats,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tripId,  String vehicleId,  String vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType vehicleType,  String routeId,  String routeName,  double latitude,  double longitude, @JsonKey(fromJson: decimalOrNull)  double? heading,  double distanceM,  int availableSeats,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _NearbyVehicleResponse() when $default != null:
return $default(_that.tripId,_that.vehicleId,_that.vehicleRegistrationNumber,_that.vehicleType,_that.routeId,_that.routeName,_that.latitude,_that.longitude,_that.heading,_that.distanceM,_that.availableSeats,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NearbyVehicleResponse implements NearbyVehicleResponse {
  const _NearbyVehicleResponse({required this.tripId, required this.vehicleId, required this.vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other) required this.vehicleType, required this.routeId, required this.routeName, required this.latitude, required this.longitude, @JsonKey(fromJson: decimalOrNull) this.heading, required this.distanceM, required this.availableSeats, required this.updatedAt});
  factory _NearbyVehicleResponse.fromJson(Map<String, dynamic> json) => _$NearbyVehicleResponseFromJson(json);

@override final  String tripId;
@override final  String vehicleId;
@override final  String vehicleRegistrationNumber;
@override@JsonKey(unknownEnumValue: VehicleType.other) final  VehicleType vehicleType;
@override final  String routeId;
@override final  String routeName;
@override final  double latitude;
@override final  double longitude;
/// Degrees from north, when the ping had one.
@override@JsonKey(fromJson: decimalOrNull) final  double? heading;
@override final  double distanceM;
@override final  int availableSeats;
@override final  DateTime updatedAt;

/// Create a copy of NearbyVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NearbyVehicleResponseCopyWith<_NearbyVehicleResponse> get copyWith => __$NearbyVehicleResponseCopyWithImpl<_NearbyVehicleResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NearbyVehicleResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NearbyVehicleResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.distanceM, distanceM) || other.distanceM == distanceM)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,vehicleId,vehicleRegistrationNumber,vehicleType,routeId,routeName,latitude,longitude,heading,distanceM,availableSeats,updatedAt);

@override
String toString() {
  return 'NearbyVehicleResponse(tripId: $tripId, vehicleId: $vehicleId, vehicleRegistrationNumber: $vehicleRegistrationNumber, vehicleType: $vehicleType, routeId: $routeId, routeName: $routeName, latitude: $latitude, longitude: $longitude, heading: $heading, distanceM: $distanceM, availableSeats: $availableSeats, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$NearbyVehicleResponseCopyWith<$Res> implements $NearbyVehicleResponseCopyWith<$Res> {
  factory _$NearbyVehicleResponseCopyWith(_NearbyVehicleResponse value, $Res Function(_NearbyVehicleResponse) _then) = __$NearbyVehicleResponseCopyWithImpl;
@override @useResult
$Res call({
 String tripId, String vehicleId, String vehicleRegistrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType vehicleType, String routeId, String routeName, double latitude, double longitude,@JsonKey(fromJson: decimalOrNull) double? heading, double distanceM, int availableSeats, DateTime updatedAt
});




}
/// @nodoc
class __$NearbyVehicleResponseCopyWithImpl<$Res>
    implements _$NearbyVehicleResponseCopyWith<$Res> {
  __$NearbyVehicleResponseCopyWithImpl(this._self, this._then);

  final _NearbyVehicleResponse _self;
  final $Res Function(_NearbyVehicleResponse) _then;

/// Create a copy of NearbyVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tripId = null,Object? vehicleId = null,Object? vehicleRegistrationNumber = null,Object? vehicleType = null,Object? routeId = null,Object? routeName = null,Object? latitude = null,Object? longitude = null,Object? heading = freezed,Object? distanceM = null,Object? availableSeats = null,Object? updatedAt = null,}) {
  return _then(_NearbyVehicleResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String,vehicleRegistrationNumber: null == vehicleRegistrationNumber ? _self.vehicleRegistrationNumber : vehicleRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
