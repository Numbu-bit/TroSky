// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentResponse {

 String get id; String? get bookingId;@JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment) PaymentPurpose get purpose;@JsonKey(unknownEnumValue: PaymentChannel.card) PaymentChannel get channel;@JsonKey(unknownEnumValue: PaymentStatus.processing) PaymentStatus get status;@JsonKey(fromJson: decimalString) String get amount; String get currency;@JsonKey(fromJson: decimalString) String get refundedAmount; String? get providerReference;/// Why it failed ("Customer declined the payment prompt.").
 String? get failureReason; DateTime? get initiatedAt; DateTime? get completedAt; DateTime get createdAt;
/// Create a copy of PaymentResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentResponseCopyWith<PaymentResponse> get copyWith => _$PaymentResponseCopyWithImpl<PaymentResponse>(this as PaymentResponse, _$identity);

  /// Serializes this PaymentResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.status, status) || other.status == status)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.refundedAmount, refundedAmount) || other.refundedAmount == refundedAmount)&&(identical(other.providerReference, providerReference) || other.providerReference == providerReference)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason)&&(identical(other.initiatedAt, initiatedAt) || other.initiatedAt == initiatedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingId,purpose,channel,status,amount,currency,refundedAmount,providerReference,failureReason,initiatedAt,completedAt,createdAt);

@override
String toString() {
  return 'PaymentResponse(id: $id, bookingId: $bookingId, purpose: $purpose, channel: $channel, status: $status, amount: $amount, currency: $currency, refundedAmount: $refundedAmount, providerReference: $providerReference, failureReason: $failureReason, initiatedAt: $initiatedAt, completedAt: $completedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PaymentResponseCopyWith<$Res>  {
  factory $PaymentResponseCopyWith(PaymentResponse value, $Res Function(PaymentResponse) _then) = _$PaymentResponseCopyWithImpl;
@useResult
$Res call({
 String id, String? bookingId,@JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment) PaymentPurpose purpose,@JsonKey(unknownEnumValue: PaymentChannel.card) PaymentChannel channel,@JsonKey(unknownEnumValue: PaymentStatus.processing) PaymentStatus status,@JsonKey(fromJson: decimalString) String amount, String currency,@JsonKey(fromJson: decimalString) String refundedAmount, String? providerReference, String? failureReason, DateTime? initiatedAt, DateTime? completedAt, DateTime createdAt
});




}
/// @nodoc
class _$PaymentResponseCopyWithImpl<$Res>
    implements $PaymentResponseCopyWith<$Res> {
  _$PaymentResponseCopyWithImpl(this._self, this._then);

  final PaymentResponse _self;
  final $Res Function(PaymentResponse) _then;

/// Create a copy of PaymentResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookingId = freezed,Object? purpose = null,Object? channel = null,Object? status = null,Object? amount = null,Object? currency = null,Object? refundedAmount = null,Object? providerReference = freezed,Object? failureReason = freezed,Object? initiatedAt = freezed,Object? completedAt = freezed,Object? createdAt = null,}) {
  return _then(PaymentResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingId: freezed == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String?,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as PaymentPurpose,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,refundedAmount: null == refundedAmount ? _self.refundedAmount : refundedAmount // ignore: cast_nullable_to_non_nullable
as String,providerReference: freezed == providerReference ? _self.providerReference : providerReference // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,initiatedAt: freezed == initiatedAt ? _self.initiatedAt : initiatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentResponse].
extension PaymentResponsePatterns on PaymentResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentResponse value)  $default,){
final _that = this;
switch (_that) {
case _PaymentResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentResponse value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? bookingId, @JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment)  PaymentPurpose purpose, @JsonKey(unknownEnumValue: PaymentChannel.card)  PaymentChannel channel, @JsonKey(unknownEnumValue: PaymentStatus.processing)  PaymentStatus status, @JsonKey(fromJson: decimalString)  String amount,  String currency, @JsonKey(fromJson: decimalString)  String refundedAmount,  String? providerReference,  String? failureReason,  DateTime? initiatedAt,  DateTime? completedAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentResponse() when $default != null:
return $default(_that.id,_that.bookingId,_that.purpose,_that.channel,_that.status,_that.amount,_that.currency,_that.refundedAmount,_that.providerReference,_that.failureReason,_that.initiatedAt,_that.completedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? bookingId, @JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment)  PaymentPurpose purpose, @JsonKey(unknownEnumValue: PaymentChannel.card)  PaymentChannel channel, @JsonKey(unknownEnumValue: PaymentStatus.processing)  PaymentStatus status, @JsonKey(fromJson: decimalString)  String amount,  String currency, @JsonKey(fromJson: decimalString)  String refundedAmount,  String? providerReference,  String? failureReason,  DateTime? initiatedAt,  DateTime? completedAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _PaymentResponse():
return $default(_that.id,_that.bookingId,_that.purpose,_that.channel,_that.status,_that.amount,_that.currency,_that.refundedAmount,_that.providerReference,_that.failureReason,_that.initiatedAt,_that.completedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? bookingId, @JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment)  PaymentPurpose purpose, @JsonKey(unknownEnumValue: PaymentChannel.card)  PaymentChannel channel, @JsonKey(unknownEnumValue: PaymentStatus.processing)  PaymentStatus status, @JsonKey(fromJson: decimalString)  String amount,  String currency, @JsonKey(fromJson: decimalString)  String refundedAmount,  String? providerReference,  String? failureReason,  DateTime? initiatedAt,  DateTime? completedAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PaymentResponse() when $default != null:
return $default(_that.id,_that.bookingId,_that.purpose,_that.channel,_that.status,_that.amount,_that.currency,_that.refundedAmount,_that.providerReference,_that.failureReason,_that.initiatedAt,_that.completedAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentResponse implements PaymentResponse {
  const _PaymentResponse({required this.id, this.bookingId, @JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment) required this.purpose, @JsonKey(unknownEnumValue: PaymentChannel.card) required this.channel, @JsonKey(unknownEnumValue: PaymentStatus.processing) required this.status, @JsonKey(fromJson: decimalString) required this.amount, required this.currency, @JsonKey(fromJson: decimalString) required this.refundedAmount, this.providerReference, this.failureReason, this.initiatedAt, this.completedAt, required this.createdAt});
  factory _PaymentResponse.fromJson(Map<String, dynamic> json) => _$PaymentResponseFromJson(json);

@override final  String id;
@override final  String? bookingId;
@override@JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment) final  PaymentPurpose purpose;
@override@JsonKey(unknownEnumValue: PaymentChannel.card) final  PaymentChannel channel;
@override@JsonKey(unknownEnumValue: PaymentStatus.processing) final  PaymentStatus status;
@override@JsonKey(fromJson: decimalString) final  String amount;
@override final  String currency;
@override@JsonKey(fromJson: decimalString) final  String refundedAmount;
@override final  String? providerReference;
/// Why it failed ("Customer declined the payment prompt.").
@override final  String? failureReason;
@override final  DateTime? initiatedAt;
@override final  DateTime? completedAt;
@override final  DateTime createdAt;

/// Create a copy of PaymentResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentResponseCopyWith<_PaymentResponse> get copyWith => __$PaymentResponseCopyWithImpl<_PaymentResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.status, status) || other.status == status)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.refundedAmount, refundedAmount) || other.refundedAmount == refundedAmount)&&(identical(other.providerReference, providerReference) || other.providerReference == providerReference)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason)&&(identical(other.initiatedAt, initiatedAt) || other.initiatedAt == initiatedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingId,purpose,channel,status,amount,currency,refundedAmount,providerReference,failureReason,initiatedAt,completedAt,createdAt);

@override
String toString() {
  return 'PaymentResponse(id: $id, bookingId: $bookingId, purpose: $purpose, channel: $channel, status: $status, amount: $amount, currency: $currency, refundedAmount: $refundedAmount, providerReference: $providerReference, failureReason: $failureReason, initiatedAt: $initiatedAt, completedAt: $completedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PaymentResponseCopyWith<$Res> implements $PaymentResponseCopyWith<$Res> {
  factory _$PaymentResponseCopyWith(_PaymentResponse value, $Res Function(_PaymentResponse) _then) = __$PaymentResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String? bookingId,@JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment) PaymentPurpose purpose,@JsonKey(unknownEnumValue: PaymentChannel.card) PaymentChannel channel,@JsonKey(unknownEnumValue: PaymentStatus.processing) PaymentStatus status,@JsonKey(fromJson: decimalString) String amount, String currency,@JsonKey(fromJson: decimalString) String refundedAmount, String? providerReference, String? failureReason, DateTime? initiatedAt, DateTime? completedAt, DateTime createdAt
});




}
/// @nodoc
class __$PaymentResponseCopyWithImpl<$Res>
    implements _$PaymentResponseCopyWith<$Res> {
  __$PaymentResponseCopyWithImpl(this._self, this._then);

  final _PaymentResponse _self;
  final $Res Function(_PaymentResponse) _then;

/// Create a copy of PaymentResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookingId = freezed,Object? purpose = null,Object? channel = null,Object? status = null,Object? amount = null,Object? currency = null,Object? refundedAmount = null,Object? providerReference = freezed,Object? failureReason = freezed,Object? initiatedAt = freezed,Object? completedAt = freezed,Object? createdAt = null,}) {
  return _then(_PaymentResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingId: freezed == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String?,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as PaymentPurpose,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,refundedAmount: null == refundedAmount ? _self.refundedAmount : refundedAmount // ignore: cast_nullable_to_non_nullable
as String,providerReference: freezed == providerReference ? _self.providerReference : providerReference // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,initiatedAt: freezed == initiatedAt ? _self.initiatedAt : initiatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$PayBookingRequest {

 String? get paymentMethodId; PaymentChannel? get channel; String? get payerPhoneNumber;
/// Create a copy of PayBookingRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PayBookingRequestCopyWith<PayBookingRequest> get copyWith => _$PayBookingRequestCopyWithImpl<PayBookingRequest>(this as PayBookingRequest, _$identity);

  /// Serializes this PayBookingRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PayBookingRequest&&(identical(other.paymentMethodId, paymentMethodId) || other.paymentMethodId == paymentMethodId)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.payerPhoneNumber, payerPhoneNumber) || other.payerPhoneNumber == payerPhoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentMethodId,channel,payerPhoneNumber);

@override
String toString() {
  return 'PayBookingRequest(paymentMethodId: $paymentMethodId, channel: $channel, payerPhoneNumber: $payerPhoneNumber)';
}


}

/// @nodoc
abstract mixin class $PayBookingRequestCopyWith<$Res>  {
  factory $PayBookingRequestCopyWith(PayBookingRequest value, $Res Function(PayBookingRequest) _then) = _$PayBookingRequestCopyWithImpl;
@useResult
$Res call({
 String? paymentMethodId, PaymentChannel? channel, String? payerPhoneNumber
});




}
/// @nodoc
class _$PayBookingRequestCopyWithImpl<$Res>
    implements $PayBookingRequestCopyWith<$Res> {
  _$PayBookingRequestCopyWithImpl(this._self, this._then);

  final PayBookingRequest _self;
  final $Res Function(PayBookingRequest) _then;

/// Create a copy of PayBookingRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentMethodId = freezed,Object? channel = freezed,Object? payerPhoneNumber = freezed,}) {
  return _then(PayBookingRequest(
paymentMethodId: freezed == paymentMethodId ? _self.paymentMethodId : paymentMethodId // ignore: cast_nullable_to_non_nullable
as String?,channel: freezed == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel?,payerPhoneNumber: freezed == payerPhoneNumber ? _self.payerPhoneNumber : payerPhoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PayBookingRequest].
extension PayBookingRequestPatterns on PayBookingRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PayBookingRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PayBookingRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PayBookingRequest value)  $default,){
final _that = this;
switch (_that) {
case _PayBookingRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PayBookingRequest value)?  $default,){
final _that = this;
switch (_that) {
case _PayBookingRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? paymentMethodId,  PaymentChannel? channel,  String? payerPhoneNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PayBookingRequest() when $default != null:
return $default(_that.paymentMethodId,_that.channel,_that.payerPhoneNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? paymentMethodId,  PaymentChannel? channel,  String? payerPhoneNumber)  $default,) {final _that = this;
switch (_that) {
case _PayBookingRequest():
return $default(_that.paymentMethodId,_that.channel,_that.payerPhoneNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? paymentMethodId,  PaymentChannel? channel,  String? payerPhoneNumber)?  $default,) {final _that = this;
switch (_that) {
case _PayBookingRequest() when $default != null:
return $default(_that.paymentMethodId,_that.channel,_that.payerPhoneNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PayBookingRequest implements PayBookingRequest {
  const _PayBookingRequest({this.paymentMethodId, this.channel, this.payerPhoneNumber});
  factory _PayBookingRequest.fromJson(Map<String, dynamic> json) => _$PayBookingRequestFromJson(json);

@override final  String? paymentMethodId;
@override final  PaymentChannel? channel;
@override final  String? payerPhoneNumber;

/// Create a copy of PayBookingRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PayBookingRequestCopyWith<_PayBookingRequest> get copyWith => __$PayBookingRequestCopyWithImpl<_PayBookingRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PayBookingRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PayBookingRequest&&(identical(other.paymentMethodId, paymentMethodId) || other.paymentMethodId == paymentMethodId)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.payerPhoneNumber, payerPhoneNumber) || other.payerPhoneNumber == payerPhoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentMethodId,channel,payerPhoneNumber);

@override
String toString() {
  return 'PayBookingRequest(paymentMethodId: $paymentMethodId, channel: $channel, payerPhoneNumber: $payerPhoneNumber)';
}


}

/// @nodoc
abstract mixin class _$PayBookingRequestCopyWith<$Res> implements $PayBookingRequestCopyWith<$Res> {
  factory _$PayBookingRequestCopyWith(_PayBookingRequest value, $Res Function(_PayBookingRequest) _then) = __$PayBookingRequestCopyWithImpl;
@override @useResult
$Res call({
 String? paymentMethodId, PaymentChannel? channel, String? payerPhoneNumber
});




}
/// @nodoc
class __$PayBookingRequestCopyWithImpl<$Res>
    implements _$PayBookingRequestCopyWith<$Res> {
  __$PayBookingRequestCopyWithImpl(this._self, this._then);

  final _PayBookingRequest _self;
  final $Res Function(_PayBookingRequest) _then;

/// Create a copy of PayBookingRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentMethodId = freezed,Object? channel = freezed,Object? payerPhoneNumber = freezed,}) {
  return _then(_PayBookingRequest(
paymentMethodId: freezed == paymentMethodId ? _self.paymentMethodId : paymentMethodId // ignore: cast_nullable_to_non_nullable
as String?,channel: freezed == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel?,payerPhoneNumber: freezed == payerPhoneNumber ? _self.payerPhoneNumber : payerPhoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WalletResponse {

@JsonKey(fromJson: decimalString) String get balance; String get currency;
/// Create a copy of WalletResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WalletResponseCopyWith<WalletResponse> get copyWith => _$WalletResponseCopyWithImpl<WalletResponse>(this as WalletResponse, _$identity);

  /// Serializes this WalletResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WalletResponse&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currency, currency) || other.currency == currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,currency);

@override
String toString() {
  return 'WalletResponse(balance: $balance, currency: $currency)';
}


}

/// @nodoc
abstract mixin class $WalletResponseCopyWith<$Res>  {
  factory $WalletResponseCopyWith(WalletResponse value, $Res Function(WalletResponse) _then) = _$WalletResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: decimalString) String balance, String currency
});




}
/// @nodoc
class _$WalletResponseCopyWithImpl<$Res>
    implements $WalletResponseCopyWith<$Res> {
  _$WalletResponseCopyWithImpl(this._self, this._then);

  final WalletResponse _self;
  final $Res Function(WalletResponse) _then;

/// Create a copy of WalletResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = null,Object? currency = null,}) {
  return _then(WalletResponse(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WalletResponse].
extension WalletResponsePatterns on WalletResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WalletResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WalletResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WalletResponse value)  $default,){
final _that = this;
switch (_that) {
case _WalletResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WalletResponse value)?  $default,){
final _that = this;
switch (_that) {
case _WalletResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: decimalString)  String balance,  String currency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WalletResponse() when $default != null:
return $default(_that.balance,_that.currency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: decimalString)  String balance,  String currency)  $default,) {final _that = this;
switch (_that) {
case _WalletResponse():
return $default(_that.balance,_that.currency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: decimalString)  String balance,  String currency)?  $default,) {final _that = this;
switch (_that) {
case _WalletResponse() when $default != null:
return $default(_that.balance,_that.currency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WalletResponse implements WalletResponse {
  const _WalletResponse({@JsonKey(fromJson: decimalString) required this.balance, required this.currency});
  factory _WalletResponse.fromJson(Map<String, dynamic> json) => _$WalletResponseFromJson(json);

@override@JsonKey(fromJson: decimalString) final  String balance;
@override final  String currency;

/// Create a copy of WalletResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WalletResponseCopyWith<_WalletResponse> get copyWith => __$WalletResponseCopyWithImpl<_WalletResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WalletResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WalletResponse&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currency, currency) || other.currency == currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,currency);

@override
String toString() {
  return 'WalletResponse(balance: $balance, currency: $currency)';
}


}

/// @nodoc
abstract mixin class _$WalletResponseCopyWith<$Res> implements $WalletResponseCopyWith<$Res> {
  factory _$WalletResponseCopyWith(_WalletResponse value, $Res Function(_WalletResponse) _then) = __$WalletResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: decimalString) String balance, String currency
});




}
/// @nodoc
class __$WalletResponseCopyWithImpl<$Res>
    implements _$WalletResponseCopyWith<$Res> {
  __$WalletResponseCopyWithImpl(this._self, this._then);

  final _WalletResponse _self;
  final $Res Function(_WalletResponse) _then;

/// Create a copy of WalletResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = null,Object? currency = null,}) {
  return _then(_WalletResponse(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PaymentMethodResponse {

 String get id;@JsonKey(unknownEnumValue: PaymentChannel.card) PaymentChannel get channel;/// "+23324•••4567".
 String get maskedNumber; String? get label; bool get isDefault; DateTime get createdAt;
/// Create a copy of PaymentMethodResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentMethodResponseCopyWith<PaymentMethodResponse> get copyWith => _$PaymentMethodResponseCopyWithImpl<PaymentMethodResponse>(this as PaymentMethodResponse, _$identity);

  /// Serializes this PaymentMethodResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentMethodResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.maskedNumber, maskedNumber) || other.maskedNumber == maskedNumber)&&(identical(other.label, label) || other.label == label)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channel,maskedNumber,label,isDefault,createdAt);

@override
String toString() {
  return 'PaymentMethodResponse(id: $id, channel: $channel, maskedNumber: $maskedNumber, label: $label, isDefault: $isDefault, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PaymentMethodResponseCopyWith<$Res>  {
  factory $PaymentMethodResponseCopyWith(PaymentMethodResponse value, $Res Function(PaymentMethodResponse) _then) = _$PaymentMethodResponseCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: PaymentChannel.card) PaymentChannel channel, String maskedNumber, String? label, bool isDefault, DateTime createdAt
});




}
/// @nodoc
class _$PaymentMethodResponseCopyWithImpl<$Res>
    implements $PaymentMethodResponseCopyWith<$Res> {
  _$PaymentMethodResponseCopyWithImpl(this._self, this._then);

  final PaymentMethodResponse _self;
  final $Res Function(PaymentMethodResponse) _then;

/// Create a copy of PaymentMethodResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? channel = null,Object? maskedNumber = null,Object? label = freezed,Object? isDefault = null,Object? createdAt = null,}) {
  return _then(PaymentMethodResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,maskedNumber: null == maskedNumber ? _self.maskedNumber : maskedNumber // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentMethodResponse].
extension PaymentMethodResponsePatterns on PaymentMethodResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentMethodResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentMethodResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentMethodResponse value)  $default,){
final _that = this;
switch (_that) {
case _PaymentMethodResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentMethodResponse value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentMethodResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: PaymentChannel.card)  PaymentChannel channel,  String maskedNumber,  String? label,  bool isDefault,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentMethodResponse() when $default != null:
return $default(_that.id,_that.channel,_that.maskedNumber,_that.label,_that.isDefault,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: PaymentChannel.card)  PaymentChannel channel,  String maskedNumber,  String? label,  bool isDefault,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _PaymentMethodResponse():
return $default(_that.id,_that.channel,_that.maskedNumber,_that.label,_that.isDefault,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(unknownEnumValue: PaymentChannel.card)  PaymentChannel channel,  String maskedNumber,  String? label,  bool isDefault,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PaymentMethodResponse() when $default != null:
return $default(_that.id,_that.channel,_that.maskedNumber,_that.label,_that.isDefault,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentMethodResponse implements PaymentMethodResponse {
  const _PaymentMethodResponse({required this.id, @JsonKey(unknownEnumValue: PaymentChannel.card) required this.channel, required this.maskedNumber, this.label, required this.isDefault, required this.createdAt});
  factory _PaymentMethodResponse.fromJson(Map<String, dynamic> json) => _$PaymentMethodResponseFromJson(json);

@override final  String id;
@override@JsonKey(unknownEnumValue: PaymentChannel.card) final  PaymentChannel channel;
/// "+23324•••4567".
@override final  String maskedNumber;
@override final  String? label;
@override final  bool isDefault;
@override final  DateTime createdAt;

/// Create a copy of PaymentMethodResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentMethodResponseCopyWith<_PaymentMethodResponse> get copyWith => __$PaymentMethodResponseCopyWithImpl<_PaymentMethodResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentMethodResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentMethodResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.maskedNumber, maskedNumber) || other.maskedNumber == maskedNumber)&&(identical(other.label, label) || other.label == label)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channel,maskedNumber,label,isDefault,createdAt);

@override
String toString() {
  return 'PaymentMethodResponse(id: $id, channel: $channel, maskedNumber: $maskedNumber, label: $label, isDefault: $isDefault, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PaymentMethodResponseCopyWith<$Res> implements $PaymentMethodResponseCopyWith<$Res> {
  factory _$PaymentMethodResponseCopyWith(_PaymentMethodResponse value, $Res Function(_PaymentMethodResponse) _then) = __$PaymentMethodResponseCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: PaymentChannel.card) PaymentChannel channel, String maskedNumber, String? label, bool isDefault, DateTime createdAt
});




}
/// @nodoc
class __$PaymentMethodResponseCopyWithImpl<$Res>
    implements _$PaymentMethodResponseCopyWith<$Res> {
  __$PaymentMethodResponseCopyWithImpl(this._self, this._then);

  final _PaymentMethodResponse _self;
  final $Res Function(_PaymentMethodResponse) _then;

/// Create a copy of PaymentMethodResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? channel = null,Object? maskedNumber = null,Object? label = freezed,Object? isDefault = null,Object? createdAt = null,}) {
  return _then(_PaymentMethodResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,maskedNumber: null == maskedNumber ? _self.maskedNumber : maskedNumber // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$PaymentMethodCreateRequest {

 PaymentChannel get channel; String get phoneNumber; String? get label; bool get isDefault;
/// Create a copy of PaymentMethodCreateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentMethodCreateRequestCopyWith<PaymentMethodCreateRequest> get copyWith => _$PaymentMethodCreateRequestCopyWithImpl<PaymentMethodCreateRequest>(this as PaymentMethodCreateRequest, _$identity);

  /// Serializes this PaymentMethodCreateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentMethodCreateRequest&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.label, label) || other.label == label)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,channel,phoneNumber,label,isDefault);

@override
String toString() {
  return 'PaymentMethodCreateRequest(channel: $channel, phoneNumber: $phoneNumber, label: $label, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $PaymentMethodCreateRequestCopyWith<$Res>  {
  factory $PaymentMethodCreateRequestCopyWith(PaymentMethodCreateRequest value, $Res Function(PaymentMethodCreateRequest) _then) = _$PaymentMethodCreateRequestCopyWithImpl;
@useResult
$Res call({
 PaymentChannel channel, String phoneNumber, String? label, bool isDefault
});




}
/// @nodoc
class _$PaymentMethodCreateRequestCopyWithImpl<$Res>
    implements $PaymentMethodCreateRequestCopyWith<$Res> {
  _$PaymentMethodCreateRequestCopyWithImpl(this._self, this._then);

  final PaymentMethodCreateRequest _self;
  final $Res Function(PaymentMethodCreateRequest) _then;

/// Create a copy of PaymentMethodCreateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channel = null,Object? phoneNumber = null,Object? label = freezed,Object? isDefault = null,}) {
  return _then(PaymentMethodCreateRequest(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentMethodCreateRequest].
extension PaymentMethodCreateRequestPatterns on PaymentMethodCreateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentMethodCreateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentMethodCreateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentMethodCreateRequest value)  $default,){
final _that = this;
switch (_that) {
case _PaymentMethodCreateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentMethodCreateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentMethodCreateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PaymentChannel channel,  String phoneNumber,  String? label,  bool isDefault)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentMethodCreateRequest() when $default != null:
return $default(_that.channel,_that.phoneNumber,_that.label,_that.isDefault);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PaymentChannel channel,  String phoneNumber,  String? label,  bool isDefault)  $default,) {final _that = this;
switch (_that) {
case _PaymentMethodCreateRequest():
return $default(_that.channel,_that.phoneNumber,_that.label,_that.isDefault);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PaymentChannel channel,  String phoneNumber,  String? label,  bool isDefault)?  $default,) {final _that = this;
switch (_that) {
case _PaymentMethodCreateRequest() when $default != null:
return $default(_that.channel,_that.phoneNumber,_that.label,_that.isDefault);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentMethodCreateRequest implements PaymentMethodCreateRequest {
  const _PaymentMethodCreateRequest({required this.channel, required this.phoneNumber, this.label, this.isDefault = false});
  factory _PaymentMethodCreateRequest.fromJson(Map<String, dynamic> json) => _$PaymentMethodCreateRequestFromJson(json);

@override final  PaymentChannel channel;
@override final  String phoneNumber;
@override final  String? label;
@override@JsonKey() final  bool isDefault;

/// Create a copy of PaymentMethodCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentMethodCreateRequestCopyWith<_PaymentMethodCreateRequest> get copyWith => __$PaymentMethodCreateRequestCopyWithImpl<_PaymentMethodCreateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentMethodCreateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentMethodCreateRequest&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.label, label) || other.label == label)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,channel,phoneNumber,label,isDefault);

@override
String toString() {
  return 'PaymentMethodCreateRequest(channel: $channel, phoneNumber: $phoneNumber, label: $label, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$PaymentMethodCreateRequestCopyWith<$Res> implements $PaymentMethodCreateRequestCopyWith<$Res> {
  factory _$PaymentMethodCreateRequestCopyWith(_PaymentMethodCreateRequest value, $Res Function(_PaymentMethodCreateRequest) _then) = __$PaymentMethodCreateRequestCopyWithImpl;
@override @useResult
$Res call({
 PaymentChannel channel, String phoneNumber, String? label, bool isDefault
});




}
/// @nodoc
class __$PaymentMethodCreateRequestCopyWithImpl<$Res>
    implements _$PaymentMethodCreateRequestCopyWith<$Res> {
  __$PaymentMethodCreateRequestCopyWithImpl(this._self, this._then);

  final _PaymentMethodCreateRequest _self;
  final $Res Function(_PaymentMethodCreateRequest) _then;

/// Create a copy of PaymentMethodCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channel = null,Object? phoneNumber = null,Object? label = freezed,Object? isDefault = null,}) {
  return _then(_PaymentMethodCreateRequest(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
