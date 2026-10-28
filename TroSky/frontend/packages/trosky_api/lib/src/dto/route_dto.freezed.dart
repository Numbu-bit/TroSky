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
mixin _$TripVehicleResponse {

 String get registrationNumber;@JsonKey(unknownEnumValue: VehicleType.other) VehicleType get type;/// "Toyota Hiace".
 String? get makeModel; int? get capacity;
/// Create a copy of TripVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripVehicleResponseCopyWith<TripVehicleResponse> get copyWith => _$TripVehicleResponseCopyWithImpl<TripVehicleResponse>(this as TripVehicleResponse, _$identity);

  /// Serializes this TripVehicleResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripVehicleResponse&&(identical(other.registrationNumber, registrationNumber) || other.registrationNumber == registrationNumber)&&(identical(other.type, type) || other.type == type)&&(identical(other.makeModel, makeModel) || other.makeModel == makeModel)&&(identical(other.capacity, capacity) || other.capacity == capacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,registrationNumber,type,makeModel,capacity);

@override
String toString() {
  return 'TripVehicleResponse(registrationNumber: $registrationNumber, type: $type, makeModel: $makeModel, capacity: $capacity)';
}


}

/// @nodoc
abstract mixin class $TripVehicleResponseCopyWith<$Res>  {
  factory $TripVehicleResponseCopyWith(TripVehicleResponse value, $Res Function(TripVehicleResponse) _then) = _$TripVehicleResponseCopyWithImpl;
@useResult
$Res call({
 String registrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType type, String? makeModel, int? capacity
});




}
/// @nodoc
class _$TripVehicleResponseCopyWithImpl<$Res>
    implements $TripVehicleResponseCopyWith<$Res> {
  _$TripVehicleResponseCopyWithImpl(this._self, this._then);

  final TripVehicleResponse _self;
  final $Res Function(TripVehicleResponse) _then;

/// Create a copy of TripVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? registrationNumber = null,Object? type = null,Object? makeModel = freezed,Object? capacity = freezed,}) {
  return _then(TripVehicleResponse(
registrationNumber: null == registrationNumber ? _self.registrationNumber : registrationNumber // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VehicleType,makeModel: freezed == makeModel ? _self.makeModel : makeModel // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TripVehicleResponse].
extension TripVehicleResponsePatterns on TripVehicleResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripVehicleResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripVehicleResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripVehicleResponse value)  $default,){
final _that = this;
switch (_that) {
case _TripVehicleResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripVehicleResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TripVehicleResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String registrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType type,  String? makeModel,  int? capacity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripVehicleResponse() when $default != null:
return $default(_that.registrationNumber,_that.type,_that.makeModel,_that.capacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String registrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType type,  String? makeModel,  int? capacity)  $default,) {final _that = this;
switch (_that) {
case _TripVehicleResponse():
return $default(_that.registrationNumber,_that.type,_that.makeModel,_that.capacity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String registrationNumber, @JsonKey(unknownEnumValue: VehicleType.other)  VehicleType type,  String? makeModel,  int? capacity)?  $default,) {final _that = this;
switch (_that) {
case _TripVehicleResponse() when $default != null:
return $default(_that.registrationNumber,_that.type,_that.makeModel,_that.capacity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripVehicleResponse implements TripVehicleResponse {
  const _TripVehicleResponse({required this.registrationNumber, @JsonKey(unknownEnumValue: VehicleType.other) required this.type, this.makeModel, this.capacity});
  factory _TripVehicleResponse.fromJson(Map<String, dynamic> json) => _$TripVehicleResponseFromJson(json);

@override final  String registrationNumber;
@override@JsonKey(unknownEnumValue: VehicleType.other) final  VehicleType type;
/// "Toyota Hiace".
@override final  String? makeModel;
@override final  int? capacity;

/// Create a copy of TripVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripVehicleResponseCopyWith<_TripVehicleResponse> get copyWith => __$TripVehicleResponseCopyWithImpl<_TripVehicleResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripVehicleResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripVehicleResponse&&(identical(other.registrationNumber, registrationNumber) || other.registrationNumber == registrationNumber)&&(identical(other.type, type) || other.type == type)&&(identical(other.makeModel, makeModel) || other.makeModel == makeModel)&&(identical(other.capacity, capacity) || other.capacity == capacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,registrationNumber,type,makeModel,capacity);

@override
String toString() {
  return 'TripVehicleResponse(registrationNumber: $registrationNumber, type: $type, makeModel: $makeModel, capacity: $capacity)';
}


}

/// @nodoc
abstract mixin class _$TripVehicleResponseCopyWith<$Res> implements $TripVehicleResponseCopyWith<$Res> {
  factory _$TripVehicleResponseCopyWith(_TripVehicleResponse value, $Res Function(_TripVehicleResponse) _then) = __$TripVehicleResponseCopyWithImpl;
@override @useResult
$Res call({
 String registrationNumber,@JsonKey(unknownEnumValue: VehicleType.other) VehicleType type, String? makeModel, int? capacity
});




}
/// @nodoc
class __$TripVehicleResponseCopyWithImpl<$Res>
    implements _$TripVehicleResponseCopyWith<$Res> {
  __$TripVehicleResponseCopyWithImpl(this._self, this._then);

  final _TripVehicleResponse _self;
  final $Res Function(_TripVehicleResponse) _then;

/// Create a copy of TripVehicleResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? registrationNumber = null,Object? type = null,Object? makeModel = freezed,Object? capacity = freezed,}) {
  return _then(_TripVehicleResponse(
registrationNumber: null == registrationNumber ? _self.registrationNumber : registrationNumber // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VehicleType,makeModel: freezed == makeModel ? _self.makeModel : makeModel // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$TripDriverResponse {

 String get id; String? get fullName; String? get avatarUrl;/// 1-5, null until rated.
@JsonKey(fromJson: decimalOrNull) double? get averageRating; int get ratingCount;
/// Create a copy of TripDriverResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripDriverResponseCopyWith<TripDriverResponse> get copyWith => _$TripDriverResponseCopyWithImpl<TripDriverResponse>(this as TripDriverResponse, _$identity);

  /// Serializes this TripDriverResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripDriverResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.averageRating, averageRating) || other.averageRating == averageRating)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fullName,avatarUrl,averageRating,ratingCount);

@override
String toString() {
  return 'TripDriverResponse(id: $id, fullName: $fullName, avatarUrl: $avatarUrl, averageRating: $averageRating, ratingCount: $ratingCount)';
}


}

/// @nodoc
abstract mixin class $TripDriverResponseCopyWith<$Res>  {
  factory $TripDriverResponseCopyWith(TripDriverResponse value, $Res Function(TripDriverResponse) _then) = _$TripDriverResponseCopyWithImpl;
@useResult
$Res call({
 String id, String? fullName, String? avatarUrl,@JsonKey(fromJson: decimalOrNull) double? averageRating, int ratingCount
});




}
/// @nodoc
class _$TripDriverResponseCopyWithImpl<$Res>
    implements $TripDriverResponseCopyWith<$Res> {
  _$TripDriverResponseCopyWithImpl(this._self, this._then);

  final TripDriverResponse _self;
  final $Res Function(TripDriverResponse) _then;

/// Create a copy of TripDriverResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fullName = freezed,Object? avatarUrl = freezed,Object? averageRating = freezed,Object? ratingCount = null,}) {
  return _then(TripDriverResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,averageRating: freezed == averageRating ? _self.averageRating : averageRating // ignore: cast_nullable_to_non_nullable
as double?,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TripDriverResponse].
extension TripDriverResponsePatterns on TripDriverResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripDriverResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripDriverResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripDriverResponse value)  $default,){
final _that = this;
switch (_that) {
case _TripDriverResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripDriverResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TripDriverResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? fullName,  String? avatarUrl, @JsonKey(fromJson: decimalOrNull)  double? averageRating,  int ratingCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripDriverResponse() when $default != null:
return $default(_that.id,_that.fullName,_that.avatarUrl,_that.averageRating,_that.ratingCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? fullName,  String? avatarUrl, @JsonKey(fromJson: decimalOrNull)  double? averageRating,  int ratingCount)  $default,) {final _that = this;
switch (_that) {
case _TripDriverResponse():
return $default(_that.id,_that.fullName,_that.avatarUrl,_that.averageRating,_that.ratingCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? fullName,  String? avatarUrl, @JsonKey(fromJson: decimalOrNull)  double? averageRating,  int ratingCount)?  $default,) {final _that = this;
switch (_that) {
case _TripDriverResponse() when $default != null:
return $default(_that.id,_that.fullName,_that.avatarUrl,_that.averageRating,_that.ratingCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripDriverResponse implements TripDriverResponse {
  const _TripDriverResponse({required this.id, this.fullName, this.avatarUrl, @JsonKey(fromJson: decimalOrNull) this.averageRating, required this.ratingCount});
  factory _TripDriverResponse.fromJson(Map<String, dynamic> json) => _$TripDriverResponseFromJson(json);

@override final  String id;
@override final  String? fullName;
@override final  String? avatarUrl;
/// 1-5, null until rated.
@override@JsonKey(fromJson: decimalOrNull) final  double? averageRating;
@override final  int ratingCount;

/// Create a copy of TripDriverResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripDriverResponseCopyWith<_TripDriverResponse> get copyWith => __$TripDriverResponseCopyWithImpl<_TripDriverResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripDriverResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripDriverResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.averageRating, averageRating) || other.averageRating == averageRating)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fullName,avatarUrl,averageRating,ratingCount);

@override
String toString() {
  return 'TripDriverResponse(id: $id, fullName: $fullName, avatarUrl: $avatarUrl, averageRating: $averageRating, ratingCount: $ratingCount)';
}


}

/// @nodoc
abstract mixin class _$TripDriverResponseCopyWith<$Res> implements $TripDriverResponseCopyWith<$Res> {
  factory _$TripDriverResponseCopyWith(_TripDriverResponse value, $Res Function(_TripDriverResponse) _then) = __$TripDriverResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String? fullName, String? avatarUrl,@JsonKey(fromJson: decimalOrNull) double? averageRating, int ratingCount
});




}
/// @nodoc
class __$TripDriverResponseCopyWithImpl<$Res>
    implements _$TripDriverResponseCopyWith<$Res> {
  __$TripDriverResponseCopyWithImpl(this._self, this._then);

  final _TripDriverResponse _self;
  final $Res Function(_TripDriverResponse) _then;

/// Create a copy of TripDriverResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fullName = freezed,Object? avatarUrl = freezed,Object? averageRating = freezed,Object? ratingCount = null,}) {
  return _then(_TripDriverResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,averageRating: freezed == averageRating ? _self.averageRating : averageRating // ignore: cast_nullable_to_non_nullable
as double?,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TripDetailResponse {

 String get id; String get routeId; DateTime get scheduledDepartureAt;/// At the end of the route.
 DateTime? get scheduledArrivalAt; DateTime? get actualDepartureAt; DateTime? get actualArrivalAt;@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus get status;@JsonKey(fromJson: decimalString) String get fareAmount; String get routeName; String get originStopId; String get originStopName; String get destinationStopId; String get destinationStopName; TripVehicleResponse? get vehicle; TripDriverResponse? get driver; int get ridersCount; int get seatsTotal; int get availableSeats;
/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripDetailResponseCopyWith<TripDetailResponse> get copyWith => _$TripDetailResponseCopyWithImpl<TripDetailResponse>(this as TripDetailResponse, _$identity);

  /// Serializes this TripDetailResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripDetailResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.scheduledArrivalAt, scheduledArrivalAt) || other.scheduledArrivalAt == scheduledArrivalAt)&&(identical(other.actualDepartureAt, actualDepartureAt) || other.actualDepartureAt == actualDepartureAt)&&(identical(other.actualArrivalAt, actualArrivalAt) || other.actualArrivalAt == actualArrivalAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.originStopName, originStopName) || other.originStopName == originStopName)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.destinationStopName, destinationStopName) || other.destinationStopName == destinationStopName)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount)&&(identical(other.seatsTotal, seatsTotal) || other.seatsTotal == seatsTotal)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,routeId,scheduledDepartureAt,scheduledArrivalAt,actualDepartureAt,actualArrivalAt,status,fareAmount,routeName,originStopId,originStopName,destinationStopId,destinationStopName,vehicle,driver,ridersCount,seatsTotal,availableSeats);

@override
String toString() {
  return 'TripDetailResponse(id: $id, routeId: $routeId, scheduledDepartureAt: $scheduledDepartureAt, scheduledArrivalAt: $scheduledArrivalAt, actualDepartureAt: $actualDepartureAt, actualArrivalAt: $actualArrivalAt, status: $status, fareAmount: $fareAmount, routeName: $routeName, originStopId: $originStopId, originStopName: $originStopName, destinationStopId: $destinationStopId, destinationStopName: $destinationStopName, vehicle: $vehicle, driver: $driver, ridersCount: $ridersCount, seatsTotal: $seatsTotal, availableSeats: $availableSeats)';
}


}

/// @nodoc
abstract mixin class $TripDetailResponseCopyWith<$Res>  {
  factory $TripDetailResponseCopyWith(TripDetailResponse value, $Res Function(TripDetailResponse) _then) = _$TripDetailResponseCopyWithImpl;
@useResult
$Res call({
 String id, String routeId, DateTime scheduledDepartureAt, DateTime? scheduledArrivalAt, DateTime? actualDepartureAt, DateTime? actualArrivalAt,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status,@JsonKey(fromJson: decimalString) String fareAmount, String routeName, String originStopId, String originStopName, String destinationStopId, String destinationStopName, TripVehicleResponse? vehicle, TripDriverResponse? driver, int ridersCount, int seatsTotal, int availableSeats
});


$TripVehicleResponseCopyWith<$Res>? get vehicle;$TripDriverResponseCopyWith<$Res>? get driver;

}
/// @nodoc
class _$TripDetailResponseCopyWithImpl<$Res>
    implements $TripDetailResponseCopyWith<$Res> {
  _$TripDetailResponseCopyWithImpl(this._self, this._then);

  final TripDetailResponse _self;
  final $Res Function(TripDetailResponse) _then;

/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? routeId = null,Object? scheduledDepartureAt = null,Object? scheduledArrivalAt = freezed,Object? actualDepartureAt = freezed,Object? actualArrivalAt = freezed,Object? status = null,Object? fareAmount = null,Object? routeName = null,Object? originStopId = null,Object? originStopName = null,Object? destinationStopId = null,Object? destinationStopName = null,Object? vehicle = freezed,Object? driver = freezed,Object? ridersCount = null,Object? seatsTotal = null,Object? availableSeats = null,}) {
  return _then(TripDetailResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,scheduledDepartureAt: null == scheduledDepartureAt ? _self.scheduledDepartureAt : scheduledDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledArrivalAt: freezed == scheduledArrivalAt ? _self.scheduledArrivalAt : scheduledArrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,actualDepartureAt: freezed == actualDepartureAt ? _self.actualDepartureAt : actualDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime?,actualArrivalAt: freezed == actualArrivalAt ? _self.actualArrivalAt : actualArrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TripStatus,fareAmount: null == fareAmount ? _self.fareAmount : fareAmount // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,originStopName: null == originStopName ? _self.originStopName : originStopName // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopName: null == destinationStopName ? _self.destinationStopName : destinationStopName // ignore: cast_nullable_to_non_nullable
as String,vehicle: freezed == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as TripVehicleResponse?,driver: freezed == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as TripDriverResponse?,ridersCount: null == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int,seatsTotal: null == seatsTotal ? _self.seatsTotal : seatsTotal // ignore: cast_nullable_to_non_nullable
as int,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TripVehicleResponseCopyWith<$Res>? get vehicle {
    if (_self.vehicle == null) {
    return null;
  }

  return $TripVehicleResponseCopyWith<$Res>(_self.vehicle!, (value) {
    return _then(_self.copyWith(vehicle: value));
  });
}/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TripDriverResponseCopyWith<$Res>? get driver {
    if (_self.driver == null) {
    return null;
  }

  return $TripDriverResponseCopyWith<$Res>(_self.driver!, (value) {
    return _then(_self.copyWith(driver: value));
  });
}
}


/// Adds pattern-matching-related methods to [TripDetailResponse].
extension TripDetailResponsePatterns on TripDetailResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripDetailResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripDetailResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripDetailResponse value)  $default,){
final _that = this;
switch (_that) {
case _TripDetailResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripDetailResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TripDetailResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String routeId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  DateTime? actualDepartureAt,  DateTime? actualArrivalAt, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status, @JsonKey(fromJson: decimalString)  String fareAmount,  String routeName,  String originStopId,  String originStopName,  String destinationStopId,  String destinationStopName,  TripVehicleResponse? vehicle,  TripDriverResponse? driver,  int ridersCount,  int seatsTotal,  int availableSeats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripDetailResponse() when $default != null:
return $default(_that.id,_that.routeId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.actualDepartureAt,_that.actualArrivalAt,_that.status,_that.fareAmount,_that.routeName,_that.originStopId,_that.originStopName,_that.destinationStopId,_that.destinationStopName,_that.vehicle,_that.driver,_that.ridersCount,_that.seatsTotal,_that.availableSeats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String routeId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  DateTime? actualDepartureAt,  DateTime? actualArrivalAt, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status, @JsonKey(fromJson: decimalString)  String fareAmount,  String routeName,  String originStopId,  String originStopName,  String destinationStopId,  String destinationStopName,  TripVehicleResponse? vehicle,  TripDriverResponse? driver,  int ridersCount,  int seatsTotal,  int availableSeats)  $default,) {final _that = this;
switch (_that) {
case _TripDetailResponse():
return $default(_that.id,_that.routeId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.actualDepartureAt,_that.actualArrivalAt,_that.status,_that.fareAmount,_that.routeName,_that.originStopId,_that.originStopName,_that.destinationStopId,_that.destinationStopName,_that.vehicle,_that.driver,_that.ridersCount,_that.seatsTotal,_that.availableSeats);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String routeId,  DateTime scheduledDepartureAt,  DateTime? scheduledArrivalAt,  DateTime? actualDepartureAt,  DateTime? actualArrivalAt, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status, @JsonKey(fromJson: decimalString)  String fareAmount,  String routeName,  String originStopId,  String originStopName,  String destinationStopId,  String destinationStopName,  TripVehicleResponse? vehicle,  TripDriverResponse? driver,  int ridersCount,  int seatsTotal,  int availableSeats)?  $default,) {final _that = this;
switch (_that) {
case _TripDetailResponse() when $default != null:
return $default(_that.id,_that.routeId,_that.scheduledDepartureAt,_that.scheduledArrivalAt,_that.actualDepartureAt,_that.actualArrivalAt,_that.status,_that.fareAmount,_that.routeName,_that.originStopId,_that.originStopName,_that.destinationStopId,_that.destinationStopName,_that.vehicle,_that.driver,_that.ridersCount,_that.seatsTotal,_that.availableSeats);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripDetailResponse implements TripDetailResponse {
  const _TripDetailResponse({required this.id, required this.routeId, required this.scheduledDepartureAt, this.scheduledArrivalAt, this.actualDepartureAt, this.actualArrivalAt, @JsonKey(unknownEnumValue: TripStatus.scheduled) required this.status, @JsonKey(fromJson: decimalString) required this.fareAmount, required this.routeName, required this.originStopId, required this.originStopName, required this.destinationStopId, required this.destinationStopName, this.vehicle, this.driver, required this.ridersCount, required this.seatsTotal, required this.availableSeats});
  factory _TripDetailResponse.fromJson(Map<String, dynamic> json) => _$TripDetailResponseFromJson(json);

@override final  String id;
@override final  String routeId;
@override final  DateTime scheduledDepartureAt;
/// At the end of the route.
@override final  DateTime? scheduledArrivalAt;
@override final  DateTime? actualDepartureAt;
@override final  DateTime? actualArrivalAt;
@override@JsonKey(unknownEnumValue: TripStatus.scheduled) final  TripStatus status;
@override@JsonKey(fromJson: decimalString) final  String fareAmount;
@override final  String routeName;
@override final  String originStopId;
@override final  String originStopName;
@override final  String destinationStopId;
@override final  String destinationStopName;
@override final  TripVehicleResponse? vehicle;
@override final  TripDriverResponse? driver;
@override final  int ridersCount;
@override final  int seatsTotal;
@override final  int availableSeats;

/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripDetailResponseCopyWith<_TripDetailResponse> get copyWith => __$TripDetailResponseCopyWithImpl<_TripDetailResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripDetailResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripDetailResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.routeId, routeId) || other.routeId == routeId)&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.scheduledArrivalAt, scheduledArrivalAt) || other.scheduledArrivalAt == scheduledArrivalAt)&&(identical(other.actualDepartureAt, actualDepartureAt) || other.actualDepartureAt == actualDepartureAt)&&(identical(other.actualArrivalAt, actualArrivalAt) || other.actualArrivalAt == actualArrivalAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.originStopName, originStopName) || other.originStopName == originStopName)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.destinationStopName, destinationStopName) || other.destinationStopName == destinationStopName)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.ridersCount, ridersCount) || other.ridersCount == ridersCount)&&(identical(other.seatsTotal, seatsTotal) || other.seatsTotal == seatsTotal)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,routeId,scheduledDepartureAt,scheduledArrivalAt,actualDepartureAt,actualArrivalAt,status,fareAmount,routeName,originStopId,originStopName,destinationStopId,destinationStopName,vehicle,driver,ridersCount,seatsTotal,availableSeats);

@override
String toString() {
  return 'TripDetailResponse(id: $id, routeId: $routeId, scheduledDepartureAt: $scheduledDepartureAt, scheduledArrivalAt: $scheduledArrivalAt, actualDepartureAt: $actualDepartureAt, actualArrivalAt: $actualArrivalAt, status: $status, fareAmount: $fareAmount, routeName: $routeName, originStopId: $originStopId, originStopName: $originStopName, destinationStopId: $destinationStopId, destinationStopName: $destinationStopName, vehicle: $vehicle, driver: $driver, ridersCount: $ridersCount, seatsTotal: $seatsTotal, availableSeats: $availableSeats)';
}


}

/// @nodoc
abstract mixin class _$TripDetailResponseCopyWith<$Res> implements $TripDetailResponseCopyWith<$Res> {
  factory _$TripDetailResponseCopyWith(_TripDetailResponse value, $Res Function(_TripDetailResponse) _then) = __$TripDetailResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String routeId, DateTime scheduledDepartureAt, DateTime? scheduledArrivalAt, DateTime? actualDepartureAt, DateTime? actualArrivalAt,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status,@JsonKey(fromJson: decimalString) String fareAmount, String routeName, String originStopId, String originStopName, String destinationStopId, String destinationStopName, TripVehicleResponse? vehicle, TripDriverResponse? driver, int ridersCount, int seatsTotal, int availableSeats
});


@override $TripVehicleResponseCopyWith<$Res>? get vehicle;@override $TripDriverResponseCopyWith<$Res>? get driver;

}
/// @nodoc
class __$TripDetailResponseCopyWithImpl<$Res>
    implements _$TripDetailResponseCopyWith<$Res> {
  __$TripDetailResponseCopyWithImpl(this._self, this._then);

  final _TripDetailResponse _self;
  final $Res Function(_TripDetailResponse) _then;

/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? routeId = null,Object? scheduledDepartureAt = null,Object? scheduledArrivalAt = freezed,Object? actualDepartureAt = freezed,Object? actualArrivalAt = freezed,Object? status = null,Object? fareAmount = null,Object? routeName = null,Object? originStopId = null,Object? originStopName = null,Object? destinationStopId = null,Object? destinationStopName = null,Object? vehicle = freezed,Object? driver = freezed,Object? ridersCount = null,Object? seatsTotal = null,Object? availableSeats = null,}) {
  return _then(_TripDetailResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,scheduledDepartureAt: null == scheduledDepartureAt ? _self.scheduledDepartureAt : scheduledDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledArrivalAt: freezed == scheduledArrivalAt ? _self.scheduledArrivalAt : scheduledArrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,actualDepartureAt: freezed == actualDepartureAt ? _self.actualDepartureAt : actualDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime?,actualArrivalAt: freezed == actualArrivalAt ? _self.actualArrivalAt : actualArrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TripStatus,fareAmount: null == fareAmount ? _self.fareAmount : fareAmount // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,originStopName: null == originStopName ? _self.originStopName : originStopName // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopName: null == destinationStopName ? _self.destinationStopName : destinationStopName // ignore: cast_nullable_to_non_nullable
as String,vehicle: freezed == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as TripVehicleResponse?,driver: freezed == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as TripDriverResponse?,ridersCount: null == ridersCount ? _self.ridersCount : ridersCount // ignore: cast_nullable_to_non_nullable
as int,seatsTotal: null == seatsTotal ? _self.seatsTotal : seatsTotal // ignore: cast_nullable_to_non_nullable
as int,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TripVehicleResponseCopyWith<$Res>? get vehicle {
    if (_self.vehicle == null) {
    return null;
  }

  return $TripVehicleResponseCopyWith<$Res>(_self.vehicle!, (value) {
    return _then(_self.copyWith(vehicle: value));
  });
}/// Create a copy of TripDetailResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TripDriverResponseCopyWith<$Res>? get driver {
    if (_self.driver == null) {
    return null;
  }

  return $TripDriverResponseCopyWith<$Res>(_self.driver!, (value) {
    return _then(_self.copyWith(driver: value));
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
