// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DriverResponse {

 String get id; String get userId; String get licenseNumber; DateTime get licenseExpiry; String? get licenseClass; int? get yearsOfExperience; ApprovalStatus get status; DateTime get createdAt;
/// Create a copy of DriverResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverResponseCopyWith<DriverResponse> get copyWith => _$DriverResponseCopyWithImpl<DriverResponse>(this as DriverResponse, _$identity);

  /// Serializes this DriverResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.licenseNumber, licenseNumber) || other.licenseNumber == licenseNumber)&&(identical(other.licenseExpiry, licenseExpiry) || other.licenseExpiry == licenseExpiry)&&(identical(other.licenseClass, licenseClass) || other.licenseClass == licenseClass)&&(identical(other.yearsOfExperience, yearsOfExperience) || other.yearsOfExperience == yearsOfExperience)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,licenseNumber,licenseExpiry,licenseClass,yearsOfExperience,status,createdAt);

@override
String toString() {
  return 'DriverResponse(id: $id, userId: $userId, licenseNumber: $licenseNumber, licenseExpiry: $licenseExpiry, licenseClass: $licenseClass, yearsOfExperience: $yearsOfExperience, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $DriverResponseCopyWith<$Res>  {
  factory $DriverResponseCopyWith(DriverResponse value, $Res Function(DriverResponse) _then) = _$DriverResponseCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String licenseNumber, DateTime licenseExpiry, String? licenseClass, int? yearsOfExperience, ApprovalStatus status, DateTime createdAt
});




}
/// @nodoc
class _$DriverResponseCopyWithImpl<$Res>
    implements $DriverResponseCopyWith<$Res> {
  _$DriverResponseCopyWithImpl(this._self, this._then);

  final DriverResponse _self;
  final $Res Function(DriverResponse) _then;

/// Create a copy of DriverResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? licenseNumber = null,Object? licenseExpiry = null,Object? licenseClass = freezed,Object? yearsOfExperience = freezed,Object? status = null,Object? createdAt = null,}) {
  return _then(DriverResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,licenseNumber: null == licenseNumber ? _self.licenseNumber : licenseNumber // ignore: cast_nullable_to_non_nullable
as String,licenseExpiry: null == licenseExpiry ? _self.licenseExpiry : licenseExpiry // ignore: cast_nullable_to_non_nullable
as DateTime,licenseClass: freezed == licenseClass ? _self.licenseClass : licenseClass // ignore: cast_nullable_to_non_nullable
as String?,yearsOfExperience: freezed == yearsOfExperience ? _self.yearsOfExperience : yearsOfExperience // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ApprovalStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DriverResponse].
extension DriverResponsePatterns on DriverResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverResponse value)  $default,){
final _that = this;
switch (_that) {
case _DriverResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverResponse value)?  $default,){
final _that = this;
switch (_that) {
case _DriverResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String licenseNumber,  DateTime licenseExpiry,  String? licenseClass,  int? yearsOfExperience,  ApprovalStatus status,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverResponse() when $default != null:
return $default(_that.id,_that.userId,_that.licenseNumber,_that.licenseExpiry,_that.licenseClass,_that.yearsOfExperience,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String licenseNumber,  DateTime licenseExpiry,  String? licenseClass,  int? yearsOfExperience,  ApprovalStatus status,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _DriverResponse():
return $default(_that.id,_that.userId,_that.licenseNumber,_that.licenseExpiry,_that.licenseClass,_that.yearsOfExperience,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String licenseNumber,  DateTime licenseExpiry,  String? licenseClass,  int? yearsOfExperience,  ApprovalStatus status,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _DriverResponse() when $default != null:
return $default(_that.id,_that.userId,_that.licenseNumber,_that.licenseExpiry,_that.licenseClass,_that.yearsOfExperience,_that.status,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DriverResponse implements DriverResponse {
  const _DriverResponse({required this.id, required this.userId, required this.licenseNumber, required this.licenseExpiry, this.licenseClass, this.yearsOfExperience, required this.status, required this.createdAt});
  factory _DriverResponse.fromJson(Map<String, dynamic> json) => _$DriverResponseFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String licenseNumber;
@override final  DateTime licenseExpiry;
@override final  String? licenseClass;
@override final  int? yearsOfExperience;
@override final  ApprovalStatus status;
@override final  DateTime createdAt;

/// Create a copy of DriverResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverResponseCopyWith<_DriverResponse> get copyWith => __$DriverResponseCopyWithImpl<_DriverResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DriverResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.licenseNumber, licenseNumber) || other.licenseNumber == licenseNumber)&&(identical(other.licenseExpiry, licenseExpiry) || other.licenseExpiry == licenseExpiry)&&(identical(other.licenseClass, licenseClass) || other.licenseClass == licenseClass)&&(identical(other.yearsOfExperience, yearsOfExperience) || other.yearsOfExperience == yearsOfExperience)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,licenseNumber,licenseExpiry,licenseClass,yearsOfExperience,status,createdAt);

@override
String toString() {
  return 'DriverResponse(id: $id, userId: $userId, licenseNumber: $licenseNumber, licenseExpiry: $licenseExpiry, licenseClass: $licenseClass, yearsOfExperience: $yearsOfExperience, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$DriverResponseCopyWith<$Res> implements $DriverResponseCopyWith<$Res> {
  factory _$DriverResponseCopyWith(_DriverResponse value, $Res Function(_DriverResponse) _then) = __$DriverResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String licenseNumber, DateTime licenseExpiry, String? licenseClass, int? yearsOfExperience, ApprovalStatus status, DateTime createdAt
});




}
/// @nodoc
class __$DriverResponseCopyWithImpl<$Res>
    implements _$DriverResponseCopyWith<$Res> {
  __$DriverResponseCopyWithImpl(this._self, this._then);

  final _DriverResponse _self;
  final $Res Function(_DriverResponse) _then;

/// Create a copy of DriverResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? licenseNumber = null,Object? licenseExpiry = null,Object? licenseClass = freezed,Object? yearsOfExperience = freezed,Object? status = null,Object? createdAt = null,}) {
  return _then(_DriverResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,licenseNumber: null == licenseNumber ? _self.licenseNumber : licenseNumber // ignore: cast_nullable_to_non_nullable
as String,licenseExpiry: null == licenseExpiry ? _self.licenseExpiry : licenseExpiry // ignore: cast_nullable_to_non_nullable
as DateTime,licenseClass: freezed == licenseClass ? _self.licenseClass : licenseClass // ignore: cast_nullable_to_non_nullable
as String?,yearsOfExperience: freezed == yearsOfExperience ? _self.yearsOfExperience : yearsOfExperience // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ApprovalStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
