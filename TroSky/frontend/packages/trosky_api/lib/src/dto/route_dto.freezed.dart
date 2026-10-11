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
mixin _$FareSummaryResponse {

/// Per seat right now, before TroSky's platform fee.
@JsonKey(fromJson: decimalString) String get current;/// Per seat with nobody to share the trip: the crossed-out price.
@JsonKey(fromJson: decimalString) String get solo;/// The lowest the per-seat price can reach if every free seat fills.
@JsonKey(fromJson: decimalString) String get minimum;/// TroSky's fee for all [seats].
@JsonKey(fromJson: decimalString) String get platformFee;/// What booking [seats] costs now: [current] × [seats] + [platformFee].
@JsonKey(fromJson: decimalString) String get total; String get currency;/// Seats already taken on the trip.
 int get ridersCount; int get seats;
/// Create a copy of FareSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FareSummaryResponseCopyWith<FareSummaryResponse> get copyWith => _$FareSummaryResponseCopyWithImpl<FareSummaryResponse>(this as FareSummaryResponse, _$identity);

  /// Serializes this FareSummaryResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FareSummaryResponse&&(identical(other.current, current) || other.current == current)&&(identical(other.solo, solo) || other.solo == solo)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.platformFee, platformFee) || other.platformFee == platformFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount)&&(identical(other.seats, seats) || other.seats == seats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,current,solo,minimum,platformFee,total,currency,ridersCount,seats);

@override
String toString() {
  return 'FareSummaryResponse(current: $current, solo: $solo, minimum: $minimum, platformFee: $platformFee, total: $total, currency: $currency, ridersCount: $ridersCount, seats: $seats)';
}


}

/// @nodoc
abstract mixin class $FareSummaryResponseCopyWith<$Res>  {
  factory $FareSummaryResponseCopyWith(FareSummaryResponse value, $Res Function(FareSummaryResponse) _then) = _$FareSummaryResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: decimalString) String current,@JsonKey(fromJson: decimalString) String solo,@JsonKey(fromJson: decimalString) String minimum,@JsonKey(fromJson: decimalString) String platformFee,@JsonKey(fromJson: decimalString) String total, String currency, int ridersCount, int seats
});




}
/// @nodoc
class _$FareSummaryResponseCopyWithImpl<$Res>
    implements $FareSummaryResponseCopyWith<$Res> {
  _$FareSummaryResponseCopyWithImpl(this._self, this._then);

  final FareSummaryResponse _self;
  final $Res Function(FareSummaryResponse) _then;

/// Create a copy of FareSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? current = null,Object? solo = null,Object? minimum = null,Object? platformFee = null,Object? total = null,Object? currency = null,Object? ridersCount = null,Object? seats = null,}) {
  return _then(FareSummaryResponse(
current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String,solo: null == solo ? _self.solo : solo // ignore: cast_nullable_to_non_nullable
as String,minimum: null == minimum ? _self.minimum : minimum // ignore: cast_nullable_to_non_nullable
as String,platformFee: null == platformFee ? _self.platformFee : platformFee // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,ridersCount: null == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FareSummaryResponse].
extension FareSummaryResponsePatterns on FareSummaryResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FareSummaryResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FareSummaryResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FareSummaryResponse value)  $default,){
final _that = this;
switch (_that) {
case _FareSummaryResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FareSummaryResponse value)?  $default,){
final _that = this;
switch (_that) {
case _FareSummaryResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: decimalString)  String current, @JsonKey(fromJson: decimalString)  String solo, @JsonKey(fromJson: decimalString)  String minimum, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String total,  String currency,  int ridersCount,  int seats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FareSummaryResponse() when $default != null:
return $default(_that.current,_that.solo,_that.minimum,_that.platformFee,_that.total,_that.currency,_that.ridersCount,_that.seats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: decimalString)  String current, @JsonKey(fromJson: decimalString)  String solo, @JsonKey(fromJson: decimalString)  String minimum, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String total,  String currency,  int ridersCount,  int seats)  $default,) {final _that = this;
switch (_that) {
case _FareSummaryResponse():
return $default(_that.current,_that.solo,_that.minimum,_that.platformFee,_that.total,_that.currency,_that.ridersCount,_that.seats);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: decimalString)  String current, @JsonKey(fromJson: decimalString)  String solo, @JsonKey(fromJson: decimalString)  String minimum, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String total,  String currency,  int ridersCount,  int seats)?  $default,) {final _that = this;
switch (_that) {
case _FareSummaryResponse() when $default != null:
return $default(_that.current,_that.solo,_that.minimum,_that.platformFee,_that.total,_that.currency,_that.ridersCount,_that.seats);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FareSummaryResponse implements FareSummaryResponse {
  const _FareSummaryResponse({@JsonKey(fromJson: decimalString) required this.current, @JsonKey(fromJson: decimalString) required this.solo, @JsonKey(fromJson: decimalString) required this.minimum, @JsonKey(fromJson: decimalString) required this.platformFee, @JsonKey(fromJson: decimalString) required this.total, required this.currency, required this.ridersCount, required this.seats});
  factory _FareSummaryResponse.fromJson(Map<String, dynamic> json) => _$FareSummaryResponseFromJson(json);

/// Per seat right now, before TroSky's platform fee.
@override@JsonKey(fromJson: decimalString) final  String current;
/// Per seat with nobody to share the trip: the crossed-out price.
@override@JsonKey(fromJson: decimalString) final  String solo;
/// The lowest the per-seat price can reach if every free seat fills.
@override@JsonKey(fromJson: decimalString) final  String minimum;
/// TroSky's fee for all [seats].
@override@JsonKey(fromJson: decimalString) final  String platformFee;
/// What booking [seats] costs now: [current] × [seats] + [platformFee].
@override@JsonKey(fromJson: decimalString) final  String total;
@override final  String currency;
/// Seats already taken on the trip.
@override final  int ridersCount;
@override final  int seats;

/// Create a copy of FareSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FareSummaryResponseCopyWith<_FareSummaryResponse> get copyWith => __$FareSummaryResponseCopyWithImpl<_FareSummaryResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FareSummaryResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FareSummaryResponse&&(identical(other.current, current) || other.current == current)&&(identical(other.solo, solo) || other.solo == solo)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.platformFee, platformFee) || other.platformFee == platformFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount)&&(identical(other.seats, seats) || other.seats == seats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,current,solo,minimum,platformFee,total,currency,ridersCount,seats);

@override
String toString() {
  return 'FareSummaryResponse(current: $current, solo: $solo, minimum: $minimum, platformFee: $platformFee, total: $total, currency: $currency, ridersCount: $ridersCount, seats: $seats)';
}


}

/// @nodoc
abstract mixin class _$FareSummaryResponseCopyWith<$Res> implements $FareSummaryResponseCopyWith<$Res> {
  factory _$FareSummaryResponseCopyWith(_FareSummaryResponse value, $Res Function(_FareSummaryResponse) _then) = __$FareSummaryResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: decimalString) String current,@JsonKey(fromJson: decimalString) String solo,@JsonKey(fromJson: decimalString) String minimum,@JsonKey(fromJson: decimalString) String platformFee,@JsonKey(fromJson: decimalString) String total, String currency, int ridersCount, int seats
});




}
/// @nodoc
class __$FareSummaryResponseCopyWithImpl<$Res>
    implements _$FareSummaryResponseCopyWith<$Res> {
  __$FareSummaryResponseCopyWithImpl(this._self, this._then);

  final _FareSummaryResponse _self;
  final $Res Function(_FareSummaryResponse) _then;

/// Create a copy of FareSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? current = null,Object? solo = null,Object? minimum = null,Object? platformFee = null,Object? total = null,Object? currency = null,Object? ridersCount = null,Object? seats = null,}) {
  return _then(_FareSummaryResponse(
current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String,solo: null == solo ? _self.solo : solo // ignore: cast_nullable_to_non_nullable
as String,minimum: null == minimum ? _self.minimum : minimum // ignore: cast_nullable_to_non_nullable
as String,platformFee: null == platformFee ? _self.platformFee : platformFee // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,ridersCount: null == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$FareQuoteResponse {

 String get tripId; String get originStopId; String get destinationStopId;@JsonKey(fromJson: decimalString) String get current;@JsonKey(fromJson: decimalString) String get solo;@JsonKey(fromJson: decimalString) String get minimum;@JsonKey(fromJson: decimalString) String get platformFee;@JsonKey(fromJson: decimalString) String get total; String get currency; int get ridersCount; int get seats;
/// Create a copy of FareQuoteResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FareQuoteResponseCopyWith<FareQuoteResponse> get copyWith => _$FareQuoteResponseCopyWithImpl<FareQuoteResponse>(this as FareQuoteResponse, _$identity);

  /// Serializes this FareQuoteResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FareQuoteResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.current, current) || other.current == current)&&(identical(other.solo, solo) || other.solo == solo)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.platformFee, platformFee) || other.platformFee == platformFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount)&&(identical(other.seats, seats) || other.seats == seats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,originStopId,destinationStopId,current,solo,minimum,platformFee,total,currency,ridersCount,seats);

@override
String toString() {
  return 'FareQuoteResponse(tripId: $tripId, originStopId: $originStopId, destinationStopId: $destinationStopId, current: $current, solo: $solo, minimum: $minimum, platformFee: $platformFee, total: $total, currency: $currency, ridersCount: $ridersCount, seats: $seats)';
}


}

/// @nodoc
abstract mixin class $FareQuoteResponseCopyWith<$Res>  {
  factory $FareQuoteResponseCopyWith(FareQuoteResponse value, $Res Function(FareQuoteResponse) _then) = _$FareQuoteResponseCopyWithImpl;
@useResult
$Res call({
 String tripId, String originStopId, String destinationStopId,@JsonKey(fromJson: decimalString) String current,@JsonKey(fromJson: decimalString) String solo,@JsonKey(fromJson: decimalString) String minimum,@JsonKey(fromJson: decimalString) String platformFee,@JsonKey(fromJson: decimalString) String total, String currency, int ridersCount, int seats
});




}
/// @nodoc
class _$FareQuoteResponseCopyWithImpl<$Res>
    implements $FareQuoteResponseCopyWith<$Res> {
  _$FareQuoteResponseCopyWithImpl(this._self, this._then);

  final FareQuoteResponse _self;
  final $Res Function(FareQuoteResponse) _then;

/// Create a copy of FareQuoteResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tripId = null,Object? originStopId = null,Object? destinationStopId = null,Object? current = null,Object? solo = null,Object? minimum = null,Object? platformFee = null,Object? total = null,Object? currency = null,Object? ridersCount = null,Object? seats = null,}) {
  return _then(FareQuoteResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String,solo: null == solo ? _self.solo : solo // ignore: cast_nullable_to_non_nullable
as String,minimum: null == minimum ? _self.minimum : minimum // ignore: cast_nullable_to_non_nullable
as String,platformFee: null == platformFee ? _self.platformFee : platformFee // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,ridersCount: null == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FareQuoteResponse].
extension FareQuoteResponsePatterns on FareQuoteResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FareQuoteResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FareQuoteResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FareQuoteResponse value)  $default,){
final _that = this;
switch (_that) {
case _FareQuoteResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FareQuoteResponse value)?  $default,){
final _that = this;
switch (_that) {
case _FareQuoteResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tripId,  String originStopId,  String destinationStopId, @JsonKey(fromJson: decimalString)  String current, @JsonKey(fromJson: decimalString)  String solo, @JsonKey(fromJson: decimalString)  String minimum, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String total,  String currency,  int ridersCount,  int seats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FareQuoteResponse() when $default != null:
return $default(_that.tripId,_that.originStopId,_that.destinationStopId,_that.current,_that.solo,_that.minimum,_that.platformFee,_that.total,_that.currency,_that.ridersCount,_that.seats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tripId,  String originStopId,  String destinationStopId, @JsonKey(fromJson: decimalString)  String current, @JsonKey(fromJson: decimalString)  String solo, @JsonKey(fromJson: decimalString)  String minimum, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String total,  String currency,  int ridersCount,  int seats)  $default,) {final _that = this;
switch (_that) {
case _FareQuoteResponse():
return $default(_that.tripId,_that.originStopId,_that.destinationStopId,_that.current,_that.solo,_that.minimum,_that.platformFee,_that.total,_that.currency,_that.ridersCount,_that.seats);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tripId,  String originStopId,  String destinationStopId, @JsonKey(fromJson: decimalString)  String current, @JsonKey(fromJson: decimalString)  String solo, @JsonKey(fromJson: decimalString)  String minimum, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String total,  String currency,  int ridersCount,  int seats)?  $default,) {final _that = this;
switch (_that) {
case _FareQuoteResponse() when $default != null:
return $default(_that.tripId,_that.originStopId,_that.destinationStopId,_that.current,_that.solo,_that.minimum,_that.platformFee,_that.total,_that.currency,_that.ridersCount,_that.seats);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FareQuoteResponse extends FareQuoteResponse {
  const _FareQuoteResponse({required this.tripId, required this.originStopId, required this.destinationStopId, @JsonKey(fromJson: decimalString) required this.current, @JsonKey(fromJson: decimalString) required this.solo, @JsonKey(fromJson: decimalString) required this.minimum, @JsonKey(fromJson: decimalString) required this.platformFee, @JsonKey(fromJson: decimalString) required this.total, required this.currency, required this.ridersCount, required this.seats}): super._();
  factory _FareQuoteResponse.fromJson(Map<String, dynamic> json) => _$FareQuoteResponseFromJson(json);

@override final  String tripId;
@override final  String originStopId;
@override final  String destinationStopId;
@override@JsonKey(fromJson: decimalString) final  String current;
@override@JsonKey(fromJson: decimalString) final  String solo;
@override@JsonKey(fromJson: decimalString) final  String minimum;
@override@JsonKey(fromJson: decimalString) final  String platformFee;
@override@JsonKey(fromJson: decimalString) final  String total;
@override final  String currency;
@override final  int ridersCount;
@override final  int seats;

/// Create a copy of FareQuoteResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FareQuoteResponseCopyWith<_FareQuoteResponse> get copyWith => __$FareQuoteResponseCopyWithImpl<_FareQuoteResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FareQuoteResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FareQuoteResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.current, current) || other.current == current)&&(identical(other.solo, solo) || other.solo == solo)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.platformFee, platformFee) || other.platformFee == platformFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount)&&(identical(other.seats, seats) || other.seats == seats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,originStopId,destinationStopId,current,solo,minimum,platformFee,total,currency,ridersCount,seats);

@override
String toString() {
  return 'FareQuoteResponse(tripId: $tripId, originStopId: $originStopId, destinationStopId: $destinationStopId, current: $current, solo: $solo, minimum: $minimum, platformFee: $platformFee, total: $total, currency: $currency, ridersCount: $ridersCount, seats: $seats)';
}


}

/// @nodoc
abstract mixin class _$FareQuoteResponseCopyWith<$Res> implements $FareQuoteResponseCopyWith<$Res> {
  factory _$FareQuoteResponseCopyWith(_FareQuoteResponse value, $Res Function(_FareQuoteResponse) _then) = __$FareQuoteResponseCopyWithImpl;
@override @useResult
$Res call({
 String tripId, String originStopId, String destinationStopId,@JsonKey(fromJson: decimalString) String current,@JsonKey(fromJson: decimalString) String solo,@JsonKey(fromJson: decimalString) String minimum,@JsonKey(fromJson: decimalString) String platformFee,@JsonKey(fromJson: decimalString) String total, String currency, int ridersCount, int seats
});




}
/// @nodoc
class __$FareQuoteResponseCopyWithImpl<$Res>
    implements _$FareQuoteResponseCopyWith<$Res> {
  __$FareQuoteResponseCopyWithImpl(this._self, this._then);

  final _FareQuoteResponse _self;
  final $Res Function(_FareQuoteResponse) _then;

/// Create a copy of FareQuoteResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tripId = null,Object? originStopId = null,Object? destinationStopId = null,Object? current = null,Object? solo = null,Object? minimum = null,Object? platformFee = null,Object? total = null,Object? currency = null,Object? ridersCount = null,Object? seats = null,}) {
  return _then(_FareQuoteResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String,solo: null == solo ? _self.solo : solo // ignore: cast_nullable_to_non_nullable
as String,minimum: null == minimum ? _self.minimum : minimum // ignore: cast_nullable_to_non_nullable
as String,platformFee: null == platformFee ? _self.platformFee : platformFee // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,ridersCount: null == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TripSearchResultResponse {

 String get tripId; String get routeId; String get routeName; String get originStopId; String get destinationStopId; DateTime get scheduledDepartureAt; DateTime? get scheduledArrivalAt; int? get estimatedDurationMinutes;@JsonKey(fromJson: decimalOrNull) double? get distanceKm;/// The trip's fare in cedis, exactly as sent ("8.00").
@JsonKey(fromJson: decimalString) String get fareAmount;@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus get status; int get availableSeats; String? get vehicleRegistrationNumber;@JsonKey(unknownEnumValue: VehicleType.other) VehicleType? get vehicleType; String? get pickupStopId; String? get pickupStopName; double? get pickupDistanceM; PickupSource? get pickupSource;/// The price of one seat from the pickup to the searched destination
/// (G20, backend 0.13.0). Null only from an older backend.
 FareSummaryResponse? get fare;/// Scheduled minutes from the pickup to the destination.
 int? get rideMinutes;/// Minutes until a vehicle already on the road reaches the pickup (0:
/// there now). Null for trips that haven't set off (G21).
 int? get vehicleEtaToPickupMinutes;/// The vehicle already passed the pickup and can't be booked from it.
 bool get hasPassedPickup;
/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripSearchResultResponseCopyWith<TripSearchResultResponse> get copyWith => _$TripSearchResultResponseCopyWithImpl<TripSearchResultResponse>(this as TripSearchResultResponse, _$identity);

  /// Serializes this TripSearchResultResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripSearchResultResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.scheduledArrivalAt, scheduledArrivalAt) || other.scheduledArrivalAt == scheduledArrivalAt)&&(identical(other.estimatedDurationMinutes, estimatedDurationMinutes) || other.estimatedDurationMinutes == estimatedDurationMinutes)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.pickupStopId, pickupStopId) || other.pickupStopId == pickupStopId)&&(identical(other.pickupStopName, pickupStopName) || other.pickupStopName == pickupStopName)&&(identical(other.pickupDistanceM, pickupDistanceM) || other.pickupDistanceM == pickupDistanceM)&&(identical(other.pickupSource, pickupSource) || other.pickupSource == pickupSource)&&(identical(other.fare, fare) || other.fare == fare)&&(identical(other.rideMinutes, rideMinutes) || other.rideMinutes == rideMinutes)&&(identical(other.vehicleEtaToPickupMinutes, vehicleEtaToPickupMinutes) || other.vehicleEtaToPickupMinutes == vehicleEtaToPickupMinutes)&&(identical(other.hasPassedPickup, hasPassedPickup) || other.hasPassedPickup == hasPassedPickup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,tripId,routeId,routeName,originStopId,destinationStopId,scheduledDepartureAt,scheduledArrivalAt,estimatedDurationMinutes,distanceKm,fareAmount,status,availableSeats,vehicleRegistrationNumber,vehicleType,pickupStopId,pickupStopName,pickupDistanceM,pickupSource,fare,rideMinutes,vehicleEtaToPickupMinutes,hasPassedPickup]);

@override
String toString() {
  return 'TripSearchResultResponse(tripId: $tripId, routeId: $routeId, routeName: $routeName, originStopId: $originStopId, destinationStopId: $destinationStopId, scheduledDepartureAt: $scheduledDepartureAt, scheduledArrivalAt: $scheduledArrivalAt, estimatedDurationMinutes: $estimatedDurationMinutes, distanceKm: $distanceKm, fareAmount: $fareAmount, status: $status, availableSeats: $availableSeats, vehicleRegistrationNumber: $vehicleRegistrationNumber, vehicleType: $vehicleType, pickupStopId: $pickupStopId, pickupStopName: $pickupStopName, pickupDistanceM: $pickupDistanceM, pickupSource: $pickupSource, fare: $fare, rideMinutes: $rideMinutes, vehicleEtaToPickupMinutes: $vehicleEtaToPickupMinutes, hasPassedPickup: $hasPassedPickup)';
}


}

/// @nodoc
abstract mixin class $TripSearchResultResponseCopyWith<$Res>  {
  factory $TripSearchResultResponseCopyWith(TripSearchResultResponse value, $Res Function(TripSearchResultResponse) _then) = _$TripSearchResultResponseCopyWithImpl;
@useResult
$Res call({
 String tripId, String routeId, String routeName, String originStopId, String destinationStopId, DateTime scheduledDepartureAt, DateTime? scheduledArrivalAt, int? estimatedDurationMinutes,@JsonKey(fromJson: decimalOrNull) double? distanceKm,@JsonKey(fromJson: decimalString) String fareAmount,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status, int availableSeats, String? vehicleRegistrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType? vehicleType, String? pickupStopId, String? pickupStopName, double? pickupDistanceM, PickupSource? pickupSource, FareSummaryResponse? fare, int? rideMinutes, int? vehicleEtaToPickupMinutes, bool hasPassedPickup
});


$FareSummaryResponseCopyWith<$Res>? get fare;

}
/// @nodoc
class _$TripSearchResultResponseCopyWithImpl<$Res>
    implements $TripSearchResultResponseCopyWith<$Res> {
  _$TripSearchResultResponseCopyWithImpl(this._self, this._then);

  final TripSearchResultResponse _self;
  final $Res Function(TripSearchResultResponse) _then;

/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tripId = null,Object? routeId = null,Object? routeName = null,Object? originStopId = null,Object? destinationStopId = null,Object? scheduledDepartureAt = null,Object? scheduledArrivalAt = freezed,Object? estimatedDurationMinutes = freezed,Object? distanceKm = freezed,Object? fareAmount = null,Object? status = null,Object? availableSeats = null,Object? vehicleRegistrationNumber = freezed,Object? vehicleType = freezed,Object? pickupStopId = freezed,Object? pickupStopName = freezed,Object? pickupDistanceM = freezed,Object? pickupSource = freezed,Object? fare = freezed,Object? rideMinutes = freezed,Object? vehicleEtaToPickupMinutes = freezed,Object? hasPassedPickup = null,}) {
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
as PickupSource?,fare: freezed == fare ? _self.fare : fare // ignore: cast_nullable_to_non_nullable
as FareSummaryResponse?,rideMinutes: freezed == rideMinutes ? _self.rideMinutes : rideMinutes // ignore: cast_nullable_to_non_nullable
as int?,vehicleEtaToPickupMinutes: freezed == vehicleEtaToPickupMinutes ? _self.vehicleEtaToPickupMinutes : vehicleEtaToPickupMinutes // ignore: cast_nullable_to_non_nullable
as int?,hasPassedPickup: null == hasPassedPickup ? _self.hasPassedPickup : hasPassedPickup // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FareSummaryResponseCopyWith<$Res>? get fare {
    if (_self.fare == null) {
    return null;
  }

  return $FareSummaryResponseCopyWith<$Res>(_self.fare!, (value) {
    return _then(_self.copyWith(fare: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tripId,  String routeId,  String routeName,  String originStopId,  String destinationStopId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  int? estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull)  double? distanceKm, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  int availableSeats,  String? vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType? vehicleType,  String? pickupStopId,  String? pickupStopName,  double? pickupDistanceM,  PickupSource? pickupSource,  FareSummaryResponse? fare,  int? rideMinutes,  int? vehicleEtaToPickupMinutes,  bool hasPassedPickup)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripSearchResultResponse() when $default != null:
return $default(_that.tripId,_that.routeId,_that.routeName,_that.originStopId,_that.destinationStopId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.estimatedDurationMinutes,_that.distanceKm,_that.fareAmount,_that.status,_that.availableSeats,_that.vehicleRegistrationNumber,_that.vehicleType,_that.pickupStopId,_that.pickupStopName,_that.pickupDistanceM,_that.pickupSource,_that.fare,_that.rideMinutes,_that.vehicleEtaToPickupMinutes,_that.hasPassedPickup);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tripId,  String routeId,  String routeName,  String originStopId,  String destinationStopId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  int? estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull)  double? distanceKm, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  int availableSeats,  String? vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType? vehicleType,  String? pickupStopId,  String? pickupStopName,  double? pickupDistanceM,  PickupSource? pickupSource,  FareSummaryResponse? fare,  int? rideMinutes,  int? vehicleEtaToPickupMinutes,  bool hasPassedPickup)  $default,) {final _that = this;
switch (_that) {
case _TripSearchResultResponse():
return $default(_that.tripId,_that.routeId,_that.routeName,_that.originStopId,_that.destinationStopId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.estimatedDurationMinutes,_that.distanceKm,_that.fareAmount,_that.status,_that.availableSeats,_that.vehicleRegistrationNumber,_that.vehicleType,_that.pickupStopId,_that.pickupStopName,_that.pickupDistanceM,_that.pickupSource,_that.fare,_that.rideMinutes,_that.vehicleEtaToPickupMinutes,_that.hasPassedPickup);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tripId,  String routeId,  String routeName,  String originStopId,  String destinationStopId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  int? estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull)  double? distanceKm, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  int availableSeats,  String? vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType? vehicleType,  String? pickupStopId,  String? pickupStopName,  double? pickupDistanceM,  PickupSource? pickupSource,  FareSummaryResponse? fare,  int? rideMinutes,  int? vehicleEtaToPickupMinutes,  bool hasPassedPickup)?  $default,) {final _that = this;
switch (_that) {
case _TripSearchResultResponse() when $default != null:
return $default(_that.tripId,_that.routeId,_that.routeName,_that.originStopId,_that.destinationStopId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.estimatedDurationMinutes,_that.distanceKm,_that.fareAmount,_that.status,_that.availableSeats,_that.vehicleRegistrationNumber,_that.vehicleType,_that.pickupStopId,_that.pickupStopName,_that.pickupDistanceM,_that.pickupSource,_that.fare,_that.rideMinutes,_that.vehicleEtaToPickupMinutes,_that.hasPassedPickup);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripSearchResultResponse implements TripSearchResultResponse {
  const _TripSearchResultResponse({required this.tripId, required this.routeId, required this.routeName, required this.originStopId, required this.destinationStopId, required this.scheduledDepartureAt, this.scheduledArrivalAt, this.estimatedDurationMinutes, @JsonKey(fromJson: decimalOrNull) this.distanceKm, @JsonKey(fromJson: decimalString) required this.fareAmount, @JsonKey(unknownEnumValue: TripStatus.scheduled) required this.status, required this.availableSeats, this.vehicleRegistrationNumber, @JsonKey(unknownEnumValue: VehicleType.other) this.vehicleType, this.pickupStopId, this.pickupStopName, this.pickupDistanceM, this.pickupSource, this.fare, this.rideMinutes, this.vehicleEtaToPickupMinutes, this.hasPassedPickup = false});
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
/// The price of one seat from the pickup to the searched destination
/// (G20, backend 0.13.0). Null only from an older backend.
@override final  FareSummaryResponse? fare;
/// Scheduled minutes from the pickup to the destination.
@override final  int? rideMinutes;
/// Minutes until a vehicle already on the road reaches the pickup (0:
/// there now). Null for trips that haven't set off (G21).
@override final  int? vehicleEtaToPickupMinutes;
/// The vehicle already passed the pickup and can't be booked from it.
@override@JsonKey() final  bool hasPassedPickup;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripSearchResultResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.scheduledArrivalAt, scheduledArrivalAt) || other.scheduledArrivalAt == scheduledArrivalAt)&&(identical(other.estimatedDurationMinutes, estimatedDurationMinutes) || other.estimatedDurationMinutes == estimatedDurationMinutes)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.pickupStopId, pickupStopId) || other.pickupStopId == pickupStopId)&&(identical(other.pickupStopName, pickupStopName) || other.pickupStopName == pickupStopName)&&(identical(other.pickupDistanceM, pickupDistanceM) || other.pickupDistanceM == pickupDistanceM)&&(identical(other.pickupSource, pickupSource) || other.pickupSource == pickupSource)&&(identical(other.fare, fare) || other.fare == fare)&&(identical(other.rideMinutes, rideMinutes) || other.rideMinutes == rideMinutes)&&(identical(other.vehicleEtaToPickupMinutes, vehicleEtaToPickupMinutes) || other.vehicleEtaToPickupMinutes == vehicleEtaToPickupMinutes)&&(identical(other.hasPassedPickup, hasPassedPickup) || other.hasPassedPickup == hasPassedPickup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,tripId,routeId,routeName,originStopId,destinationStopId,scheduledDepartureAt,scheduledArrivalAt,estimatedDurationMinutes,distanceKm,fareAmount,status,availableSeats,vehicleRegistrationNumber,vehicleType,pickupStopId,pickupStopName,pickupDistanceM,pickupSource,fare,rideMinutes,vehicleEtaToPickupMinutes,hasPassedPickup]);

@override
String toString() {
  return 'TripSearchResultResponse(tripId: $tripId, routeId: $routeId, routeName: $routeName, originStopId: $originStopId, destinationStopId: $destinationStopId, scheduledDepartureAt: $scheduledDepartureAt, scheduledArrivalAt: $scheduledArrivalAt, estimatedDurationMinutes: $estimatedDurationMinutes, distanceKm: $distanceKm, fareAmount: $fareAmount, status: $status, availableSeats: $availableSeats, vehicleRegistrationNumber: $vehicleRegistrationNumber, vehicleType: $vehicleType, pickupStopId: $pickupStopId, pickupStopName: $pickupStopName, pickupDistanceM: $pickupDistanceM, pickupSource: $pickupSource, fare: $fare, rideMinutes: $rideMinutes, vehicleEtaToPickupMinutes: $vehicleEtaToPickupMinutes, hasPassedPickup: $hasPassedPickup)';
}


}

/// @nodoc
abstract mixin class _$TripSearchResultResponseCopyWith<$Res> implements $TripSearchResultResponseCopyWith<$Res> {
  factory _$TripSearchResultResponseCopyWith(_TripSearchResultResponse value, $Res Function(_TripSearchResultResponse) _then) = __$TripSearchResultResponseCopyWithImpl;
@override @useResult
$Res call({
 String tripId, String routeId, String routeName, String originStopId, String destinationStopId, DateTime scheduledDepartureAt, DateTime? scheduledArrivalAt, int? estimatedDurationMinutes,@JsonKey(fromJson: decimalOrNull) double? distanceKm,@JsonKey(fromJson: decimalString) String fareAmount,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status, int availableSeats, String? vehicleRegistrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType? vehicleType, String? pickupStopId, String? pickupStopName, double? pickupDistanceM, PickupSource? pickupSource, FareSummaryResponse? fare, int? rideMinutes, int? vehicleEtaToPickupMinutes, bool hasPassedPickup
});


@override $FareSummaryResponseCopyWith<$Res>? get fare;

}
/// @nodoc
class __$TripSearchResultResponseCopyWithImpl<$Res>
    implements _$TripSearchResultResponseCopyWith<$Res> {
  __$TripSearchResultResponseCopyWithImpl(this._self, this._then);

  final _TripSearchResultResponse _self;
  final $Res Function(_TripSearchResultResponse) _then;

/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tripId = null,Object? routeId = null,Object? routeName = null,Object? originStopId = null,Object? destinationStopId = null,Object? scheduledDepartureAt = null,Object? scheduledArrivalAt = freezed,Object? estimatedDurationMinutes = freezed,Object? distanceKm = freezed,Object? fareAmount = null,Object? status = null,Object? availableSeats = null,Object? vehicleRegistrationNumber = freezed,Object? vehicleType = freezed,Object? pickupStopId = freezed,Object? pickupStopName = freezed,Object? pickupDistanceM = freezed,Object? pickupSource = freezed,Object? fare = freezed,Object? rideMinutes = freezed,Object? vehicleEtaToPickupMinutes = freezed,Object? hasPassedPickup = null,}) {
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
as PickupSource?,fare: freezed == fare ? _self.fare : fare // ignore: cast_nullable_to_non_nullable
as FareSummaryResponse?,rideMinutes: freezed == rideMinutes ? _self.rideMinutes : rideMinutes // ignore: cast_nullable_to_non_nullable
as int?,vehicleEtaToPickupMinutes: freezed == vehicleEtaToPickupMinutes ? _self.vehicleEtaToPickupMinutes : vehicleEtaToPickupMinutes // ignore: cast_nullable_to_non_nullable
as int?,hasPassedPickup: null == hasPassedPickup ? _self.hasPassedPickup : hasPassedPickup // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of TripSearchResultResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FareSummaryResponseCopyWith<$Res>? get fare {
    if (_self.fare == null) {
    return null;
  }

  return $FareSummaryResponseCopyWith<$Res>(_self.fare!, (value) {
    return _then(_self.copyWith(fare: value));
  });
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
