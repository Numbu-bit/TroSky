// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ticket_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TicketResponse {

 String get id; String get ticketReference; String get bookingId; String get bookingPassengerId; String get tripId;@JsonKey(unknownEnumValue: TicketStatus.issued) TicketStatus get status; DateTime get issuedAt; DateTime get expiresAt; DateTime? get validatedAt; String get qrToken;
/// Create a copy of TicketResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketResponseCopyWith<TicketResponse> get copyWith => _$TicketResponseCopyWithImpl<TicketResponse>(this as TicketResponse, _$identity);

  /// Serializes this TicketResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketReference, ticketReference) || other.ticketReference == ticketReference)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.bookingPassengerId, bookingPassengerId) || other.bookingPassengerId == bookingPassengerId)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.status, status) || other.status == status)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.validatedAt, validatedAt) || other.validatedAt == validatedAt)&&(identical(other.qrToken, qrToken) || other.qrToken == qrToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketReference,bookingId,bookingPassengerId,tripId,status,issuedAt,expiresAt,validatedAt,qrToken);

@override
String toString() {
  return 'TicketResponse(id: $id, ticketReference: $ticketReference, bookingId: $bookingId, bookingPassengerId: $bookingPassengerId, tripId: $tripId, status: $status, issuedAt: $issuedAt, expiresAt: $expiresAt, validatedAt: $validatedAt, qrToken: $qrToken)';
}


}

/// @nodoc
abstract mixin class $TicketResponseCopyWith<$Res>  {
  factory $TicketResponseCopyWith(TicketResponse value, $Res Function(TicketResponse) _then) = _$TicketResponseCopyWithImpl;
@useResult
$Res call({
 String id, String ticketReference, String bookingId, String bookingPassengerId, String tripId,@JsonKey(unknownEnumValue: TicketStatus.issued) TicketStatus status, DateTime issuedAt, DateTime expiresAt, DateTime? validatedAt, String qrToken
});




}
/// @nodoc
class _$TicketResponseCopyWithImpl<$Res>
    implements $TicketResponseCopyWith<$Res> {
  _$TicketResponseCopyWithImpl(this._self, this._then);

  final TicketResponse _self;
  final $Res Function(TicketResponse) _then;

/// Create a copy of TicketResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketReference = null,Object? bookingId = null,Object? bookingPassengerId = null,Object? tripId = null,Object? status = null,Object? issuedAt = null,Object? expiresAt = null,Object? validatedAt = freezed,Object? qrToken = null,}) {
  return _then(TicketResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketReference: null == ticketReference ? _self.ticketReference : ticketReference // ignore: cast_nullable_to_non_nullable
as String,bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,bookingPassengerId: null == bookingPassengerId ? _self.bookingPassengerId : bookingPassengerId // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TicketStatus,issuedAt: null == issuedAt ? _self.issuedAt : issuedAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,validatedAt: freezed == validatedAt ? _self.validatedAt : validatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,qrToken: null == qrToken ? _self.qrToken : qrToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketResponse].
extension TicketResponsePatterns on TicketResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketResponse value)  $default,){
final _that = this;
switch (_that) {
case _TicketResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TicketResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ticketReference,  String bookingId,  String bookingPassengerId,  String tripId, @JsonKey(unknownEnumValue: TicketStatus.issued)  TicketStatus status,  DateTime issuedAt,  DateTime expiresAt,  DateTime? validatedAt,  String qrToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketResponse() when $default != null:
return $default(_that.id,_that.ticketReference,_that.bookingId,_that.bookingPassengerId,_that.tripId,_that.status,_that.issuedAt,_that.expiresAt,_that.validatedAt,_that.qrToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ticketReference,  String bookingId,  String bookingPassengerId,  String tripId, @JsonKey(unknownEnumValue: TicketStatus.issued)  TicketStatus status,  DateTime issuedAt,  DateTime expiresAt,  DateTime? validatedAt,  String qrToken)  $default,) {final _that = this;
switch (_that) {
case _TicketResponse():
return $default(_that.id,_that.ticketReference,_that.bookingId,_that.bookingPassengerId,_that.tripId,_that.status,_that.issuedAt,_that.expiresAt,_that.validatedAt,_that.qrToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ticketReference,  String bookingId,  String bookingPassengerId,  String tripId, @JsonKey(unknownEnumValue: TicketStatus.issued)  TicketStatus status,  DateTime issuedAt,  DateTime expiresAt,  DateTime? validatedAt,  String qrToken)?  $default,) {final _that = this;
switch (_that) {
case _TicketResponse() when $default != null:
return $default(_that.id,_that.ticketReference,_that.bookingId,_that.bookingPassengerId,_that.tripId,_that.status,_that.issuedAt,_that.expiresAt,_that.validatedAt,_that.qrToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketResponse implements TicketResponse {
  const _TicketResponse({required this.id, required this.ticketReference, required this.bookingId, required this.bookingPassengerId, required this.tripId, @JsonKey(unknownEnumValue: TicketStatus.issued) required this.status, required this.issuedAt, required this.expiresAt, this.validatedAt, required this.qrToken});
  factory _TicketResponse.fromJson(Map<String, dynamic> json) => _$TicketResponseFromJson(json);

@override final  String id;
@override final  String ticketReference;
@override final  String bookingId;
@override final  String bookingPassengerId;
@override final  String tripId;
@override@JsonKey(unknownEnumValue: TicketStatus.issued) final  TicketStatus status;
@override final  DateTime issuedAt;
@override final  DateTime expiresAt;
@override final  DateTime? validatedAt;
@override final  String qrToken;

/// Create a copy of TicketResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketResponseCopyWith<_TicketResponse> get copyWith => __$TicketResponseCopyWithImpl<_TicketResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketReference, ticketReference) || other.ticketReference == ticketReference)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.bookingPassengerId, bookingPassengerId) || other.bookingPassengerId == bookingPassengerId)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.status, status) || other.status == status)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.validatedAt, validatedAt) || other.validatedAt == validatedAt)&&(identical(other.qrToken, qrToken) || other.qrToken == qrToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketReference,bookingId,bookingPassengerId,tripId,status,issuedAt,expiresAt,validatedAt,qrToken);

@override
String toString() {
  return 'TicketResponse(id: $id, ticketReference: $ticketReference, bookingId: $bookingId, bookingPassengerId: $bookingPassengerId, tripId: $tripId, status: $status, issuedAt: $issuedAt, expiresAt: $expiresAt, validatedAt: $validatedAt, qrToken: $qrToken)';
}


}

/// @nodoc
abstract mixin class _$TicketResponseCopyWith<$Res> implements $TicketResponseCopyWith<$Res> {
  factory _$TicketResponseCopyWith(_TicketResponse value, $Res Function(_TicketResponse) _then) = __$TicketResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String ticketReference, String bookingId, String bookingPassengerId, String tripId,@JsonKey(unknownEnumValue: TicketStatus.issued) TicketStatus status, DateTime issuedAt, DateTime expiresAt, DateTime? validatedAt, String qrToken
});




}
/// @nodoc
class __$TicketResponseCopyWithImpl<$Res>
    implements _$TicketResponseCopyWith<$Res> {
  __$TicketResponseCopyWithImpl(this._self, this._then);

  final _TicketResponse _self;
  final $Res Function(_TicketResponse) _then;

/// Create a copy of TicketResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketReference = null,Object? bookingId = null,Object? bookingPassengerId = null,Object? tripId = null,Object? status = null,Object? issuedAt = null,Object? expiresAt = null,Object? validatedAt = freezed,Object? qrToken = null,}) {
  return _then(_TicketResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketReference: null == ticketReference ? _self.ticketReference : ticketReference // ignore: cast_nullable_to_non_nullable
as String,bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,bookingPassengerId: null == bookingPassengerId ? _self.bookingPassengerId : bookingPassengerId // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TicketStatus,issuedAt: null == issuedAt ? _self.issuedAt : issuedAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,validatedAt: freezed == validatedAt ? _self.validatedAt : validatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,qrToken: null == qrToken ? _self.qrToken : qrToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
