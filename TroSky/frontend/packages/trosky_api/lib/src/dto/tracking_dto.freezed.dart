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
mixin _$LiveLocationResponse {

 String get tripId; double get latitude; double get longitude;@JsonKey(fromJson: decimalOrNull) double? get speedKmh;@JsonKey(fromJson: decimalOrNull) double? get headingDegrees; DateTime get recordedAt; bool get isStale;@JsonKey(unknownEnumValue: null) TripStatus? get tripStatus;/// Current per-seat fare, split across confirmed riders (PR #89).
/// Null only from a legacy cache before the backend was deployed.
@JsonKey(fromJson: decimalOrNull) double? get liveFarePerSeat;/// Count of confirmed/completed bookings on this trip. Null from a
/// legacy cache.
 int? get ridersCount;
/// Create a copy of LiveLocationResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveLocationResponseCopyWith<LiveLocationResponse> get copyWith => _$LiveLocationResponseCopyWithImpl<LiveLocationResponse>(this as LiveLocationResponse, _$identity);

  /// Serializes this LiveLocationResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveLocationResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speedKmh, speedKmh) || other.speedKmh == speedKmh)&&(identical(other.headingDegrees, headingDegrees) || other.headingDegrees == headingDegrees)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.isStale, isStale) || other.isStale == isStale)&&(identical(other.tripStatus, tripStatus) || other.tripStatus == tripStatus)&&(identical(other.liveFarePerSeat, liveFarePerSeat) || other.liveFarePerSeat == liveFarePerSeat)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,latitude,longitude,speedKmh,headingDegrees,recordedAt,isStale,tripStatus,liveFarePerSeat,ridersCount);

@override
String toString() {
  return 'LiveLocationResponse(tripId: $tripId, latitude: $latitude, longitude: $longitude, speedKmh: $speedKmh, headingDegrees: $headingDegrees, recordedAt: $recordedAt, isStale: $isStale, tripStatus: $tripStatus, liveFarePerSeat: $liveFarePerSeat, ridersCount: $ridersCount)';
}


}

/// @nodoc
abstract mixin class $LiveLocationResponseCopyWith<$Res>  {
  factory $LiveLocationResponseCopyWith(LiveLocationResponse value, $Res Function(LiveLocationResponse) _then) = _$LiveLocationResponseCopyWithImpl;
@useResult
$Res call({
 String tripId, double latitude, double longitude,@JsonKey(fromJson: decimalOrNull) double? speedKmh,@JsonKey(fromJson: decimalOrNull) double? headingDegrees, DateTime recordedAt, bool isStale,@JsonKey(unknownEnumValue: null) TripStatus? tripStatus,@JsonKey(fromJson: decimalOrNull) double? liveFarePerSeat, int? ridersCount
});




}
/// @nodoc
class _$LiveLocationResponseCopyWithImpl<$Res>
    implements $LiveLocationResponseCopyWith<$Res> {
  _$LiveLocationResponseCopyWithImpl(this._self, this._then);

  final LiveLocationResponse _self;
  final $Res Function(LiveLocationResponse) _then;

/// Create a copy of LiveLocationResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tripId = null,Object? latitude = null,Object? longitude = null,Object? speedKmh = freezed,Object? headingDegrees = freezed,Object? recordedAt = null,Object? isStale = null,Object? tripStatus = freezed,Object? liveFarePerSeat = freezed,Object? ridersCount = freezed,}) {
  return _then(LiveLocationResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,speedKmh: freezed == speedKmh ? _self.speedKmh : speedKmh // ignore: cast_nullable_to_non_nullable
as double?,headingDegrees: freezed == headingDegrees ? _self.headingDegrees : headingDegrees // ignore: cast_nullable_to_non_nullable
as double?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,tripStatus: freezed == tripStatus ? _self.tripStatus : tripStatus // ignore: cast_nullable_to_non_nullable
as TripStatus?,liveFarePerSeat: freezed == liveFarePerSeat ? _self.liveFarePerSeat : liveFarePerSeat // ignore: cast_nullable_to_non_nullable
as double?,ridersCount: freezed == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveLocationResponse].
extension LiveLocationResponsePatterns on LiveLocationResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveLocationResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveLocationResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveLocationResponse value)  $default,){
final _that = this;
switch (_that) {
case _LiveLocationResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveLocationResponse value)?  $default,){
final _that = this;
switch (_that) {
case _LiveLocationResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tripId,  double latitude,  double longitude, @JsonKey(fromJson: decimalOrNull)  double? speedKmh, @JsonKey(fromJson: decimalOrNull)  double? headingDegrees,  DateTime recordedAt,  bool isStale, @JsonKey(unknownEnumValue: null)  TripStatus? tripStatus, @JsonKey(fromJson: decimalOrNull)  double? liveFarePerSeat,  int? ridersCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveLocationResponse() when $default != null:
return $default(_that.tripId,_that.latitude,_that.longitude,_that.speedKmh,_that.headingDegrees,_that.recordedAt,_that.isStale,_that.tripStatus,_that.liveFarePerSeat,_that.ridersCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tripId,  double latitude,  double longitude, @JsonKey(fromJson: decimalOrNull)  double? speedKmh, @JsonKey(fromJson: decimalOrNull)  double? headingDegrees,  DateTime recordedAt,  bool isStale, @JsonKey(unknownEnumValue: null)  TripStatus? tripStatus, @JsonKey(fromJson: decimalOrNull)  double? liveFarePerSeat,  int? ridersCount)  $default,) {final _that = this;
switch (_that) {
case _LiveLocationResponse():
return $default(_that.tripId,_that.latitude,_that.longitude,_that.speedKmh,_that.headingDegrees,_that.recordedAt,_that.isStale,_that.tripStatus,_that.liveFarePerSeat,_that.ridersCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tripId,  double latitude,  double longitude, @JsonKey(fromJson: decimalOrNull)  double? speedKmh, @JsonKey(fromJson: decimalOrNull)  double? headingDegrees,  DateTime recordedAt,  bool isStale, @JsonKey(unknownEnumValue: null)  TripStatus? tripStatus, @JsonKey(fromJson: decimalOrNull)  double? liveFarePerSeat,  int? ridersCount)?  $default,) {final _that = this;
switch (_that) {
case _LiveLocationResponse() when $default != null:
return $default(_that.tripId,_that.latitude,_that.longitude,_that.speedKmh,_that.headingDegrees,_that.recordedAt,_that.isStale,_that.tripStatus,_that.liveFarePerSeat,_that.ridersCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveLocationResponse implements LiveLocationResponse {
  const _LiveLocationResponse({required this.tripId, required this.latitude, required this.longitude, @JsonKey(fromJson: decimalOrNull) this.speedKmh, @JsonKey(fromJson: decimalOrNull) this.headingDegrees, required this.recordedAt, required this.isStale, @JsonKey(unknownEnumValue: null) this.tripStatus, @JsonKey(fromJson: decimalOrNull) this.liveFarePerSeat, this.ridersCount});
  factory _LiveLocationResponse.fromJson(Map<String, dynamic> json) => _$LiveLocationResponseFromJson(json);

@override final  String tripId;
@override final  double latitude;
@override final  double longitude;
@override@JsonKey(fromJson: decimalOrNull) final  double? speedKmh;
@override@JsonKey(fromJson: decimalOrNull) final  double? headingDegrees;
@override final  DateTime recordedAt;
@override final  bool isStale;
@override@JsonKey(unknownEnumValue: null) final  TripStatus? tripStatus;
/// Current per-seat fare, split across confirmed riders (PR #89).
/// Null only from a legacy cache before the backend was deployed.
@override@JsonKey(fromJson: decimalOrNull) final  double? liveFarePerSeat;
/// Count of confirmed/completed bookings on this trip. Null from a
/// legacy cache.
@override final  int? ridersCount;

/// Create a copy of LiveLocationResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveLocationResponseCopyWith<_LiveLocationResponse> get copyWith => __$LiveLocationResponseCopyWithImpl<_LiveLocationResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveLocationResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveLocationResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speedKmh, speedKmh) || other.speedKmh == speedKmh)&&(identical(other.headingDegrees, headingDegrees) || other.headingDegrees == headingDegrees)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.isStale, isStale) || other.isStale == isStale)&&(identical(other.tripStatus, tripStatus) || other.tripStatus == tripStatus)&&(identical(other.liveFarePerSeat, liveFarePerSeat) || other.liveFarePerSeat == liveFarePerSeat)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,latitude,longitude,speedKmh,headingDegrees,recordedAt,isStale,tripStatus,liveFarePerSeat,ridersCount);

@override
String toString() {
  return 'LiveLocationResponse(tripId: $tripId, latitude: $latitude, longitude: $longitude, speedKmh: $speedKmh, headingDegrees: $headingDegrees, recordedAt: $recordedAt, isStale: $isStale, tripStatus: $tripStatus, liveFarePerSeat: $liveFarePerSeat, ridersCount: $ridersCount)';
}


}

/// @nodoc
abstract mixin class _$LiveLocationResponseCopyWith<$Res> implements $LiveLocationResponseCopyWith<$Res> {
  factory _$LiveLocationResponseCopyWith(_LiveLocationResponse value, $Res Function(_LiveLocationResponse) _then) = __$LiveLocationResponseCopyWithImpl;
@override @useResult
$Res call({
 String tripId, double latitude, double longitude,@JsonKey(fromJson: decimalOrNull) double? speedKmh,@JsonKey(fromJson: decimalOrNull) double? headingDegrees, DateTime recordedAt, bool isStale,@JsonKey(unknownEnumValue: null) TripStatus? tripStatus,@JsonKey(fromJson: decimalOrNull) double? liveFarePerSeat, int? ridersCount
});




}
/// @nodoc
class __$LiveLocationResponseCopyWithImpl<$Res>
    implements _$LiveLocationResponseCopyWith<$Res> {
  __$LiveLocationResponseCopyWithImpl(this._self, this._then);

  final _LiveLocationResponse _self;
  final $Res Function(_LiveLocationResponse) _then;

/// Create a copy of LiveLocationResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tripId = null,Object? latitude = null,Object? longitude = null,Object? speedKmh = freezed,Object? headingDegrees = freezed,Object? recordedAt = null,Object? isStale = null,Object? tripStatus = freezed,Object? liveFarePerSeat = freezed,Object? ridersCount = freezed,}) {
  return _then(_LiveLocationResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,speedKmh: freezed == speedKmh ? _self.speedKmh : speedKmh // ignore: cast_nullable_to_non_nullable
as double?,headingDegrees: freezed == headingDegrees ? _self.headingDegrees : headingDegrees // ignore: cast_nullable_to_non_nullable
as double?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,tripStatus: freezed == tripStatus ? _self.tripStatus : tripStatus // ignore: cast_nullable_to_non_nullable
as TripStatus?,liveFarePerSeat: freezed == liveFarePerSeat ? _self.liveFarePerSeat : liveFarePerSeat // ignore: cast_nullable_to_non_nullable
as double?,ridersCount: freezed == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$EtaResponse {

@JsonKey(fromJson: decimalString) String get distanceKm; int get durationMinutes; DateTime get etaAt;
/// Create a copy of EtaResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EtaResponseCopyWith<EtaResponse> get copyWith => _$EtaResponseCopyWithImpl<EtaResponse>(this as EtaResponse, _$identity);

  /// Serializes this EtaResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EtaResponse&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.etaAt, etaAt) || other.etaAt == etaAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,distanceKm,durationMinutes,etaAt);

@override
String toString() {
  return 'EtaResponse(distanceKm: $distanceKm, durationMinutes: $durationMinutes, etaAt: $etaAt)';
}


}

/// @nodoc
abstract mixin class $EtaResponseCopyWith<$Res>  {
  factory $EtaResponseCopyWith(EtaResponse value, $Res Function(EtaResponse) _then) = _$EtaResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: decimalString) String distanceKm, int durationMinutes, DateTime etaAt
});




}
/// @nodoc
class _$EtaResponseCopyWithImpl<$Res>
    implements $EtaResponseCopyWith<$Res> {
  _$EtaResponseCopyWithImpl(this._self, this._then);

  final EtaResponse _self;
  final $Res Function(EtaResponse) _then;

/// Create a copy of EtaResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? distanceKm = null,Object? durationMinutes = null,Object? etaAt = null,}) {
  return _then(EtaResponse(
distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as String,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,etaAt: null == etaAt ? _self.etaAt : etaAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EtaResponse].
extension EtaResponsePatterns on EtaResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EtaResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EtaResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EtaResponse value)  $default,){
final _that = this;
switch (_that) {
case _EtaResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EtaResponse value)?  $default,){
final _that = this;
switch (_that) {
case _EtaResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: decimalString)  String distanceKm,  int durationMinutes,  DateTime etaAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EtaResponse() when $default != null:
return $default(_that.distanceKm,_that.durationMinutes,_that.etaAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: decimalString)  String distanceKm,  int durationMinutes,  DateTime etaAt)  $default,) {final _that = this;
switch (_that) {
case _EtaResponse():
return $default(_that.distanceKm,_that.durationMinutes,_that.etaAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: decimalString)  String distanceKm,  int durationMinutes,  DateTime etaAt)?  $default,) {final _that = this;
switch (_that) {
case _EtaResponse() when $default != null:
return $default(_that.distanceKm,_that.durationMinutes,_that.etaAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EtaResponse implements EtaResponse {
  const _EtaResponse({@JsonKey(fromJson: decimalString) required this.distanceKm, required this.durationMinutes, required this.etaAt});
  factory _EtaResponse.fromJson(Map<String, dynamic> json) => _$EtaResponseFromJson(json);

@override@JsonKey(fromJson: decimalString) final  String distanceKm;
@override final  int durationMinutes;
@override final  DateTime etaAt;

/// Create a copy of EtaResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EtaResponseCopyWith<_EtaResponse> get copyWith => __$EtaResponseCopyWithImpl<_EtaResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EtaResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EtaResponse&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.etaAt, etaAt) || other.etaAt == etaAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,distanceKm,durationMinutes,etaAt);

@override
String toString() {
  return 'EtaResponse(distanceKm: $distanceKm, durationMinutes: $durationMinutes, etaAt: $etaAt)';
}


}

/// @nodoc
abstract mixin class _$EtaResponseCopyWith<$Res> implements $EtaResponseCopyWith<$Res> {
  factory _$EtaResponseCopyWith(_EtaResponse value, $Res Function(_EtaResponse) _then) = __$EtaResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: decimalString) String distanceKm, int durationMinutes, DateTime etaAt
});




}
/// @nodoc
class __$EtaResponseCopyWithImpl<$Res>
    implements _$EtaResponseCopyWith<$Res> {
  __$EtaResponseCopyWithImpl(this._self, this._then);

  final _EtaResponse _self;
  final $Res Function(_EtaResponse) _then;

/// Create a copy of EtaResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? distanceKm = null,Object? durationMinutes = null,Object? etaAt = null,}) {
  return _then(_EtaResponse(
distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as String,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,etaAt: null == etaAt ? _self.etaAt : etaAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


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
