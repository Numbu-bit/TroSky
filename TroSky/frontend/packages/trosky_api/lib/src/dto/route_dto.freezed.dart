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
