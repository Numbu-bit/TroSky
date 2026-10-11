// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TripSeatResponse {

 String get id; String get seatNumber; int get rowNumber; int get columnNumber;@JsonKey(unknownEnumValue: SeatType.standard) SeatType get seatType; bool get isAvailable;
/// Create a copy of TripSeatResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripSeatResponseCopyWith<TripSeatResponse> get copyWith => _$TripSeatResponseCopyWithImpl<TripSeatResponse>(this as TripSeatResponse, _$identity);

  /// Serializes this TripSeatResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripSeatResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.seatNumber, seatNumber) || other.seatNumber == seatNumber)&&(identical(other.rowNumber, rowNumber) || other.rowNumber == rowNumber)&&(identical(other.columnNumber, columnNumber) || other.columnNumber == columnNumber)&&(identical(other.seatType, seatType) || other.seatType == seatType)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,seatNumber,rowNumber,columnNumber,seatType,isAvailable);

@override
String toString() {
  return 'TripSeatResponse(id: $id, seatNumber: $seatNumber, rowNumber: $rowNumber, columnNumber: $columnNumber, seatType: $seatType, isAvailable: $isAvailable)';
}


}

/// @nodoc
abstract mixin class $TripSeatResponseCopyWith<$Res>  {
  factory $TripSeatResponseCopyWith(TripSeatResponse value, $Res Function(TripSeatResponse) _then) = _$TripSeatResponseCopyWithImpl;
@useResult
$Res call({
 String id, String seatNumber, int rowNumber, int columnNumber,@JsonKey(unknownEnumValue: SeatType.standard) SeatType seatType, bool isAvailable
});




}
/// @nodoc
class _$TripSeatResponseCopyWithImpl<$Res>
    implements $TripSeatResponseCopyWith<$Res> {
  _$TripSeatResponseCopyWithImpl(this._self, this._then);

  final TripSeatResponse _self;
  final $Res Function(TripSeatResponse) _then;

/// Create a copy of TripSeatResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? seatNumber = null,Object? rowNumber = null,Object? columnNumber = null,Object? seatType = null,Object? isAvailable = null,}) {
  return _then(TripSeatResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seatNumber: null == seatNumber ? _self.seatNumber : seatNumber // ignore: cast_nullable_to_non_nullable
as String,rowNumber: null == rowNumber ? _self.rowNumber : rowNumber // ignore: cast_nullable_to_non_nullable
as int,columnNumber: null == columnNumber ? _self.columnNumber : columnNumber // ignore: cast_nullable_to_non_nullable
as int,seatType: null == seatType ? _self.seatType : seatType // ignore: cast_nullable_to_non_nullable
as SeatType,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TripSeatResponse].
extension TripSeatResponsePatterns on TripSeatResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripSeatResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripSeatResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripSeatResponse value)  $default,){
final _that = this;
switch (_that) {
case _TripSeatResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripSeatResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TripSeatResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String seatNumber,  int rowNumber,  int columnNumber, @JsonKey(unknownEnumValue: SeatType.standard)  SeatType seatType,  bool isAvailable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripSeatResponse() when $default != null:
return $default(_that.id,_that.seatNumber,_that.rowNumber,_that.columnNumber,_that.seatType,_that.isAvailable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String seatNumber,  int rowNumber,  int columnNumber, @JsonKey(unknownEnumValue: SeatType.standard)  SeatType seatType,  bool isAvailable)  $default,) {final _that = this;
switch (_that) {
case _TripSeatResponse():
return $default(_that.id,_that.seatNumber,_that.rowNumber,_that.columnNumber,_that.seatType,_that.isAvailable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String seatNumber,  int rowNumber,  int columnNumber, @JsonKey(unknownEnumValue: SeatType.standard)  SeatType seatType,  bool isAvailable)?  $default,) {final _that = this;
switch (_that) {
case _TripSeatResponse() when $default != null:
return $default(_that.id,_that.seatNumber,_that.rowNumber,_that.columnNumber,_that.seatType,_that.isAvailable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripSeatResponse implements TripSeatResponse {
  const _TripSeatResponse({required this.id, required this.seatNumber, required this.rowNumber, required this.columnNumber, @JsonKey(unknownEnumValue: SeatType.standard) required this.seatType, required this.isAvailable});
  factory _TripSeatResponse.fromJson(Map<String, dynamic> json) => _$TripSeatResponseFromJson(json);

@override final  String id;
@override final  String seatNumber;
@override final  int rowNumber;
@override final  int columnNumber;
@override@JsonKey(unknownEnumValue: SeatType.standard) final  SeatType seatType;
@override final  bool isAvailable;

/// Create a copy of TripSeatResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripSeatResponseCopyWith<_TripSeatResponse> get copyWith => __$TripSeatResponseCopyWithImpl<_TripSeatResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripSeatResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripSeatResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.seatNumber, seatNumber) || other.seatNumber == seatNumber)&&(identical(other.rowNumber, rowNumber) || other.rowNumber == rowNumber)&&(identical(other.columnNumber, columnNumber) || other.columnNumber == columnNumber)&&(identical(other.seatType, seatType) || other.seatType == seatType)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,seatNumber,rowNumber,columnNumber,seatType,isAvailable);

@override
String toString() {
  return 'TripSeatResponse(id: $id, seatNumber: $seatNumber, rowNumber: $rowNumber, columnNumber: $columnNumber, seatType: $seatType, isAvailable: $isAvailable)';
}


}

/// @nodoc
abstract mixin class _$TripSeatResponseCopyWith<$Res> implements $TripSeatResponseCopyWith<$Res> {
  factory _$TripSeatResponseCopyWith(_TripSeatResponse value, $Res Function(_TripSeatResponse) _then) = __$TripSeatResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String seatNumber, int rowNumber, int columnNumber,@JsonKey(unknownEnumValue: SeatType.standard) SeatType seatType, bool isAvailable
});




}
/// @nodoc
class __$TripSeatResponseCopyWithImpl<$Res>
    implements _$TripSeatResponseCopyWith<$Res> {
  __$TripSeatResponseCopyWithImpl(this._self, this._then);

  final _TripSeatResponse _self;
  final $Res Function(_TripSeatResponse) _then;

/// Create a copy of TripSeatResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? seatNumber = null,Object? rowNumber = null,Object? columnNumber = null,Object? seatType = null,Object? isAvailable = null,}) {
  return _then(_TripSeatResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seatNumber: null == seatNumber ? _self.seatNumber : seatNumber // ignore: cast_nullable_to_non_nullable
as String,rowNumber: null == rowNumber ? _self.rowNumber : rowNumber // ignore: cast_nullable_to_non_nullable
as int,columnNumber: null == columnNumber ? _self.columnNumber : columnNumber // ignore: cast_nullable_to_non_nullable
as int,seatType: null == seatType ? _self.seatType : seatType // ignore: cast_nullable_to_non_nullable
as SeatType,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TripSeatsResponse {

 String get tripId; String get vehicleId; int get totalSeats; int get availableSeats; List<TripSeatResponse> get seats;
/// Create a copy of TripSeatsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripSeatsResponseCopyWith<TripSeatsResponse> get copyWith => _$TripSeatsResponseCopyWithImpl<TripSeatsResponse>(this as TripSeatsResponse, _$identity);

  /// Serializes this TripSeatsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripSeatsResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.totalSeats, totalSeats) || other.totalSeats == totalSeats)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&const DeepCollectionEquality().equals(other.seats, seats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,vehicleId,totalSeats,availableSeats,const DeepCollectionEquality().hash(seats));

@override
String toString() {
  return 'TripSeatsResponse(tripId: $tripId, vehicleId: $vehicleId, totalSeats: $totalSeats, availableSeats: $availableSeats, seats: $seats)';
}


}

/// @nodoc
abstract mixin class $TripSeatsResponseCopyWith<$Res>  {
  factory $TripSeatsResponseCopyWith(TripSeatsResponse value, $Res Function(TripSeatsResponse) _then) = _$TripSeatsResponseCopyWithImpl;
@useResult
$Res call({
 String tripId, String vehicleId, int totalSeats, int availableSeats, List<TripSeatResponse> seats
});




}
/// @nodoc
class _$TripSeatsResponseCopyWithImpl<$Res>
    implements $TripSeatsResponseCopyWith<$Res> {
  _$TripSeatsResponseCopyWithImpl(this._self, this._then);

  final TripSeatsResponse _self;
  final $Res Function(TripSeatsResponse) _then;

/// Create a copy of TripSeatsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tripId = null,Object? vehicleId = null,Object? totalSeats = null,Object? availableSeats = null,Object? seats = null,}) {
  return _then(TripSeatsResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String,totalSeats: null == totalSeats ? _self.totalSeats : totalSeats // ignore: cast_nullable_to_non_nullable
as int,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as List<TripSeatResponse>,
  ));
}

}


/// Adds pattern-matching-related methods to [TripSeatsResponse].
extension TripSeatsResponsePatterns on TripSeatsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripSeatsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripSeatsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripSeatsResponse value)  $default,){
final _that = this;
switch (_that) {
case _TripSeatsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripSeatsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TripSeatsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tripId,  String vehicleId,  int totalSeats,  int availableSeats,  List<TripSeatResponse> seats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripSeatsResponse() when $default != null:
return $default(_that.tripId,_that.vehicleId,_that.totalSeats,_that.availableSeats,_that.seats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tripId,  String vehicleId,  int totalSeats,  int availableSeats,  List<TripSeatResponse> seats)  $default,) {final _that = this;
switch (_that) {
case _TripSeatsResponse():
return $default(_that.tripId,_that.vehicleId,_that.totalSeats,_that.availableSeats,_that.seats);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tripId,  String vehicleId,  int totalSeats,  int availableSeats,  List<TripSeatResponse> seats)?  $default,) {final _that = this;
switch (_that) {
case _TripSeatsResponse() when $default != null:
return $default(_that.tripId,_that.vehicleId,_that.totalSeats,_that.availableSeats,_that.seats);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripSeatsResponse implements TripSeatsResponse {
  const _TripSeatsResponse({required this.tripId, required this.vehicleId, required this.totalSeats, required this.availableSeats, required  List<TripSeatResponse> seats}): _seats = seats;
  factory _TripSeatsResponse.fromJson(Map<String, dynamic> json) => _$TripSeatsResponseFromJson(json);

@override final  String tripId;
@override final  String vehicleId;
@override final  int totalSeats;
@override final  int availableSeats;
 final  List<TripSeatResponse> _seats;
@override List<TripSeatResponse> get seats {
  if (_seats is EqualUnmodifiableListView) return _seats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seats);
}


/// Create a copy of TripSeatsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripSeatsResponseCopyWith<_TripSeatsResponse> get copyWith => __$TripSeatsResponseCopyWithImpl<_TripSeatsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripSeatsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripSeatsResponse&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.totalSeats, totalSeats) || other.totalSeats == totalSeats)&&(identical(other.availableSeats, availableSeats) || other.availableSeats == availableSeats)&&const DeepCollectionEquality().equals(other._seats, _seats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,vehicleId,totalSeats,availableSeats,const DeepCollectionEquality().hash(_seats));

@override
String toString() {
  return 'TripSeatsResponse(tripId: $tripId, vehicleId: $vehicleId, totalSeats: $totalSeats, availableSeats: $availableSeats, seats: $seats)';
}


}

/// @nodoc
abstract mixin class _$TripSeatsResponseCopyWith<$Res> implements $TripSeatsResponseCopyWith<$Res> {
  factory _$TripSeatsResponseCopyWith(_TripSeatsResponse value, $Res Function(_TripSeatsResponse) _then) = __$TripSeatsResponseCopyWithImpl;
@override @useResult
$Res call({
 String tripId, String vehicleId, int totalSeats, int availableSeats, List<TripSeatResponse> seats
});




}
/// @nodoc
class __$TripSeatsResponseCopyWithImpl<$Res>
    implements _$TripSeatsResponseCopyWith<$Res> {
  __$TripSeatsResponseCopyWithImpl(this._self, this._then);

  final _TripSeatsResponse _self;
  final $Res Function(_TripSeatsResponse) _then;

/// Create a copy of TripSeatsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tripId = null,Object? vehicleId = null,Object? totalSeats = null,Object? availableSeats = null,Object? seats = null,}) {
  return _then(_TripSeatsResponse(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String,totalSeats: null == totalSeats ? _self.totalSeats : totalSeats // ignore: cast_nullable_to_non_nullable
as int,availableSeats: null == availableSeats ? _self.availableSeats : availableSeats // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self._seats : seats // ignore: cast_nullable_to_non_nullable
as List<TripSeatResponse>,
  ));
}


}


/// @nodoc
mixin _$PassengerInput {

 String get seatId; String get fullName; String? get phoneNumber;
/// Create a copy of PassengerInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PassengerInputCopyWith<PassengerInput> get copyWith => _$PassengerInputCopyWithImpl<PassengerInput>(this as PassengerInput, _$identity);

  /// Serializes this PassengerInput to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PassengerInput&&(identical(other.seatId, seatId) || other.seatId == seatId)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seatId,fullName,phoneNumber);

@override
String toString() {
  return 'PassengerInput(seatId: $seatId, fullName: $fullName, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class $PassengerInputCopyWith<$Res>  {
  factory $PassengerInputCopyWith(PassengerInput value, $Res Function(PassengerInput) _then) = _$PassengerInputCopyWithImpl;
@useResult
$Res call({
 String seatId, String fullName, String? phoneNumber
});




}
/// @nodoc
class _$PassengerInputCopyWithImpl<$Res>
    implements $PassengerInputCopyWith<$Res> {
  _$PassengerInputCopyWithImpl(this._self, this._then);

  final PassengerInput _self;
  final $Res Function(PassengerInput) _then;

/// Create a copy of PassengerInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seatId = null,Object? fullName = null,Object? phoneNumber = freezed,}) {
  return _then(PassengerInput(
seatId: null == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PassengerInput].
extension PassengerInputPatterns on PassengerInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PassengerInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PassengerInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PassengerInput value)  $default,){
final _that = this;
switch (_that) {
case _PassengerInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PassengerInput value)?  $default,){
final _that = this;
switch (_that) {
case _PassengerInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String seatId,  String fullName,  String? phoneNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PassengerInput() when $default != null:
return $default(_that.seatId,_that.fullName,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String seatId,  String fullName,  String? phoneNumber)  $default,) {final _that = this;
switch (_that) {
case _PassengerInput():
return $default(_that.seatId,_that.fullName,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String seatId,  String fullName,  String? phoneNumber)?  $default,) {final _that = this;
switch (_that) {
case _PassengerInput() when $default != null:
return $default(_that.seatId,_that.fullName,_that.phoneNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PassengerInput implements PassengerInput {
  const _PassengerInput({required this.seatId, required this.fullName, this.phoneNumber});
  factory _PassengerInput.fromJson(Map<String, dynamic> json) => _$PassengerInputFromJson(json);

@override final  String seatId;
@override final  String fullName;
@override final  String? phoneNumber;

/// Create a copy of PassengerInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PassengerInputCopyWith<_PassengerInput> get copyWith => __$PassengerInputCopyWithImpl<_PassengerInput>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PassengerInputToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PassengerInput&&(identical(other.seatId, seatId) || other.seatId == seatId)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seatId,fullName,phoneNumber);

@override
String toString() {
  return 'PassengerInput(seatId: $seatId, fullName: $fullName, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class _$PassengerInputCopyWith<$Res> implements $PassengerInputCopyWith<$Res> {
  factory _$PassengerInputCopyWith(_PassengerInput value, $Res Function(_PassengerInput) _then) = __$PassengerInputCopyWithImpl;
@override @useResult
$Res call({
 String seatId, String fullName, String? phoneNumber
});




}
/// @nodoc
class __$PassengerInputCopyWithImpl<$Res>
    implements _$PassengerInputCopyWith<$Res> {
  __$PassengerInputCopyWithImpl(this._self, this._then);

  final _PassengerInput _self;
  final $Res Function(_PassengerInput) _then;

/// Create a copy of PassengerInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seatId = null,Object? fullName = null,Object? phoneNumber = freezed,}) {
  return _then(_PassengerInput(
seatId: null == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$BookingCreateRequest {

 String get tripId; List<PassengerInput> get passengers; String? get originStopId; String? get destinationStopId; double? get pickupLatitude; double? get pickupLongitude;
/// Create a copy of BookingCreateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingCreateRequestCopyWith<BookingCreateRequest> get copyWith => _$BookingCreateRequestCopyWithImpl<BookingCreateRequest>(this as BookingCreateRequest, _$identity);

  /// Serializes this BookingCreateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingCreateRequest&&(identical(other.tripId, tripId) || other.tripId == tripId)&&const DeepCollectionEquality().equals(other.passengers, passengers)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.pickupLatitude, pickupLatitude) || other.pickupLatitude == pickupLatitude)&&(identical(other.pickupLongitude, pickupLongitude) || other.pickupLongitude == pickupLongitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,const DeepCollectionEquality().hash(passengers),originStopId,destinationStopId,pickupLatitude,pickupLongitude);

@override
String toString() {
  return 'BookingCreateRequest(tripId: $tripId, passengers: $passengers, originStopId: $originStopId, destinationStopId: $destinationStopId, pickupLatitude: $pickupLatitude, pickupLongitude: $pickupLongitude)';
}


}

/// @nodoc
abstract mixin class $BookingCreateRequestCopyWith<$Res>  {
  factory $BookingCreateRequestCopyWith(BookingCreateRequest value, $Res Function(BookingCreateRequest) _then) = _$BookingCreateRequestCopyWithImpl;
@useResult
$Res call({
 String tripId, List<PassengerInput> passengers, String? originStopId, String? destinationStopId, double? pickupLatitude, double? pickupLongitude
});




}
/// @nodoc
class _$BookingCreateRequestCopyWithImpl<$Res>
    implements $BookingCreateRequestCopyWith<$Res> {
  _$BookingCreateRequestCopyWithImpl(this._self, this._then);

  final BookingCreateRequest _self;
  final $Res Function(BookingCreateRequest) _then;

/// Create a copy of BookingCreateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tripId = null,Object? passengers = null,Object? originStopId = freezed,Object? destinationStopId = freezed,Object? pickupLatitude = freezed,Object? pickupLongitude = freezed,}) {
  return _then(BookingCreateRequest(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,passengers: null == passengers ? _self.passengers : passengers // ignore: cast_nullable_to_non_nullable
as List<PassengerInput>,originStopId: freezed == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String?,destinationStopId: freezed == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String?,pickupLatitude: freezed == pickupLatitude ? _self.pickupLatitude : pickupLatitude // ignore: cast_nullable_to_non_nullable
as double?,pickupLongitude: freezed == pickupLongitude ? _self.pickupLongitude : pickupLongitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingCreateRequest].
extension BookingCreateRequestPatterns on BookingCreateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingCreateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingCreateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingCreateRequest value)  $default,){
final _that = this;
switch (_that) {
case _BookingCreateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingCreateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _BookingCreateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tripId,  List<PassengerInput> passengers,  String? originStopId,  String? destinationStopId,  double? pickupLatitude,  double? pickupLongitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingCreateRequest() when $default != null:
return $default(_that.tripId,_that.passengers,_that.originStopId,_that.destinationStopId,_that.pickupLatitude,_that.pickupLongitude);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tripId,  List<PassengerInput> passengers,  String? originStopId,  String? destinationStopId,  double? pickupLatitude,  double? pickupLongitude)  $default,) {final _that = this;
switch (_that) {
case _BookingCreateRequest():
return $default(_that.tripId,_that.passengers,_that.originStopId,_that.destinationStopId,_that.pickupLatitude,_that.pickupLongitude);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tripId,  List<PassengerInput> passengers,  String? originStopId,  String? destinationStopId,  double? pickupLatitude,  double? pickupLongitude)?  $default,) {final _that = this;
switch (_that) {
case _BookingCreateRequest() when $default != null:
return $default(_that.tripId,_that.passengers,_that.originStopId,_that.destinationStopId,_that.pickupLatitude,_that.pickupLongitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingCreateRequest implements BookingCreateRequest {
  const _BookingCreateRequest({required this.tripId, required  List<PassengerInput> passengers, this.originStopId, this.destinationStopId, this.pickupLatitude, this.pickupLongitude}): _passengers = passengers;
  factory _BookingCreateRequest.fromJson(Map<String, dynamic> json) => _$BookingCreateRequestFromJson(json);

@override final  String tripId;
 final  List<PassengerInput> _passengers;
@override List<PassengerInput> get passengers {
  if (_passengers is EqualUnmodifiableListView) return _passengers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_passengers);
}

@override final  String? originStopId;
@override final  String? destinationStopId;
@override final  double? pickupLatitude;
@override final  double? pickupLongitude;

/// Create a copy of BookingCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingCreateRequestCopyWith<_BookingCreateRequest> get copyWith => __$BookingCreateRequestCopyWithImpl<_BookingCreateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingCreateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingCreateRequest&&(identical(other.tripId, tripId) || other.tripId == tripId)&&const DeepCollectionEquality().equals(other._passengers, _passengers)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.pickupLatitude, pickupLatitude) || other.pickupLatitude == pickupLatitude)&&(identical(other.pickupLongitude, pickupLongitude) || other.pickupLongitude == pickupLongitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tripId,const DeepCollectionEquality().hash(_passengers),originStopId,destinationStopId,pickupLatitude,pickupLongitude);

@override
String toString() {
  return 'BookingCreateRequest(tripId: $tripId, passengers: $passengers, originStopId: $originStopId, destinationStopId: $destinationStopId, pickupLatitude: $pickupLatitude, pickupLongitude: $pickupLongitude)';
}


}

/// @nodoc
abstract mixin class _$BookingCreateRequestCopyWith<$Res> implements $BookingCreateRequestCopyWith<$Res> {
  factory _$BookingCreateRequestCopyWith(_BookingCreateRequest value, $Res Function(_BookingCreateRequest) _then) = __$BookingCreateRequestCopyWithImpl;
@override @useResult
$Res call({
 String tripId, List<PassengerInput> passengers, String? originStopId, String? destinationStopId, double? pickupLatitude, double? pickupLongitude
});




}
/// @nodoc
class __$BookingCreateRequestCopyWithImpl<$Res>
    implements _$BookingCreateRequestCopyWith<$Res> {
  __$BookingCreateRequestCopyWithImpl(this._self, this._then);

  final _BookingCreateRequest _self;
  final $Res Function(_BookingCreateRequest) _then;

/// Create a copy of BookingCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tripId = null,Object? passengers = null,Object? originStopId = freezed,Object? destinationStopId = freezed,Object? pickupLatitude = freezed,Object? pickupLongitude = freezed,}) {
  return _then(_BookingCreateRequest(
tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,passengers: null == passengers ? _self._passengers : passengers // ignore: cast_nullable_to_non_nullable
as List<PassengerInput>,originStopId: freezed == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String?,destinationStopId: freezed == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String?,pickupLatitude: freezed == pickupLatitude ? _self.pickupLatitude : pickupLatitude // ignore: cast_nullable_to_non_nullable
as double?,pickupLongitude: freezed == pickupLongitude ? _self.pickupLongitude : pickupLongitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$BookingPassengerResponse {

 String get id; String get seatId; String get fullName; String? get phoneNumber;
/// Create a copy of BookingPassengerResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingPassengerResponseCopyWith<BookingPassengerResponse> get copyWith => _$BookingPassengerResponseCopyWithImpl<BookingPassengerResponse>(this as BookingPassengerResponse, _$identity);

  /// Serializes this BookingPassengerResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingPassengerResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.seatId, seatId) || other.seatId == seatId)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,seatId,fullName,phoneNumber);

@override
String toString() {
  return 'BookingPassengerResponse(id: $id, seatId: $seatId, fullName: $fullName, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class $BookingPassengerResponseCopyWith<$Res>  {
  factory $BookingPassengerResponseCopyWith(BookingPassengerResponse value, $Res Function(BookingPassengerResponse) _then) = _$BookingPassengerResponseCopyWithImpl;
@useResult
$Res call({
 String id, String seatId, String fullName, String? phoneNumber
});




}
/// @nodoc
class _$BookingPassengerResponseCopyWithImpl<$Res>
    implements $BookingPassengerResponseCopyWith<$Res> {
  _$BookingPassengerResponseCopyWithImpl(this._self, this._then);

  final BookingPassengerResponse _self;
  final $Res Function(BookingPassengerResponse) _then;

/// Create a copy of BookingPassengerResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? seatId = null,Object? fullName = null,Object? phoneNumber = freezed,}) {
  return _then(BookingPassengerResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seatId: null == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingPassengerResponse].
extension BookingPassengerResponsePatterns on BookingPassengerResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingPassengerResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingPassengerResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingPassengerResponse value)  $default,){
final _that = this;
switch (_that) {
case _BookingPassengerResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingPassengerResponse value)?  $default,){
final _that = this;
switch (_that) {
case _BookingPassengerResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String seatId,  String fullName,  String? phoneNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingPassengerResponse() when $default != null:
return $default(_that.id,_that.seatId,_that.fullName,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String seatId,  String fullName,  String? phoneNumber)  $default,) {final _that = this;
switch (_that) {
case _BookingPassengerResponse():
return $default(_that.id,_that.seatId,_that.fullName,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String seatId,  String fullName,  String? phoneNumber)?  $default,) {final _that = this;
switch (_that) {
case _BookingPassengerResponse() when $default != null:
return $default(_that.id,_that.seatId,_that.fullName,_that.phoneNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingPassengerResponse implements BookingPassengerResponse {
  const _BookingPassengerResponse({required this.id, required this.seatId, required this.fullName, this.phoneNumber});
  factory _BookingPassengerResponse.fromJson(Map<String, dynamic> json) => _$BookingPassengerResponseFromJson(json);

@override final  String id;
@override final  String seatId;
@override final  String fullName;
@override final  String? phoneNumber;

/// Create a copy of BookingPassengerResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingPassengerResponseCopyWith<_BookingPassengerResponse> get copyWith => __$BookingPassengerResponseCopyWithImpl<_BookingPassengerResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingPassengerResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingPassengerResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.seatId, seatId) || other.seatId == seatId)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,seatId,fullName,phoneNumber);

@override
String toString() {
  return 'BookingPassengerResponse(id: $id, seatId: $seatId, fullName: $fullName, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class _$BookingPassengerResponseCopyWith<$Res> implements $BookingPassengerResponseCopyWith<$Res> {
  factory _$BookingPassengerResponseCopyWith(_BookingPassengerResponse value, $Res Function(_BookingPassengerResponse) _then) = __$BookingPassengerResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String seatId, String fullName, String? phoneNumber
});




}
/// @nodoc
class __$BookingPassengerResponseCopyWithImpl<$Res>
    implements _$BookingPassengerResponseCopyWith<$Res> {
  __$BookingPassengerResponseCopyWithImpl(this._self, this._then);

  final _BookingPassengerResponse _self;
  final $Res Function(_BookingPassengerResponse) _then;

/// Create a copy of BookingPassengerResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? seatId = null,Object? fullName = null,Object? phoneNumber = freezed,}) {
  return _then(_BookingPassengerResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seatId: null == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$BookingTripSummaryResponse {

 DateTime get scheduledDepartureAt; String get routeName; String get originStopName; String get destinationStopName;@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus get status; String? get vehicleRegistrationNumber;
/// Create a copy of BookingTripSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingTripSummaryResponseCopyWith<BookingTripSummaryResponse> get copyWith => _$BookingTripSummaryResponseCopyWithImpl<BookingTripSummaryResponse>(this as BookingTripSummaryResponse, _$identity);

  /// Serializes this BookingTripSummaryResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingTripSummaryResponse&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopName, originStopName) || other.originStopName == originStopName)&&(identical(other.destinationStopName, destinationStopName) || other.destinationStopName == destinationStopName)&&(identical(other.status, status) || other.status == status)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scheduledDepartureAt,routeName,originStopName,destinationStopName,status,vehicleRegistrationNumber);

@override
String toString() {
  return 'BookingTripSummaryResponse(scheduledDepartureAt: $scheduledDepartureAt, routeName: $routeName, originStopName: $originStopName, destinationStopName: $destinationStopName, status: $status, vehicleRegistrationNumber: $vehicleRegistrationNumber)';
}


}

/// @nodoc
abstract mixin class $BookingTripSummaryResponseCopyWith<$Res>  {
  factory $BookingTripSummaryResponseCopyWith(BookingTripSummaryResponse value, $Res Function(BookingTripSummaryResponse) _then) = _$BookingTripSummaryResponseCopyWithImpl;
@useResult
$Res call({
 DateTime scheduledDepartureAt, String routeName, String originStopName, String destinationStopName,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status, String? vehicleRegistrationNumber
});




}
/// @nodoc
class _$BookingTripSummaryResponseCopyWithImpl<$Res>
    implements $BookingTripSummaryResponseCopyWith<$Res> {
  _$BookingTripSummaryResponseCopyWithImpl(this._self, this._then);

  final BookingTripSummaryResponse _self;
  final $Res Function(BookingTripSummaryResponse) _then;

/// Create a copy of BookingTripSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scheduledDepartureAt = null,Object? routeName = null,Object? originStopName = null,Object? destinationStopName = null,Object? status = null,Object? vehicleRegistrationNumber = freezed,}) {
  return _then(BookingTripSummaryResponse(
scheduledDepartureAt: null == scheduledDepartureAt ? _self.scheduledDepartureAt : scheduledDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,originStopName: null == originStopName ? _self.originStopName : originStopName // ignore: cast_nullable_to_non_nullable
as String,destinationStopName: null == destinationStopName ? _self.destinationStopName : destinationStopName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TripStatus,vehicleRegistrationNumber: freezed == vehicleRegistrationNumber ? _self.vehicleRegistrationNumber : vehicleRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingTripSummaryResponse].
extension BookingTripSummaryResponsePatterns on BookingTripSummaryResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingTripSummaryResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingTripSummaryResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingTripSummaryResponse value)  $default,){
final _that = this;
switch (_that) {
case _BookingTripSummaryResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingTripSummaryResponse value)?  $default,){
final _that = this;
switch (_that) {
case _BookingTripSummaryResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime scheduledDepartureAt,  String routeName,  String originStopName,  String destinationStopName, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  String? vehicleRegistrationNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingTripSummaryResponse() when $default != null:
return $default(_that.scheduledDepartureAt,_that.routeName,_that.originStopName,_that.destinationStopName,_that.status,_that.vehicleRegistrationNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime scheduledDepartureAt,  String routeName,  String originStopName,  String destinationStopName, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  String? vehicleRegistrationNumber)  $default,) {final _that = this;
switch (_that) {
case _BookingTripSummaryResponse():
return $default(_that.scheduledDepartureAt,_that.routeName,_that.originStopName,_that.destinationStopName,_that.status,_that.vehicleRegistrationNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime scheduledDepartureAt,  String routeName,  String originStopName,  String destinationStopName, @JsonKey(unknownEnumValue: TripStatus.scheduled)  TripStatus status,  String? vehicleRegistrationNumber)?  $default,) {final _that = this;
switch (_that) {
case _BookingTripSummaryResponse() when $default != null:
return $default(_that.scheduledDepartureAt,_that.routeName,_that.originStopName,_that.destinationStopName,_that.status,_that.vehicleRegistrationNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingTripSummaryResponse implements BookingTripSummaryResponse {
  const _BookingTripSummaryResponse({required this.scheduledDepartureAt, required this.routeName, required this.originStopName, required this.destinationStopName, @JsonKey(unknownEnumValue: TripStatus.scheduled) required this.status, this.vehicleRegistrationNumber});
  factory _BookingTripSummaryResponse.fromJson(Map<String, dynamic> json) => _$BookingTripSummaryResponseFromJson(json);

@override final  DateTime scheduledDepartureAt;
@override final  String routeName;
@override final  String originStopName;
@override final  String destinationStopName;
@override@JsonKey(unknownEnumValue: TripStatus.scheduled) final  TripStatus status;
@override final  String? vehicleRegistrationNumber;

/// Create a copy of BookingTripSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingTripSummaryResponseCopyWith<_BookingTripSummaryResponse> get copyWith => __$BookingTripSummaryResponseCopyWithImpl<_BookingTripSummaryResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingTripSummaryResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingTripSummaryResponse&&(identical(other.scheduledDepartureAt, scheduledDepartureAt) || other.scheduledDepartureAt == scheduledDepartureAt)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.originStopName, originStopName) || other.originStopName == originStopName)&&(identical(other.destinationStopName, destinationStopName) || other.destinationStopName == destinationStopName)&&(identical(other.status, status) || other.status == status)&&(identical(other.vehicleRegistrationNumber, vehicleRegistrationNumber) || other.vehicleRegistrationNumber == vehicleRegistrationNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scheduledDepartureAt,routeName,originStopName,destinationStopName,status,vehicleRegistrationNumber);

@override
String toString() {
  return 'BookingTripSummaryResponse(scheduledDepartureAt: $scheduledDepartureAt, routeName: $routeName, originStopName: $originStopName, destinationStopName: $destinationStopName, status: $status, vehicleRegistrationNumber: $vehicleRegistrationNumber)';
}


}

/// @nodoc
abstract mixin class _$BookingTripSummaryResponseCopyWith<$Res> implements $BookingTripSummaryResponseCopyWith<$Res> {
  factory _$BookingTripSummaryResponseCopyWith(_BookingTripSummaryResponse value, $Res Function(_BookingTripSummaryResponse) _then) = __$BookingTripSummaryResponseCopyWithImpl;
@override @useResult
$Res call({
 DateTime scheduledDepartureAt, String routeName, String originStopName, String destinationStopName,@JsonKey(unknownEnumValue: TripStatus.scheduled) TripStatus status, String? vehicleRegistrationNumber
});




}
/// @nodoc
class __$BookingTripSummaryResponseCopyWithImpl<$Res>
    implements _$BookingTripSummaryResponseCopyWith<$Res> {
  __$BookingTripSummaryResponseCopyWithImpl(this._self, this._then);

  final _BookingTripSummaryResponse _self;
  final $Res Function(_BookingTripSummaryResponse) _then;

/// Create a copy of BookingTripSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scheduledDepartureAt = null,Object? routeName = null,Object? originStopName = null,Object? destinationStopName = null,Object? status = null,Object? vehicleRegistrationNumber = freezed,}) {
  return _then(_BookingTripSummaryResponse(
scheduledDepartureAt: null == scheduledDepartureAt ? _self.scheduledDepartureAt : scheduledDepartureAt // ignore: cast_nullable_to_non_nullable
as DateTime,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,originStopName: null == originStopName ? _self.originStopName : originStopName // ignore: cast_nullable_to_non_nullable
as String,destinationStopName: null == destinationStopName ? _self.destinationStopName : destinationStopName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TripStatus,vehicleRegistrationNumber: freezed == vehicleRegistrationNumber ? _self.vehicleRegistrationNumber : vehicleRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$BookingResponse {

 String get id; String get bookingReference; String get tripId;@JsonKey(unknownEnumValue: BookingStatus.pending) BookingStatus get status; int get passengerCount; String? get originStopId; String? get destinationStopId;@JsonKey(fromJson: decimalString) String get fareAmount;@JsonKey(fromJson: decimalString) String get platformFee;@JsonKey(fromJson: decimalString) String get totalAmount;/// When the seat hold lapses (pending bookings).
 DateTime? get expiresAt; DateTime get createdAt; List<BookingPassengerResponse> get passengers; BookingTripSummaryResponse? get trip; String? get boardingStopName; String? get alightingStopName;
/// Create a copy of BookingResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingResponseCopyWith<BookingResponse> get copyWith => _$BookingResponseCopyWithImpl<BookingResponse>(this as BookingResponse, _$identity);

  /// Serializes this BookingResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingReference, bookingReference) || other.bookingReference == bookingReference)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.status, status) || other.status == status)&&(identical(other.passengerCount, passengerCount) || other.passengerCount == passengerCount)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.platformFee, platformFee) || other.platformFee == platformFee)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.passengers, passengers)&&(identical(other.trip, trip) || other.trip == trip)&&(identical(other.boardingStopName, boardingStopName) || other.boardingStopName == boardingStopName)&&(identical(other.alightingStopName, alightingStopName) || other.alightingStopName == alightingStopName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingReference,tripId,status,passengerCount,originStopId,destinationStopId,fareAmount,platformFee,totalAmount,expiresAt,createdAt,const DeepCollectionEquality().hash(passengers),trip,boardingStopName,alightingStopName);

@override
String toString() {
  return 'BookingResponse(id: $id, bookingReference: $bookingReference, tripId: $tripId, status: $status, passengerCount: $passengerCount, originStopId: $originStopId, destinationStopId: $destinationStopId, fareAmount: $fareAmount, platformFee: $platformFee, totalAmount: $totalAmount, expiresAt: $expiresAt, createdAt: $createdAt, passengers: $passengers, trip: $trip, boardingStopName: $boardingStopName, alightingStopName: $alightingStopName)';
}


}

/// @nodoc
abstract mixin class $BookingResponseCopyWith<$Res>  {
  factory $BookingResponseCopyWith(BookingResponse value, $Res Function(BookingResponse) _then) = _$BookingResponseCopyWithImpl;
@useResult
$Res call({
 String id, String bookingReference, String tripId,@JsonKey(unknownEnumValue: BookingStatus.pending) BookingStatus status, int passengerCount, String? originStopId, String? destinationStopId,@JsonKey(fromJson: decimalString) String fareAmount,@JsonKey(fromJson: decimalString) String platformFee,@JsonKey(fromJson: decimalString) String totalAmount, DateTime? expiresAt, DateTime createdAt, List<BookingPassengerResponse> passengers, BookingTripSummaryResponse? trip, String? boardingStopName, String? alightingStopName
});


$BookingTripSummaryResponseCopyWith<$Res>? get trip;

}
/// @nodoc
class _$BookingResponseCopyWithImpl<$Res>
    implements $BookingResponseCopyWith<$Res> {
  _$BookingResponseCopyWithImpl(this._self, this._then);

  final BookingResponse _self;
  final $Res Function(BookingResponse) _then;

/// Create a copy of BookingResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookingReference = null,Object? tripId = null,Object? status = null,Object? passengerCount = null,Object? originStopId = freezed,Object? destinationStopId = freezed,Object? fareAmount = null,Object? platformFee = null,Object? totalAmount = null,Object? expiresAt = freezed,Object? createdAt = null,Object? passengers = null,Object? trip = freezed,Object? boardingStopName = freezed,Object? alightingStopName = freezed,}) {
  return _then(BookingResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingReference: null == bookingReference ? _self.bookingReference : bookingReference // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,passengerCount: null == passengerCount ? _self.passengerCount : passengerCount // ignore: cast_nullable_to_non_nullable
as int,originStopId: freezed == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String?,destinationStopId: freezed == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String?,fareAmount: null == fareAmount ? _self.fareAmount : fareAmount // ignore: cast_nullable_to_non_nullable
as String,platformFee: null == platformFee ? _self.platformFee : platformFee // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,passengers: null == passengers ? _self.passengers : passengers // ignore: cast_nullable_to_non_nullable
as List<BookingPassengerResponse>,trip: freezed == trip ? _self.trip : trip // ignore: cast_nullable_to_non_nullable
as BookingTripSummaryResponse?,boardingStopName: freezed == boardingStopName ? _self.boardingStopName : boardingStopName // ignore: cast_nullable_to_non_nullable
as String?,alightingStopName: freezed == alightingStopName ? _self.alightingStopName : alightingStopName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of BookingResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingTripSummaryResponseCopyWith<$Res>? get trip {
    if (_self.trip == null) {
    return null;
  }

  return $BookingTripSummaryResponseCopyWith<$Res>(_self.trip!, (value) {
    return _then(_self.copyWith(trip: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookingResponse].
extension BookingResponsePatterns on BookingResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingResponse value)  $default,){
final _that = this;
switch (_that) {
case _BookingResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingResponse value)?  $default,){
final _that = this;
switch (_that) {
case _BookingResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String bookingReference,  String tripId, @JsonKey(unknownEnumValue: BookingStatus.pending)  BookingStatus status,  int passengerCount,  String? originStopId,  String? destinationStopId, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String totalAmount,  DateTime? expiresAt,  DateTime createdAt,  List<BookingPassengerResponse> passengers,  BookingTripSummaryResponse? trip,  String? boardingStopName,  String? alightingStopName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingResponse() when $default != null:
return $default(_that.id,_that.bookingReference,_that.tripId,_that.status,_that.passengerCount,_that.originStopId,_that.destinationStopId,_that.fareAmount,_that.platformFee,_that.totalAmount,_that.expiresAt,_that.createdAt,_that.passengers,_that.trip,_that.boardingStopName,_that.alightingStopName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String bookingReference,  String tripId, @JsonKey(unknownEnumValue: BookingStatus.pending)  BookingStatus status,  int passengerCount,  String? originStopId,  String? destinationStopId, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String totalAmount,  DateTime? expiresAt,  DateTime createdAt,  List<BookingPassengerResponse> passengers,  BookingTripSummaryResponse? trip,  String? boardingStopName,  String? alightingStopName)  $default,) {final _that = this;
switch (_that) {
case _BookingResponse():
return $default(_that.id,_that.bookingReference,_that.tripId,_that.status,_that.passengerCount,_that.originStopId,_that.destinationStopId,_that.fareAmount,_that.platformFee,_that.totalAmount,_that.expiresAt,_that.createdAt,_that.passengers,_that.trip,_that.boardingStopName,_that.alightingStopName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String bookingReference,  String tripId, @JsonKey(unknownEnumValue: BookingStatus.pending)  BookingStatus status,  int passengerCount,  String? originStopId,  String? destinationStopId, @JsonKey(fromJson: decimalString)  String fareAmount, @JsonKey(fromJson: decimalString)  String platformFee, @JsonKey(fromJson: decimalString)  String totalAmount,  DateTime? expiresAt,  DateTime createdAt,  List<BookingPassengerResponse> passengers,  BookingTripSummaryResponse? trip,  String? boardingStopName,  String? alightingStopName)?  $default,) {final _that = this;
switch (_that) {
case _BookingResponse() when $default != null:
return $default(_that.id,_that.bookingReference,_that.tripId,_that.status,_that.passengerCount,_that.originStopId,_that.destinationStopId,_that.fareAmount,_that.platformFee,_that.totalAmount,_that.expiresAt,_that.createdAt,_that.passengers,_that.trip,_that.boardingStopName,_that.alightingStopName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingResponse implements BookingResponse {
  const _BookingResponse({required this.id, required this.bookingReference, required this.tripId, @JsonKey(unknownEnumValue: BookingStatus.pending) required this.status, required this.passengerCount, this.originStopId, this.destinationStopId, @JsonKey(fromJson: decimalString) required this.fareAmount, @JsonKey(fromJson: decimalString) required this.platformFee, @JsonKey(fromJson: decimalString) required this.totalAmount, this.expiresAt, required this.createdAt, required  List<BookingPassengerResponse> passengers, this.trip, this.boardingStopName, this.alightingStopName}): _passengers = passengers;
  factory _BookingResponse.fromJson(Map<String, dynamic> json) => _$BookingResponseFromJson(json);

@override final  String id;
@override final  String bookingReference;
@override final  String tripId;
@override@JsonKey(unknownEnumValue: BookingStatus.pending) final  BookingStatus status;
@override final  int passengerCount;
@override final  String? originStopId;
@override final  String? destinationStopId;
@override@JsonKey(fromJson: decimalString) final  String fareAmount;
@override@JsonKey(fromJson: decimalString) final  String platformFee;
@override@JsonKey(fromJson: decimalString) final  String totalAmount;
/// When the seat hold lapses (pending bookings).
@override final  DateTime? expiresAt;
@override final  DateTime createdAt;
 final  List<BookingPassengerResponse> _passengers;
@override List<BookingPassengerResponse> get passengers {
  if (_passengers is EqualUnmodifiableListView) return _passengers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_passengers);
}

@override final  BookingTripSummaryResponse? trip;
@override final  String? boardingStopName;
@override final  String? alightingStopName;

/// Create a copy of BookingResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingResponseCopyWith<_BookingResponse> get copyWith => __$BookingResponseCopyWithImpl<_BookingResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingReference, bookingReference) || other.bookingReference == bookingReference)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.status, status) || other.status == status)&&(identical(other.passengerCount, passengerCount) || other.passengerCount == passengerCount)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.fareAmount, fareAmount) || other.fareAmount == fareAmount)&&(identical(other.platformFee, platformFee) || other.platformFee == platformFee)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._passengers, _passengers)&&(identical(other.trip, trip) || other.trip == trip)&&(identical(other.boardingStopName, boardingStopName) || other.boardingStopName == boardingStopName)&&(identical(other.alightingStopName, alightingStopName) || other.alightingStopName == alightingStopName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingReference,tripId,status,passengerCount,originStopId,destinationStopId,fareAmount,platformFee,totalAmount,expiresAt,createdAt,const DeepCollectionEquality().hash(_passengers),trip,boardingStopName,alightingStopName);

@override
String toString() {
  return 'BookingResponse(id: $id, bookingReference: $bookingReference, tripId: $tripId, status: $status, passengerCount: $passengerCount, originStopId: $originStopId, destinationStopId: $destinationStopId, fareAmount: $fareAmount, platformFee: $platformFee, totalAmount: $totalAmount, expiresAt: $expiresAt, createdAt: $createdAt, passengers: $passengers, trip: $trip, boardingStopName: $boardingStopName, alightingStopName: $alightingStopName)';
}


}

/// @nodoc
abstract mixin class _$BookingResponseCopyWith<$Res> implements $BookingResponseCopyWith<$Res> {
  factory _$BookingResponseCopyWith(_BookingResponse value, $Res Function(_BookingResponse) _then) = __$BookingResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String bookingReference, String tripId,@JsonKey(unknownEnumValue: BookingStatus.pending) BookingStatus status, int passengerCount, String? originStopId, String? destinationStopId,@JsonKey(fromJson: decimalString) String fareAmount,@JsonKey(fromJson: decimalString) String platformFee,@JsonKey(fromJson: decimalString) String totalAmount, DateTime? expiresAt, DateTime createdAt, List<BookingPassengerResponse> passengers, BookingTripSummaryResponse? trip, String? boardingStopName, String? alightingStopName
});


@override $BookingTripSummaryResponseCopyWith<$Res>? get trip;

}
/// @nodoc
class __$BookingResponseCopyWithImpl<$Res>
    implements _$BookingResponseCopyWith<$Res> {
  __$BookingResponseCopyWithImpl(this._self, this._then);

  final _BookingResponse _self;
  final $Res Function(_BookingResponse) _then;

/// Create a copy of BookingResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookingReference = null,Object? tripId = null,Object? status = null,Object? passengerCount = null,Object? originStopId = freezed,Object? destinationStopId = freezed,Object? fareAmount = null,Object? platformFee = null,Object? totalAmount = null,Object? expiresAt = freezed,Object? createdAt = null,Object? passengers = null,Object? trip = freezed,Object? boardingStopName = freezed,Object? alightingStopName = freezed,}) {
  return _then(_BookingResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingReference: null == bookingReference ? _self.bookingReference : bookingReference // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,passengerCount: null == passengerCount ? _self.passengerCount : passengerCount // ignore: cast_nullable_to_non_nullable
as int,originStopId: freezed == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String?,destinationStopId: freezed == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String?,fareAmount: null == fareAmount ? _self.fareAmount : fareAmount // ignore: cast_nullable_to_non_nullable
as String,platformFee: null == platformFee ? _self.platformFee : platformFee // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,passengers: null == passengers ? _self._passengers : passengers // ignore: cast_nullable_to_non_nullable
as List<BookingPassengerResponse>,trip: freezed == trip ? _self.trip : trip // ignore: cast_nullable_to_non_nullable
as BookingTripSummaryResponse?,boardingStopName: freezed == boardingStopName ? _self.boardingStopName : boardingStopName // ignore: cast_nullable_to_non_nullable
as String?,alightingStopName: freezed == alightingStopName ? _self.alightingStopName : alightingStopName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of BookingResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingTripSummaryResponseCopyWith<$Res>? get trip {
    if (_self.trip == null) {
    return null;
  }

  return $BookingTripSummaryResponseCopyWith<$Res>(_self.trip!, (value) {
    return _then(_self.copyWith(trip: value));
  });
}
}

// dart format on
