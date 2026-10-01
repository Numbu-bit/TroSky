// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RegisterRequest {

 String get phoneNumber; String? get email; String get password; String get fullName; RegistrableRole get role; String get preferredLanguage;
/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterRequestCopyWith<RegisterRequest> get copyWith => _$RegisterRequestCopyWithImpl<RegisterRequest>(this as RegisterRequest, _$identity);

  /// Serializes this RegisterRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterRequest&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.role, role) || other.role == role)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,phoneNumber,email,password,fullName,role,preferredLanguage);

@override
String toString() {
  return 'RegisterRequest(phoneNumber: $phoneNumber, email: $email, password: $password, fullName: $fullName, role: $role, preferredLanguage: $preferredLanguage)';
}


}

/// @nodoc
abstract mixin class $RegisterRequestCopyWith<$Res>  {
  factory $RegisterRequestCopyWith(RegisterRequest value, $Res Function(RegisterRequest) _then) = _$RegisterRequestCopyWithImpl;
@useResult
$Res call({
 String phoneNumber, String? email, String password, String fullName, RegistrableRole role, String preferredLanguage
});




}
/// @nodoc
class _$RegisterRequestCopyWithImpl<$Res>
    implements $RegisterRequestCopyWith<$Res> {
  _$RegisterRequestCopyWithImpl(this._self, this._then);

  final RegisterRequest _self;
  final $Res Function(RegisterRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phoneNumber = null,Object? email = freezed,Object? password = null,Object? fullName = null,Object? role = null,Object? preferredLanguage = null,}) {
  return _then(RegisterRequest(
phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as RegistrableRole,preferredLanguage: null == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RegisterRequest].
extension RegisterRequestPatterns on RegisterRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RegisterRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RegisterRequest value)  $default,){
final _that = this;
switch (_that) {
case _RegisterRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RegisterRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String phoneNumber,  String? email,  String password,  String fullName,  RegistrableRole role,  String preferredLanguage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
return $default(_that.phoneNumber,_that.email,_that.password,_that.fullName,_that.role,_that.preferredLanguage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String phoneNumber,  String? email,  String password,  String fullName,  RegistrableRole role,  String preferredLanguage)  $default,) {final _that = this;
switch (_that) {
case _RegisterRequest():
return $default(_that.phoneNumber,_that.email,_that.password,_that.fullName,_that.role,_that.preferredLanguage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String phoneNumber,  String? email,  String password,  String fullName,  RegistrableRole role,  String preferredLanguage)?  $default,) {final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
return $default(_that.phoneNumber,_that.email,_that.password,_that.fullName,_that.role,_that.preferredLanguage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RegisterRequest implements RegisterRequest {
  const _RegisterRequest({required this.phoneNumber, this.email, required this.password, required this.fullName, this.role = RegistrableRole.passenger, this.preferredLanguage = 'en'});
  factory _RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);

@override final  String phoneNumber;
@override final  String? email;
@override final  String password;
@override final  String fullName;
@override@JsonKey() final  RegistrableRole role;
@override@JsonKey() final  String preferredLanguage;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterRequestCopyWith<_RegisterRequest> get copyWith => __$RegisterRequestCopyWithImpl<_RegisterRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterRequest&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.role, role) || other.role == role)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,phoneNumber,email,password,fullName,role,preferredLanguage);

@override
String toString() {
  return 'RegisterRequest(phoneNumber: $phoneNumber, email: $email, password: $password, fullName: $fullName, role: $role, preferredLanguage: $preferredLanguage)';
}


}

/// @nodoc
abstract mixin class _$RegisterRequestCopyWith<$Res> implements $RegisterRequestCopyWith<$Res> {
  factory _$RegisterRequestCopyWith(_RegisterRequest value, $Res Function(_RegisterRequest) _then) = __$RegisterRequestCopyWithImpl;
@override @useResult
$Res call({
 String phoneNumber, String? email, String password, String fullName, RegistrableRole role, String preferredLanguage
});




}
/// @nodoc
class __$RegisterRequestCopyWithImpl<$Res>
    implements _$RegisterRequestCopyWith<$Res> {
  __$RegisterRequestCopyWithImpl(this._self, this._then);

  final _RegisterRequest _self;
  final $Res Function(_RegisterRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phoneNumber = null,Object? email = freezed,Object? password = null,Object? fullName = null,Object? role = null,Object? preferredLanguage = null,}) {
  return _then(_RegisterRequest(
phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as RegistrableRole,preferredLanguage: null == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RegisterResponse {

 String get userId; String get phoneNumber; String get otpSentTo; String get message;
/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterResponseCopyWith<RegisterResponse> get copyWith => _$RegisterResponseCopyWithImpl<RegisterResponse>(this as RegisterResponse, _$identity);

  /// Serializes this RegisterResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterResponse&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.otpSentTo, otpSentTo) || other.otpSentTo == otpSentTo)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,phoneNumber,otpSentTo,message);

@override
String toString() {
  return 'RegisterResponse(userId: $userId, phoneNumber: $phoneNumber, otpSentTo: $otpSentTo, message: $message)';
}


}

/// @nodoc
abstract mixin class $RegisterResponseCopyWith<$Res>  {
  factory $RegisterResponseCopyWith(RegisterResponse value, $Res Function(RegisterResponse) _then) = _$RegisterResponseCopyWithImpl;
@useResult
$Res call({
 String userId, String phoneNumber, String otpSentTo, String message
});




}
/// @nodoc
class _$RegisterResponseCopyWithImpl<$Res>
    implements $RegisterResponseCopyWith<$Res> {
  _$RegisterResponseCopyWithImpl(this._self, this._then);

  final RegisterResponse _self;
  final $Res Function(RegisterResponse) _then;

/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? phoneNumber = null,Object? otpSentTo = null,Object? message = null,}) {
  return _then(RegisterResponse(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,otpSentTo: null == otpSentTo ? _self.otpSentTo : otpSentTo // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RegisterResponse].
extension RegisterResponsePatterns on RegisterResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RegisterResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RegisterResponse value)  $default,){
final _that = this;
switch (_that) {
case _RegisterResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RegisterResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String phoneNumber,  String otpSentTo,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
return $default(_that.userId,_that.phoneNumber,_that.otpSentTo,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String phoneNumber,  String otpSentTo,  String message)  $default,) {final _that = this;
switch (_that) {
case _RegisterResponse():
return $default(_that.userId,_that.phoneNumber,_that.otpSentTo,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String phoneNumber,  String otpSentTo,  String message)?  $default,) {final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
return $default(_that.userId,_that.phoneNumber,_that.otpSentTo,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RegisterResponse implements RegisterResponse {
  const _RegisterResponse({required this.userId, required this.phoneNumber, required this.otpSentTo, required this.message});
  factory _RegisterResponse.fromJson(Map<String, dynamic> json) => _$RegisterResponseFromJson(json);

@override final  String userId;
@override final  String phoneNumber;
@override final  String otpSentTo;
@override final  String message;

/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterResponseCopyWith<_RegisterResponse> get copyWith => __$RegisterResponseCopyWithImpl<_RegisterResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterResponse&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.otpSentTo, otpSentTo) || other.otpSentTo == otpSentTo)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,phoneNumber,otpSentTo,message);

@override
String toString() {
  return 'RegisterResponse(userId: $userId, phoneNumber: $phoneNumber, otpSentTo: $otpSentTo, message: $message)';
}


}

/// @nodoc
abstract mixin class _$RegisterResponseCopyWith<$Res> implements $RegisterResponseCopyWith<$Res> {
  factory _$RegisterResponseCopyWith(_RegisterResponse value, $Res Function(_RegisterResponse) _then) = __$RegisterResponseCopyWithImpl;
@override @useResult
$Res call({
 String userId, String phoneNumber, String otpSentTo, String message
});




}
/// @nodoc
class __$RegisterResponseCopyWithImpl<$Res>
    implements _$RegisterResponseCopyWith<$Res> {
  __$RegisterResponseCopyWithImpl(this._self, this._then);

  final _RegisterResponse _self;
  final $Res Function(_RegisterResponse) _then;

/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? phoneNumber = null,Object? otpSentTo = null,Object? message = null,}) {
  return _then(_RegisterResponse(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,otpSentTo: null == otpSentTo ? _self.otpSentTo : otpSentTo // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VerifyOtpRequest {

 String get target; OtpPurpose get purpose; String get code;
/// Create a copy of VerifyOtpRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerifyOtpRequestCopyWith<VerifyOtpRequest> get copyWith => _$VerifyOtpRequestCopyWithImpl<VerifyOtpRequest>(this as VerifyOtpRequest, _$identity);

  /// Serializes this VerifyOtpRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerifyOtpRequest&&(identical(other.target, target) || other.target == target)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,purpose,code);

@override
String toString() {
  return 'VerifyOtpRequest(target: $target, purpose: $purpose, code: $code)';
}


}

/// @nodoc
abstract mixin class $VerifyOtpRequestCopyWith<$Res>  {
  factory $VerifyOtpRequestCopyWith(VerifyOtpRequest value, $Res Function(VerifyOtpRequest) _then) = _$VerifyOtpRequestCopyWithImpl;
@useResult
$Res call({
 String target, OtpPurpose purpose, String code
});




}
/// @nodoc
class _$VerifyOtpRequestCopyWithImpl<$Res>
    implements $VerifyOtpRequestCopyWith<$Res> {
  _$VerifyOtpRequestCopyWithImpl(this._self, this._then);

  final VerifyOtpRequest _self;
  final $Res Function(VerifyOtpRequest) _then;

/// Create a copy of VerifyOtpRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? purpose = null,Object? code = null,}) {
  return _then(VerifyOtpRequest(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as OtpPurpose,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VerifyOtpRequest].
extension VerifyOtpRequestPatterns on VerifyOtpRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerifyOtpRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerifyOtpRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerifyOtpRequest value)  $default,){
final _that = this;
switch (_that) {
case _VerifyOtpRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerifyOtpRequest value)?  $default,){
final _that = this;
switch (_that) {
case _VerifyOtpRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  OtpPurpose purpose,  String code)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerifyOtpRequest() when $default != null:
return $default(_that.target,_that.purpose,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  OtpPurpose purpose,  String code)  $default,) {final _that = this;
switch (_that) {
case _VerifyOtpRequest():
return $default(_that.target,_that.purpose,_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  OtpPurpose purpose,  String code)?  $default,) {final _that = this;
switch (_that) {
case _VerifyOtpRequest() when $default != null:
return $default(_that.target,_that.purpose,_that.code);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VerifyOtpRequest implements VerifyOtpRequest {
  const _VerifyOtpRequest({required this.target, required this.purpose, required this.code});
  factory _VerifyOtpRequest.fromJson(Map<String, dynamic> json) => _$VerifyOtpRequestFromJson(json);

@override final  String target;
@override final  OtpPurpose purpose;
@override final  String code;

/// Create a copy of VerifyOtpRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyOtpRequestCopyWith<_VerifyOtpRequest> get copyWith => __$VerifyOtpRequestCopyWithImpl<_VerifyOtpRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerifyOtpRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyOtpRequest&&(identical(other.target, target) || other.target == target)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,purpose,code);

@override
String toString() {
  return 'VerifyOtpRequest(target: $target, purpose: $purpose, code: $code)';
}


}

/// @nodoc
abstract mixin class _$VerifyOtpRequestCopyWith<$Res> implements $VerifyOtpRequestCopyWith<$Res> {
  factory _$VerifyOtpRequestCopyWith(_VerifyOtpRequest value, $Res Function(_VerifyOtpRequest) _then) = __$VerifyOtpRequestCopyWithImpl;
@override @useResult
$Res call({
 String target, OtpPurpose purpose, String code
});




}
/// @nodoc
class __$VerifyOtpRequestCopyWithImpl<$Res>
    implements _$VerifyOtpRequestCopyWith<$Res> {
  __$VerifyOtpRequestCopyWithImpl(this._self, this._then);

  final _VerifyOtpRequest _self;
  final $Res Function(_VerifyOtpRequest) _then;

/// Create a copy of VerifyOtpRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? purpose = null,Object? code = null,}) {
  return _then(_VerifyOtpRequest(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as OtpPurpose,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ResendOtpRequest {

 String get target; OtpPurpose get purpose; OtpChannel get channel;
/// Create a copy of ResendOtpRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResendOtpRequestCopyWith<ResendOtpRequest> get copyWith => _$ResendOtpRequestCopyWithImpl<ResendOtpRequest>(this as ResendOtpRequest, _$identity);

  /// Serializes this ResendOtpRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResendOtpRequest&&(identical(other.target, target) || other.target == target)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.channel, channel) || other.channel == channel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,purpose,channel);

@override
String toString() {
  return 'ResendOtpRequest(target: $target, purpose: $purpose, channel: $channel)';
}


}

/// @nodoc
abstract mixin class $ResendOtpRequestCopyWith<$Res>  {
  factory $ResendOtpRequestCopyWith(ResendOtpRequest value, $Res Function(ResendOtpRequest) _then) = _$ResendOtpRequestCopyWithImpl;
@useResult
$Res call({
 String target, OtpPurpose purpose, OtpChannel channel
});




}
/// @nodoc
class _$ResendOtpRequestCopyWithImpl<$Res>
    implements $ResendOtpRequestCopyWith<$Res> {
  _$ResendOtpRequestCopyWithImpl(this._self, this._then);

  final ResendOtpRequest _self;
  final $Res Function(ResendOtpRequest) _then;

/// Create a copy of ResendOtpRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? purpose = null,Object? channel = null,}) {
  return _then(ResendOtpRequest(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as OtpPurpose,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as OtpChannel,
  ));
}

}


/// Adds pattern-matching-related methods to [ResendOtpRequest].
extension ResendOtpRequestPatterns on ResendOtpRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResendOtpRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResendOtpRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResendOtpRequest value)  $default,){
final _that = this;
switch (_that) {
case _ResendOtpRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResendOtpRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ResendOtpRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  OtpPurpose purpose,  OtpChannel channel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResendOtpRequest() when $default != null:
return $default(_that.target,_that.purpose,_that.channel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  OtpPurpose purpose,  OtpChannel channel)  $default,) {final _that = this;
switch (_that) {
case _ResendOtpRequest():
return $default(_that.target,_that.purpose,_that.channel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  OtpPurpose purpose,  OtpChannel channel)?  $default,) {final _that = this;
switch (_that) {
case _ResendOtpRequest() when $default != null:
return $default(_that.target,_that.purpose,_that.channel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResendOtpRequest implements ResendOtpRequest {
  const _ResendOtpRequest({required this.target, required this.purpose, this.channel = OtpChannel.sms});
  factory _ResendOtpRequest.fromJson(Map<String, dynamic> json) => _$ResendOtpRequestFromJson(json);

@override final  String target;
@override final  OtpPurpose purpose;
@override@JsonKey() final  OtpChannel channel;

/// Create a copy of ResendOtpRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResendOtpRequestCopyWith<_ResendOtpRequest> get copyWith => __$ResendOtpRequestCopyWithImpl<_ResendOtpRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResendOtpRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResendOtpRequest&&(identical(other.target, target) || other.target == target)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.channel, channel) || other.channel == channel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,purpose,channel);

@override
String toString() {
  return 'ResendOtpRequest(target: $target, purpose: $purpose, channel: $channel)';
}


}

/// @nodoc
abstract mixin class _$ResendOtpRequestCopyWith<$Res> implements $ResendOtpRequestCopyWith<$Res> {
  factory _$ResendOtpRequestCopyWith(_ResendOtpRequest value, $Res Function(_ResendOtpRequest) _then) = __$ResendOtpRequestCopyWithImpl;
@override @useResult
$Res call({
 String target, OtpPurpose purpose, OtpChannel channel
});




}
/// @nodoc
class __$ResendOtpRequestCopyWithImpl<$Res>
    implements _$ResendOtpRequestCopyWith<$Res> {
  __$ResendOtpRequestCopyWithImpl(this._self, this._then);

  final _ResendOtpRequest _self;
  final $Res Function(_ResendOtpRequest) _then;

/// Create a copy of ResendOtpRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? purpose = null,Object? channel = null,}) {
  return _then(_ResendOtpRequest(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as OtpPurpose,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as OtpChannel,
  ));
}


}


/// @nodoc
mixin _$DeviceContext {

 String? get deviceId; String? get deviceName; DevicePlatform? get platform; String? get pushToken;
/// Create a copy of DeviceContext
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceContextCopyWith<DeviceContext> get copyWith => _$DeviceContextCopyWithImpl<DeviceContext>(this as DeviceContext, _$identity);

  /// Serializes this DeviceContext to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceContext&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.pushToken, pushToken) || other.pushToken == pushToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,deviceName,platform,pushToken);

@override
String toString() {
  return 'DeviceContext(deviceId: $deviceId, deviceName: $deviceName, platform: $platform, pushToken: $pushToken)';
}


}

/// @nodoc
abstract mixin class $DeviceContextCopyWith<$Res>  {
  factory $DeviceContextCopyWith(DeviceContext value, $Res Function(DeviceContext) _then) = _$DeviceContextCopyWithImpl;
@useResult
$Res call({
 String? deviceId, String? deviceName, DevicePlatform? platform, String? pushToken
});




}
/// @nodoc
class _$DeviceContextCopyWithImpl<$Res>
    implements $DeviceContextCopyWith<$Res> {
  _$DeviceContextCopyWithImpl(this._self, this._then);

  final DeviceContext _self;
  final $Res Function(DeviceContext) _then;

/// Create a copy of DeviceContext
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = freezed,Object? deviceName = freezed,Object? platform = freezed,Object? pushToken = freezed,}) {
  return _then(DeviceContext(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceContext].
extension DeviceContextPatterns on DeviceContext {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceContext value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceContext() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceContext value)  $default,){
final _that = this;
switch (_that) {
case _DeviceContext():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceContext value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceContext() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? deviceId,  String? deviceName,  DevicePlatform? platform,  String? pushToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceContext() when $default != null:
return $default(_that.deviceId,_that.deviceName,_that.platform,_that.pushToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? deviceId,  String? deviceName,  DevicePlatform? platform,  String? pushToken)  $default,) {final _that = this;
switch (_that) {
case _DeviceContext():
return $default(_that.deviceId,_that.deviceName,_that.platform,_that.pushToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? deviceId,  String? deviceName,  DevicePlatform? platform,  String? pushToken)?  $default,) {final _that = this;
switch (_that) {
case _DeviceContext() when $default != null:
return $default(_that.deviceId,_that.deviceName,_that.platform,_that.pushToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceContext implements DeviceContext {
  const _DeviceContext({this.deviceId, this.deviceName, this.platform, this.pushToken});
  factory _DeviceContext.fromJson(Map<String, dynamic> json) => _$DeviceContextFromJson(json);

@override final  String? deviceId;
@override final  String? deviceName;
@override final  DevicePlatform? platform;
@override final  String? pushToken;

/// Create a copy of DeviceContext
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceContextCopyWith<_DeviceContext> get copyWith => __$DeviceContextCopyWithImpl<_DeviceContext>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceContextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceContext&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.pushToken, pushToken) || other.pushToken == pushToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,deviceName,platform,pushToken);

@override
String toString() {
  return 'DeviceContext(deviceId: $deviceId, deviceName: $deviceName, platform: $platform, pushToken: $pushToken)';
}


}

/// @nodoc
abstract mixin class _$DeviceContextCopyWith<$Res> implements $DeviceContextCopyWith<$Res> {
  factory _$DeviceContextCopyWith(_DeviceContext value, $Res Function(_DeviceContext) _then) = __$DeviceContextCopyWithImpl;
@override @useResult
$Res call({
 String? deviceId, String? deviceName, DevicePlatform? platform, String? pushToken
});




}
/// @nodoc
class __$DeviceContextCopyWithImpl<$Res>
    implements _$DeviceContextCopyWith<$Res> {
  __$DeviceContextCopyWithImpl(this._self, this._then);

  final _DeviceContext _self;
  final $Res Function(_DeviceContext) _then;

/// Create a copy of DeviceContext
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = freezed,Object? deviceName = freezed,Object? platform = freezed,Object? pushToken = freezed,}) {
  return _then(_DeviceContext(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LoginRequest {

 String get identifier; String get password; DeviceContext? get device;
/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginRequestCopyWith<LoginRequest> get copyWith => _$LoginRequestCopyWithImpl<LoginRequest>(this as LoginRequest, _$identity);

  /// Serializes this LoginRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginRequest&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.password, password) || other.password == password)&&(identical(other.device, device) || other.device == device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,identifier,password,device);

@override
String toString() {
  return 'LoginRequest(identifier: $identifier, password: $password, device: $device)';
}


}

/// @nodoc
abstract mixin class $LoginRequestCopyWith<$Res>  {
  factory $LoginRequestCopyWith(LoginRequest value, $Res Function(LoginRequest) _then) = _$LoginRequestCopyWithImpl;
@useResult
$Res call({
 String identifier, String password, DeviceContext? device
});


$DeviceContextCopyWith<$Res>? get device;

}
/// @nodoc
class _$LoginRequestCopyWithImpl<$Res>
    implements $LoginRequestCopyWith<$Res> {
  _$LoginRequestCopyWithImpl(this._self, this._then);

  final LoginRequest _self;
  final $Res Function(LoginRequest) _then;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? identifier = null,Object? password = null,Object? device = freezed,}) {
  return _then(LoginRequest(
identifier: null == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as DeviceContext?,
  ));
}
/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceContextCopyWith<$Res>? get device {
    if (_self.device == null) {
    return null;
  }

  return $DeviceContextCopyWith<$Res>(_self.device!, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// Adds pattern-matching-related methods to [LoginRequest].
extension LoginRequestPatterns on LoginRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginRequest value)  $default,){
final _that = this;
switch (_that) {
case _LoginRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String identifier,  String password,  DeviceContext? device)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
return $default(_that.identifier,_that.password,_that.device);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String identifier,  String password,  DeviceContext? device)  $default,) {final _that = this;
switch (_that) {
case _LoginRequest():
return $default(_that.identifier,_that.password,_that.device);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String identifier,  String password,  DeviceContext? device)?  $default,) {final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
return $default(_that.identifier,_that.password,_that.device);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginRequest implements LoginRequest {
  const _LoginRequest({required this.identifier, required this.password, this.device});
  factory _LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);

@override final  String identifier;
@override final  String password;
@override final  DeviceContext? device;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginRequestCopyWith<_LoginRequest> get copyWith => __$LoginRequestCopyWithImpl<_LoginRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginRequest&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.password, password) || other.password == password)&&(identical(other.device, device) || other.device == device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,identifier,password,device);

@override
String toString() {
  return 'LoginRequest(identifier: $identifier, password: $password, device: $device)';
}


}

/// @nodoc
abstract mixin class _$LoginRequestCopyWith<$Res> implements $LoginRequestCopyWith<$Res> {
  factory _$LoginRequestCopyWith(_LoginRequest value, $Res Function(_LoginRequest) _then) = __$LoginRequestCopyWithImpl;
@override @useResult
$Res call({
 String identifier, String password, DeviceContext? device
});


@override $DeviceContextCopyWith<$Res>? get device;

}
/// @nodoc
class __$LoginRequestCopyWithImpl<$Res>
    implements _$LoginRequestCopyWith<$Res> {
  __$LoginRequestCopyWithImpl(this._self, this._then);

  final _LoginRequest _self;
  final $Res Function(_LoginRequest) _then;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? identifier = null,Object? password = null,Object? device = freezed,}) {
  return _then(_LoginRequest(
identifier: null == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as DeviceContext?,
  ));
}

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceContextCopyWith<$Res>? get device {
    if (_self.device == null) {
    return null;
  }

  return $DeviceContextCopyWith<$Res>(_self.device!, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// @nodoc
mixin _$OtpLoginRequest {

 String get target; String get code; DeviceContext? get device;
/// Create a copy of OtpLoginRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OtpLoginRequestCopyWith<OtpLoginRequest> get copyWith => _$OtpLoginRequestCopyWithImpl<OtpLoginRequest>(this as OtpLoginRequest, _$identity);

  /// Serializes this OtpLoginRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OtpLoginRequest&&(identical(other.target, target) || other.target == target)&&(identical(other.code, code) || other.code == code)&&(identical(other.device, device) || other.device == device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,code,device);

@override
String toString() {
  return 'OtpLoginRequest(target: $target, code: $code, device: $device)';
}


}

/// @nodoc
abstract mixin class $OtpLoginRequestCopyWith<$Res>  {
  factory $OtpLoginRequestCopyWith(OtpLoginRequest value, $Res Function(OtpLoginRequest) _then) = _$OtpLoginRequestCopyWithImpl;
@useResult
$Res call({
 String target, String code, DeviceContext? device
});


$DeviceContextCopyWith<$Res>? get device;

}
/// @nodoc
class _$OtpLoginRequestCopyWithImpl<$Res>
    implements $OtpLoginRequestCopyWith<$Res> {
  _$OtpLoginRequestCopyWithImpl(this._self, this._then);

  final OtpLoginRequest _self;
  final $Res Function(OtpLoginRequest) _then;

/// Create a copy of OtpLoginRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? code = null,Object? device = freezed,}) {
  return _then(OtpLoginRequest(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as DeviceContext?,
  ));
}
/// Create a copy of OtpLoginRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceContextCopyWith<$Res>? get device {
    if (_self.device == null) {
    return null;
  }

  return $DeviceContextCopyWith<$Res>(_self.device!, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// Adds pattern-matching-related methods to [OtpLoginRequest].
extension OtpLoginRequestPatterns on OtpLoginRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OtpLoginRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OtpLoginRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OtpLoginRequest value)  $default,){
final _that = this;
switch (_that) {
case _OtpLoginRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OtpLoginRequest value)?  $default,){
final _that = this;
switch (_that) {
case _OtpLoginRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  String code,  DeviceContext? device)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OtpLoginRequest() when $default != null:
return $default(_that.target,_that.code,_that.device);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  String code,  DeviceContext? device)  $default,) {final _that = this;
switch (_that) {
case _OtpLoginRequest():
return $default(_that.target,_that.code,_that.device);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  String code,  DeviceContext? device)?  $default,) {final _that = this;
switch (_that) {
case _OtpLoginRequest() when $default != null:
return $default(_that.target,_that.code,_that.device);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OtpLoginRequest implements OtpLoginRequest {
  const _OtpLoginRequest({required this.target, required this.code, this.device});
  factory _OtpLoginRequest.fromJson(Map<String, dynamic> json) => _$OtpLoginRequestFromJson(json);

@override final  String target;
@override final  String code;
@override final  DeviceContext? device;

/// Create a copy of OtpLoginRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OtpLoginRequestCopyWith<_OtpLoginRequest> get copyWith => __$OtpLoginRequestCopyWithImpl<_OtpLoginRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OtpLoginRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OtpLoginRequest&&(identical(other.target, target) || other.target == target)&&(identical(other.code, code) || other.code == code)&&(identical(other.device, device) || other.device == device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,code,device);

@override
String toString() {
  return 'OtpLoginRequest(target: $target, code: $code, device: $device)';
}


}

/// @nodoc
abstract mixin class _$OtpLoginRequestCopyWith<$Res> implements $OtpLoginRequestCopyWith<$Res> {
  factory _$OtpLoginRequestCopyWith(_OtpLoginRequest value, $Res Function(_OtpLoginRequest) _then) = __$OtpLoginRequestCopyWithImpl;
@override @useResult
$Res call({
 String target, String code, DeviceContext? device
});


@override $DeviceContextCopyWith<$Res>? get device;

}
/// @nodoc
class __$OtpLoginRequestCopyWithImpl<$Res>
    implements _$OtpLoginRequestCopyWith<$Res> {
  __$OtpLoginRequestCopyWithImpl(this._self, this._then);

  final _OtpLoginRequest _self;
  final $Res Function(_OtpLoginRequest) _then;

/// Create a copy of OtpLoginRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? code = null,Object? device = freezed,}) {
  return _then(_OtpLoginRequest(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as DeviceContext?,
  ));
}

/// Create a copy of OtpLoginRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceContextCopyWith<$Res>? get device {
    if (_self.device == null) {
    return null;
  }

  return $DeviceContextCopyWith<$Res>(_self.device!, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// @nodoc
mixin _$RefreshRequest {

 String get refreshToken;
/// Create a copy of RefreshRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefreshRequestCopyWith<RefreshRequest> get copyWith => _$RefreshRequestCopyWithImpl<RefreshRequest>(this as RefreshRequest, _$identity);

  /// Serializes this RefreshRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefreshRequest&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,refreshToken);

@override
String toString() {
  return 'RefreshRequest(refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class $RefreshRequestCopyWith<$Res>  {
  factory $RefreshRequestCopyWith(RefreshRequest value, $Res Function(RefreshRequest) _then) = _$RefreshRequestCopyWithImpl;
@useResult
$Res call({
 String refreshToken
});




}
/// @nodoc
class _$RefreshRequestCopyWithImpl<$Res>
    implements $RefreshRequestCopyWith<$Res> {
  _$RefreshRequestCopyWithImpl(this._self, this._then);

  final RefreshRequest _self;
  final $Res Function(RefreshRequest) _then;

/// Create a copy of RefreshRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? refreshToken = null,}) {
  return _then(RefreshRequest(
refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RefreshRequest].
extension RefreshRequestPatterns on RefreshRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefreshRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefreshRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefreshRequest value)  $default,){
final _that = this;
switch (_that) {
case _RefreshRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefreshRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RefreshRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String refreshToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefreshRequest() when $default != null:
return $default(_that.refreshToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String refreshToken)  $default,) {final _that = this;
switch (_that) {
case _RefreshRequest():
return $default(_that.refreshToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String refreshToken)?  $default,) {final _that = this;
switch (_that) {
case _RefreshRequest() when $default != null:
return $default(_that.refreshToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefreshRequest implements RefreshRequest {
  const _RefreshRequest({required this.refreshToken});
  factory _RefreshRequest.fromJson(Map<String, dynamic> json) => _$RefreshRequestFromJson(json);

@override final  String refreshToken;

/// Create a copy of RefreshRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefreshRequestCopyWith<_RefreshRequest> get copyWith => __$RefreshRequestCopyWithImpl<_RefreshRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefreshRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequest&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,refreshToken);

@override
String toString() {
  return 'RefreshRequest(refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$RefreshRequestCopyWith<$Res> implements $RefreshRequestCopyWith<$Res> {
  factory _$RefreshRequestCopyWith(_RefreshRequest value, $Res Function(_RefreshRequest) _then) = __$RefreshRequestCopyWithImpl;
@override @useResult
$Res call({
 String refreshToken
});




}
/// @nodoc
class __$RefreshRequestCopyWithImpl<$Res>
    implements _$RefreshRequestCopyWith<$Res> {
  __$RefreshRequestCopyWithImpl(this._self, this._then);

  final _RefreshRequest _self;
  final $Res Function(_RefreshRequest) _then;

/// Create a copy of RefreshRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? refreshToken = null,}) {
  return _then(_RefreshRequest(
refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TokenPairResponse {

 String get accessToken; String get refreshToken; String get tokenType; int get expiresIn; String get sessionId;
/// Create a copy of TokenPairResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenPairResponseCopyWith<TokenPairResponse> get copyWith => _$TokenPairResponseCopyWithImpl<TokenPairResponse>(this as TokenPairResponse, _$identity);

  /// Serializes this TokenPairResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenPairResponse&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.tokenType, tokenType) || other.tokenType == tokenType)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,tokenType,expiresIn,sessionId);

@override
String toString() {
  return 'TokenPairResponse(accessToken: $accessToken, refreshToken: $refreshToken, tokenType: $tokenType, expiresIn: $expiresIn, sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $TokenPairResponseCopyWith<$Res>  {
  factory $TokenPairResponseCopyWith(TokenPairResponse value, $Res Function(TokenPairResponse) _then) = _$TokenPairResponseCopyWithImpl;
@useResult
$Res call({
 String accessToken, String refreshToken, String tokenType, int expiresIn, String sessionId
});




}
/// @nodoc
class _$TokenPairResponseCopyWithImpl<$Res>
    implements $TokenPairResponseCopyWith<$Res> {
  _$TokenPairResponseCopyWithImpl(this._self, this._then);

  final TokenPairResponse _self;
  final $Res Function(TokenPairResponse) _then;

/// Create a copy of TokenPairResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? refreshToken = null,Object? tokenType = null,Object? expiresIn = null,Object? sessionId = null,}) {
  return _then(TokenPairResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TokenPairResponse].
extension TokenPairResponsePatterns on TokenPairResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TokenPairResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TokenPairResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TokenPairResponse value)  $default,){
final _that = this;
switch (_that) {
case _TokenPairResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TokenPairResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TokenPairResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken,  String tokenType,  int expiresIn,  String sessionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TokenPairResponse() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.tokenType,_that.expiresIn,_that.sessionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken,  String tokenType,  int expiresIn,  String sessionId)  $default,) {final _that = this;
switch (_that) {
case _TokenPairResponse():
return $default(_that.accessToken,_that.refreshToken,_that.tokenType,_that.expiresIn,_that.sessionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accessToken,  String refreshToken,  String tokenType,  int expiresIn,  String sessionId)?  $default,) {final _that = this;
switch (_that) {
case _TokenPairResponse() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.tokenType,_that.expiresIn,_that.sessionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TokenPairResponse implements TokenPairResponse {
  const _TokenPairResponse({required this.accessToken, required this.refreshToken, this.tokenType = 'bearer', required this.expiresIn, required this.sessionId});
  factory _TokenPairResponse.fromJson(Map<String, dynamic> json) => _$TokenPairResponseFromJson(json);

@override final  String accessToken;
@override final  String refreshToken;
@override@JsonKey() final  String tokenType;
@override final  int expiresIn;
@override final  String sessionId;

/// Create a copy of TokenPairResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenPairResponseCopyWith<_TokenPairResponse> get copyWith => __$TokenPairResponseCopyWithImpl<_TokenPairResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenPairResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenPairResponse&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.tokenType, tokenType) || other.tokenType == tokenType)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,tokenType,expiresIn,sessionId);

@override
String toString() {
  return 'TokenPairResponse(accessToken: $accessToken, refreshToken: $refreshToken, tokenType: $tokenType, expiresIn: $expiresIn, sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$TokenPairResponseCopyWith<$Res> implements $TokenPairResponseCopyWith<$Res> {
  factory _$TokenPairResponseCopyWith(_TokenPairResponse value, $Res Function(_TokenPairResponse) _then) = __$TokenPairResponseCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, String refreshToken, String tokenType, int expiresIn, String sessionId
});




}
/// @nodoc
class __$TokenPairResponseCopyWithImpl<$Res>
    implements _$TokenPairResponseCopyWith<$Res> {
  __$TokenPairResponseCopyWithImpl(this._self, this._then);

  final _TokenPairResponse _self;
  final $Res Function(_TokenPairResponse) _then;

/// Create a copy of TokenPairResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,Object? tokenType = null,Object? expiresIn = null,Object? sessionId = null,}) {
  return _then(_TokenPairResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MessageResponse {

 String get message;
/// Create a copy of MessageResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageResponseCopyWith<MessageResponse> get copyWith => _$MessageResponseCopyWithImpl<MessageResponse>(this as MessageResponse, _$identity);

  /// Serializes this MessageResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageResponse&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'MessageResponse(message: $message)';
}


}

/// @nodoc
abstract mixin class $MessageResponseCopyWith<$Res>  {
  factory $MessageResponseCopyWith(MessageResponse value, $Res Function(MessageResponse) _then) = _$MessageResponseCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$MessageResponseCopyWithImpl<$Res>
    implements $MessageResponseCopyWith<$Res> {
  _$MessageResponseCopyWithImpl(this._self, this._then);

  final MessageResponse _self;
  final $Res Function(MessageResponse) _then;

/// Create a copy of MessageResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,}) {
  return _then(MessageResponse(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageResponse].
extension MessageResponsePatterns on MessageResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageResponse value)  $default,){
final _that = this;
switch (_that) {
case _MessageResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MessageResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageResponse() when $default != null:
return $default(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message)  $default,) {final _that = this;
switch (_that) {
case _MessageResponse():
return $default(_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message)?  $default,) {final _that = this;
switch (_that) {
case _MessageResponse() when $default != null:
return $default(_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageResponse implements MessageResponse {
  const _MessageResponse({required this.message});
  factory _MessageResponse.fromJson(Map<String, dynamic> json) => _$MessageResponseFromJson(json);

@override final  String message;

/// Create a copy of MessageResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageResponseCopyWith<_MessageResponse> get copyWith => __$MessageResponseCopyWithImpl<_MessageResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageResponse&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'MessageResponse(message: $message)';
}


}

/// @nodoc
abstract mixin class _$MessageResponseCopyWith<$Res> implements $MessageResponseCopyWith<$Res> {
  factory _$MessageResponseCopyWith(_MessageResponse value, $Res Function(_MessageResponse) _then) = __$MessageResponseCopyWithImpl;
@override @useResult
$Res call({
 String message
});




}
/// @nodoc
class __$MessageResponseCopyWithImpl<$Res>
    implements _$MessageResponseCopyWith<$Res> {
  __$MessageResponseCopyWithImpl(this._self, this._then);

  final _MessageResponse _self;
  final $Res Function(_MessageResponse) _then;

/// Create a copy of MessageResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_MessageResponse(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
