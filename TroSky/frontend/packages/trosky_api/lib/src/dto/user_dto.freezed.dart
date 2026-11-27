// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserProfileResponse {

 String get fullName; DateTime? get dateOfBirth; String? get gender; String get preferredLanguage; String? get avatarUrl; String? get ghanaCardNumber; bool get ghanaCardVerified;
/// Create a copy of UserProfileResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileResponseCopyWith<UserProfileResponse> get copyWith => _$UserProfileResponseCopyWithImpl<UserProfileResponse>(this as UserProfileResponse, _$identity);

  /// Serializes this UserProfileResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfileResponse&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.ghanaCardNumber, ghanaCardNumber) || other.ghanaCardNumber == ghanaCardNumber)&&(identical(other.ghanaCardVerified, ghanaCardVerified) || other.ghanaCardVerified == ghanaCardVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,dateOfBirth,gender,preferredLanguage,avatarUrl,ghanaCardNumber,ghanaCardVerified);

@override
String toString() {
  return 'UserProfileResponse(fullName: $fullName, dateOfBirth: $dateOfBirth, gender: $gender, preferredLanguage: $preferredLanguage, avatarUrl: $avatarUrl, ghanaCardNumber: $ghanaCardNumber, ghanaCardVerified: $ghanaCardVerified)';
}


}

/// @nodoc
abstract mixin class $UserProfileResponseCopyWith<$Res>  {
  factory $UserProfileResponseCopyWith(UserProfileResponse value, $Res Function(UserProfileResponse) _then) = _$UserProfileResponseCopyWithImpl;
@useResult
$Res call({
 String fullName, DateTime? dateOfBirth, String? gender, String preferredLanguage, String? avatarUrl, String? ghanaCardNumber, bool ghanaCardVerified
});




}
/// @nodoc
class _$UserProfileResponseCopyWithImpl<$Res>
    implements $UserProfileResponseCopyWith<$Res> {
  _$UserProfileResponseCopyWithImpl(this._self, this._then);

  final UserProfileResponse _self;
  final $Res Function(UserProfileResponse) _then;

/// Create a copy of UserProfileResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fullName = null,Object? dateOfBirth = freezed,Object? gender = freezed,Object? preferredLanguage = null,Object? avatarUrl = freezed,Object? ghanaCardNumber = freezed,Object? ghanaCardVerified = null,}) {
  return _then(UserProfileResponse(
fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,preferredLanguage: null == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,ghanaCardNumber: freezed == ghanaCardNumber ? _self.ghanaCardNumber : ghanaCardNumber // ignore: cast_nullable_to_non_nullable
as String?,ghanaCardVerified: null == ghanaCardVerified ? _self.ghanaCardVerified : ghanaCardVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfileResponse].
extension UserProfileResponsePatterns on UserProfileResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfileResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfileResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfileResponse value)  $default,){
final _that = this;
switch (_that) {
case _UserProfileResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfileResponse value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfileResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fullName,  DateTime? dateOfBirth,  String? gender,  String preferredLanguage,  String? avatarUrl,  String? ghanaCardNumber,  bool ghanaCardVerified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfileResponse() when $default != null:
return $default(_that.fullName,_that.dateOfBirth,_that.gender,_that.preferredLanguage,_that.avatarUrl,_that.ghanaCardNumber,_that.ghanaCardVerified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fullName,  DateTime? dateOfBirth,  String? gender,  String preferredLanguage,  String? avatarUrl,  String? ghanaCardNumber,  bool ghanaCardVerified)  $default,) {final _that = this;
switch (_that) {
case _UserProfileResponse():
return $default(_that.fullName,_that.dateOfBirth,_that.gender,_that.preferredLanguage,_that.avatarUrl,_that.ghanaCardNumber,_that.ghanaCardVerified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fullName,  DateTime? dateOfBirth,  String? gender,  String preferredLanguage,  String? avatarUrl,  String? ghanaCardNumber,  bool ghanaCardVerified)?  $default,) {final _that = this;
switch (_that) {
case _UserProfileResponse() when $default != null:
return $default(_that.fullName,_that.dateOfBirth,_that.gender,_that.preferredLanguage,_that.avatarUrl,_that.ghanaCardNumber,_that.ghanaCardVerified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserProfileResponse implements UserProfileResponse {
  const _UserProfileResponse({required this.fullName, this.dateOfBirth, this.gender, required this.preferredLanguage, this.avatarUrl, this.ghanaCardNumber, required this.ghanaCardVerified});
  factory _UserProfileResponse.fromJson(Map<String, dynamic> json) => _$UserProfileResponseFromJson(json);

@override final  String fullName;
@override final  DateTime? dateOfBirth;
@override final  String? gender;
@override final  String preferredLanguage;
@override final  String? avatarUrl;
@override final  String? ghanaCardNumber;
@override final  bool ghanaCardVerified;

/// Create a copy of UserProfileResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileResponseCopyWith<_UserProfileResponse> get copyWith => __$UserProfileResponseCopyWithImpl<_UserProfileResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfileResponse&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.ghanaCardNumber, ghanaCardNumber) || other.ghanaCardNumber == ghanaCardNumber)&&(identical(other.ghanaCardVerified, ghanaCardVerified) || other.ghanaCardVerified == ghanaCardVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,dateOfBirth,gender,preferredLanguage,avatarUrl,ghanaCardNumber,ghanaCardVerified);

@override
String toString() {
  return 'UserProfileResponse(fullName: $fullName, dateOfBirth: $dateOfBirth, gender: $gender, preferredLanguage: $preferredLanguage, avatarUrl: $avatarUrl, ghanaCardNumber: $ghanaCardNumber, ghanaCardVerified: $ghanaCardVerified)';
}


}

/// @nodoc
abstract mixin class _$UserProfileResponseCopyWith<$Res> implements $UserProfileResponseCopyWith<$Res> {
  factory _$UserProfileResponseCopyWith(_UserProfileResponse value, $Res Function(_UserProfileResponse) _then) = __$UserProfileResponseCopyWithImpl;
@override @useResult
$Res call({
 String fullName, DateTime? dateOfBirth, String? gender, String preferredLanguage, String? avatarUrl, String? ghanaCardNumber, bool ghanaCardVerified
});




}
/// @nodoc
class __$UserProfileResponseCopyWithImpl<$Res>
    implements _$UserProfileResponseCopyWith<$Res> {
  __$UserProfileResponseCopyWithImpl(this._self, this._then);

  final _UserProfileResponse _self;
  final $Res Function(_UserProfileResponse) _then;

/// Create a copy of UserProfileResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fullName = null,Object? dateOfBirth = freezed,Object? gender = freezed,Object? preferredLanguage = null,Object? avatarUrl = freezed,Object? ghanaCardNumber = freezed,Object? ghanaCardVerified = null,}) {
  return _then(_UserProfileResponse(
fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,preferredLanguage: null == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,ghanaCardNumber: freezed == ghanaCardNumber ? _self.ghanaCardNumber : ghanaCardNumber // ignore: cast_nullable_to_non_nullable
as String?,ghanaCardVerified: null == ghanaCardVerified ? _self.ghanaCardVerified : ghanaCardVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$UserResponse {

 String get id; String get phoneNumber; String? get email; bool get isActive; bool get phoneVerified; bool get emailVerified; List<String> get roles; DateTime get createdAt; UserProfileResponse? get profile;
/// Create a copy of UserResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserResponseCopyWith<UserResponse> get copyWith => _$UserResponseCopyWithImpl<UserResponse>(this as UserResponse, _$identity);

  /// Serializes this UserResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.email, email) || other.email == email)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.phoneVerified, phoneVerified) || other.phoneVerified == phoneVerified)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.profile, profile) || other.profile == profile));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,phoneNumber,email,isActive,phoneVerified,emailVerified,const DeepCollectionEquality().hash(roles),createdAt,profile);

@override
String toString() {
  return 'UserResponse(id: $id, phoneNumber: $phoneNumber, email: $email, isActive: $isActive, phoneVerified: $phoneVerified, emailVerified: $emailVerified, roles: $roles, createdAt: $createdAt, profile: $profile)';
}


}

/// @nodoc
abstract mixin class $UserResponseCopyWith<$Res>  {
  factory $UserResponseCopyWith(UserResponse value, $Res Function(UserResponse) _then) = _$UserResponseCopyWithImpl;
@useResult
$Res call({
 String id, String phoneNumber, String? email, bool isActive, bool phoneVerified, bool emailVerified, List<String> roles, DateTime createdAt, UserProfileResponse? profile
});


$UserProfileResponseCopyWith<$Res>? get profile;

}
/// @nodoc
class _$UserResponseCopyWithImpl<$Res>
    implements $UserResponseCopyWith<$Res> {
  _$UserResponseCopyWithImpl(this._self, this._then);

  final UserResponse _self;
  final $Res Function(UserResponse) _then;

/// Create a copy of UserResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? phoneNumber = null,Object? email = freezed,Object? isActive = null,Object? phoneVerified = null,Object? emailVerified = null,Object? roles = null,Object? createdAt = null,Object? profile = freezed,}) {
  return _then(UserResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,phoneVerified: null == phoneVerified ? _self.phoneVerified : phoneVerified // ignore: cast_nullable_to_non_nullable
as bool,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as UserProfileResponse?,
  ));
}
/// Create a copy of UserResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileResponseCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $UserProfileResponseCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserResponse].
extension UserResponsePatterns on UserResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserResponse value)  $default,){
final _that = this;
switch (_that) {
case _UserResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserResponse value)?  $default,){
final _that = this;
switch (_that) {
case _UserResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String phoneNumber,  String? email,  bool isActive,  bool phoneVerified,  bool emailVerified,  List<String> roles,  DateTime createdAt,  UserProfileResponse? profile)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserResponse() when $default != null:
return $default(_that.id,_that.phoneNumber,_that.email,_that.isActive,_that.phoneVerified,_that.emailVerified,_that.roles,_that.createdAt,_that.profile);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String phoneNumber,  String? email,  bool isActive,  bool phoneVerified,  bool emailVerified,  List<String> roles,  DateTime createdAt,  UserProfileResponse? profile)  $default,) {final _that = this;
switch (_that) {
case _UserResponse():
return $default(_that.id,_that.phoneNumber,_that.email,_that.isActive,_that.phoneVerified,_that.emailVerified,_that.roles,_that.createdAt,_that.profile);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String phoneNumber,  String? email,  bool isActive,  bool phoneVerified,  bool emailVerified,  List<String> roles,  DateTime createdAt,  UserProfileResponse? profile)?  $default,) {final _that = this;
switch (_that) {
case _UserResponse() when $default != null:
return $default(_that.id,_that.phoneNumber,_that.email,_that.isActive,_that.phoneVerified,_that.emailVerified,_that.roles,_that.createdAt,_that.profile);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserResponse implements UserResponse {
  const _UserResponse({required this.id, required this.phoneNumber, this.email, required this.isActive, required this.phoneVerified, required this.emailVerified, required  List<String> roles, required this.createdAt, this.profile}): _roles = roles;
  factory _UserResponse.fromJson(Map<String, dynamic> json) => _$UserResponseFromJson(json);

@override final  String id;
@override final  String phoneNumber;
@override final  String? email;
@override final  bool isActive;
@override final  bool phoneVerified;
@override final  bool emailVerified;
 final  List<String> _roles;
@override List<String> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override final  DateTime createdAt;
@override final  UserProfileResponse? profile;

/// Create a copy of UserResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserResponseCopyWith<_UserResponse> get copyWith => __$UserResponseCopyWithImpl<_UserResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.email, email) || other.email == email)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.phoneVerified, phoneVerified) || other.phoneVerified == phoneVerified)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.profile, profile) || other.profile == profile));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,phoneNumber,email,isActive,phoneVerified,emailVerified,const DeepCollectionEquality().hash(_roles),createdAt,profile);

@override
String toString() {
  return 'UserResponse(id: $id, phoneNumber: $phoneNumber, email: $email, isActive: $isActive, phoneVerified: $phoneVerified, emailVerified: $emailVerified, roles: $roles, createdAt: $createdAt, profile: $profile)';
}


}

/// @nodoc
abstract mixin class _$UserResponseCopyWith<$Res> implements $UserResponseCopyWith<$Res> {
  factory _$UserResponseCopyWith(_UserResponse value, $Res Function(_UserResponse) _then) = __$UserResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String phoneNumber, String? email, bool isActive, bool phoneVerified, bool emailVerified, List<String> roles, DateTime createdAt, UserProfileResponse? profile
});


@override $UserProfileResponseCopyWith<$Res>? get profile;

}
/// @nodoc
class __$UserResponseCopyWithImpl<$Res>
    implements _$UserResponseCopyWith<$Res> {
  __$UserResponseCopyWithImpl(this._self, this._then);

  final _UserResponse _self;
  final $Res Function(_UserResponse) _then;

/// Create a copy of UserResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? phoneNumber = null,Object? email = freezed,Object? isActive = null,Object? phoneVerified = null,Object? emailVerified = null,Object? roles = null,Object? createdAt = null,Object? profile = freezed,}) {
  return _then(_UserResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,phoneVerified: null == phoneVerified ? _self.phoneVerified : phoneVerified // ignore: cast_nullable_to_non_nullable
as bool,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as UserProfileResponse?,
  ));
}

/// Create a copy of UserResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileResponseCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $UserProfileResponseCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}


/// @nodoc
mixin _$UserProfileUpdateRequest {

 String? get fullName; DateTime? get dateOfBirth; String? get gender; String? get preferredLanguage; String? get avatarUrl;
/// Create a copy of UserProfileUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileUpdateRequestCopyWith<UserProfileUpdateRequest> get copyWith => _$UserProfileUpdateRequestCopyWithImpl<UserProfileUpdateRequest>(this as UserProfileUpdateRequest, _$identity);

  /// Serializes this UserProfileUpdateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfileUpdateRequest&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,dateOfBirth,gender,preferredLanguage,avatarUrl);

@override
String toString() {
  return 'UserProfileUpdateRequest(fullName: $fullName, dateOfBirth: $dateOfBirth, gender: $gender, preferredLanguage: $preferredLanguage, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $UserProfileUpdateRequestCopyWith<$Res>  {
  factory $UserProfileUpdateRequestCopyWith(UserProfileUpdateRequest value, $Res Function(UserProfileUpdateRequest) _then) = _$UserProfileUpdateRequestCopyWithImpl;
@useResult
$Res call({
 String? fullName, DateTime? dateOfBirth, String? gender, String? preferredLanguage, String? avatarUrl
});




}
/// @nodoc
class _$UserProfileUpdateRequestCopyWithImpl<$Res>
    implements $UserProfileUpdateRequestCopyWith<$Res> {
  _$UserProfileUpdateRequestCopyWithImpl(this._self, this._then);

  final UserProfileUpdateRequest _self;
  final $Res Function(UserProfileUpdateRequest) _then;

/// Create a copy of UserProfileUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fullName = freezed,Object? dateOfBirth = freezed,Object? gender = freezed,Object? preferredLanguage = freezed,Object? avatarUrl = freezed,}) {
  return _then(UserProfileUpdateRequest(
fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,preferredLanguage: freezed == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfileUpdateRequest].
extension UserProfileUpdateRequestPatterns on UserProfileUpdateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfileUpdateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfileUpdateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfileUpdateRequest value)  $default,){
final _that = this;
switch (_that) {
case _UserProfileUpdateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfileUpdateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfileUpdateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? fullName,  DateTime? dateOfBirth,  String? gender,  String? preferredLanguage,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfileUpdateRequest() when $default != null:
return $default(_that.fullName,_that.dateOfBirth,_that.gender,_that.preferredLanguage,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? fullName,  DateTime? dateOfBirth,  String? gender,  String? preferredLanguage,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _UserProfileUpdateRequest():
return $default(_that.fullName,_that.dateOfBirth,_that.gender,_that.preferredLanguage,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? fullName,  DateTime? dateOfBirth,  String? gender,  String? preferredLanguage,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _UserProfileUpdateRequest() when $default != null:
return $default(_that.fullName,_that.dateOfBirth,_that.gender,_that.preferredLanguage,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserProfileUpdateRequest implements UserProfileUpdateRequest {
  const _UserProfileUpdateRequest({this.fullName, this.dateOfBirth, this.gender, this.preferredLanguage, this.avatarUrl});
  factory _UserProfileUpdateRequest.fromJson(Map<String, dynamic> json) => _$UserProfileUpdateRequestFromJson(json);

@override final  String? fullName;
@override final  DateTime? dateOfBirth;
@override final  String? gender;
@override final  String? preferredLanguage;
@override final  String? avatarUrl;

/// Create a copy of UserProfileUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileUpdateRequestCopyWith<_UserProfileUpdateRequest> get copyWith => __$UserProfileUpdateRequestCopyWithImpl<_UserProfileUpdateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileUpdateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfileUpdateRequest&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,dateOfBirth,gender,preferredLanguage,avatarUrl);

@override
String toString() {
  return 'UserProfileUpdateRequest(fullName: $fullName, dateOfBirth: $dateOfBirth, gender: $gender, preferredLanguage: $preferredLanguage, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$UserProfileUpdateRequestCopyWith<$Res> implements $UserProfileUpdateRequestCopyWith<$Res> {
  factory _$UserProfileUpdateRequestCopyWith(_UserProfileUpdateRequest value, $Res Function(_UserProfileUpdateRequest) _then) = __$UserProfileUpdateRequestCopyWithImpl;
@override @useResult
$Res call({
 String? fullName, DateTime? dateOfBirth, String? gender, String? preferredLanguage, String? avatarUrl
});




}
/// @nodoc
class __$UserProfileUpdateRequestCopyWithImpl<$Res>
    implements _$UserProfileUpdateRequestCopyWith<$Res> {
  __$UserProfileUpdateRequestCopyWithImpl(this._self, this._then);

  final _UserProfileUpdateRequest _self;
  final $Res Function(_UserProfileUpdateRequest) _then;

/// Create a copy of UserProfileUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fullName = freezed,Object? dateOfBirth = freezed,Object? gender = freezed,Object? preferredLanguage = freezed,Object? avatarUrl = freezed,}) {
  return _then(_UserProfileUpdateRequest(
fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,preferredLanguage: freezed == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AccountDeletionRequest {

 String get password; String? get reason;
/// Create a copy of AccountDeletionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountDeletionRequestCopyWith<AccountDeletionRequest> get copyWith => _$AccountDeletionRequestCopyWithImpl<AccountDeletionRequest>(this as AccountDeletionRequest, _$identity);

  /// Serializes this AccountDeletionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountDeletionRequest&&(identical(other.password, password) || other.password == password)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,password,reason);

@override
String toString() {
  return 'AccountDeletionRequest(password: $password, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $AccountDeletionRequestCopyWith<$Res>  {
  factory $AccountDeletionRequestCopyWith(AccountDeletionRequest value, $Res Function(AccountDeletionRequest) _then) = _$AccountDeletionRequestCopyWithImpl;
@useResult
$Res call({
 String password, String? reason
});




}
/// @nodoc
class _$AccountDeletionRequestCopyWithImpl<$Res>
    implements $AccountDeletionRequestCopyWith<$Res> {
  _$AccountDeletionRequestCopyWithImpl(this._self, this._then);

  final AccountDeletionRequest _self;
  final $Res Function(AccountDeletionRequest) _then;

/// Create a copy of AccountDeletionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? password = null,Object? reason = freezed,}) {
  return _then(AccountDeletionRequest(
password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountDeletionRequest].
extension AccountDeletionRequestPatterns on AccountDeletionRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountDeletionRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountDeletionRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountDeletionRequest value)  $default,){
final _that = this;
switch (_that) {
case _AccountDeletionRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountDeletionRequest value)?  $default,){
final _that = this;
switch (_that) {
case _AccountDeletionRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String password,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountDeletionRequest() when $default != null:
return $default(_that.password,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String password,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _AccountDeletionRequest():
return $default(_that.password,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String password,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _AccountDeletionRequest() when $default != null:
return $default(_that.password,_that.reason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountDeletionRequest implements AccountDeletionRequest {
  const _AccountDeletionRequest({required this.password, this.reason});
  factory _AccountDeletionRequest.fromJson(Map<String, dynamic> json) => _$AccountDeletionRequestFromJson(json);

@override final  String password;
@override final  String? reason;

/// Create a copy of AccountDeletionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountDeletionRequestCopyWith<_AccountDeletionRequest> get copyWith => __$AccountDeletionRequestCopyWithImpl<_AccountDeletionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountDeletionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountDeletionRequest&&(identical(other.password, password) || other.password == password)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,password,reason);

@override
String toString() {
  return 'AccountDeletionRequest(password: $password, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$AccountDeletionRequestCopyWith<$Res> implements $AccountDeletionRequestCopyWith<$Res> {
  factory _$AccountDeletionRequestCopyWith(_AccountDeletionRequest value, $Res Function(_AccountDeletionRequest) _then) = __$AccountDeletionRequestCopyWithImpl;
@override @useResult
$Res call({
 String password, String? reason
});




}
/// @nodoc
class __$AccountDeletionRequestCopyWithImpl<$Res>
    implements _$AccountDeletionRequestCopyWith<$Res> {
  __$AccountDeletionRequestCopyWithImpl(this._self, this._then);

  final _AccountDeletionRequest _self;
  final $Res Function(_AccountDeletionRequest) _then;

/// Create a copy of AccountDeletionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? password = null,Object? reason = freezed,}) {
  return _then(_AccountDeletionRequest(
password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ChangePasswordRequest {

 String get currentPassword; String get newPassword;
/// Create a copy of ChangePasswordRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangePasswordRequestCopyWith<ChangePasswordRequest> get copyWith => _$ChangePasswordRequestCopyWithImpl<ChangePasswordRequest>(this as ChangePasswordRequest, _$identity);

  /// Serializes this ChangePasswordRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangePasswordRequest&&(identical(other.currentPassword, currentPassword) || other.currentPassword == currentPassword)&&(identical(other.newPassword, newPassword) || other.newPassword == newPassword));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPassword,newPassword);

@override
String toString() {
  return 'ChangePasswordRequest(currentPassword: $currentPassword, newPassword: $newPassword)';
}


}

/// @nodoc
abstract mixin class $ChangePasswordRequestCopyWith<$Res>  {
  factory $ChangePasswordRequestCopyWith(ChangePasswordRequest value, $Res Function(ChangePasswordRequest) _then) = _$ChangePasswordRequestCopyWithImpl;
@useResult
$Res call({
 String currentPassword, String newPassword
});




}
/// @nodoc
class _$ChangePasswordRequestCopyWithImpl<$Res>
    implements $ChangePasswordRequestCopyWith<$Res> {
  _$ChangePasswordRequestCopyWithImpl(this._self, this._then);

  final ChangePasswordRequest _self;
  final $Res Function(ChangePasswordRequest) _then;

/// Create a copy of ChangePasswordRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentPassword = null,Object? newPassword = null,}) {
  return _then(ChangePasswordRequest(
currentPassword: null == currentPassword ? _self.currentPassword : currentPassword // ignore: cast_nullable_to_non_nullable
as String,newPassword: null == newPassword ? _self.newPassword : newPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChangePasswordRequest].
extension ChangePasswordRequestPatterns on ChangePasswordRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChangePasswordRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChangePasswordRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChangePasswordRequest value)  $default,){
final _that = this;
switch (_that) {
case _ChangePasswordRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChangePasswordRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ChangePasswordRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String currentPassword,  String newPassword)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChangePasswordRequest() when $default != null:
return $default(_that.currentPassword,_that.newPassword);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String currentPassword,  String newPassword)  $default,) {final _that = this;
switch (_that) {
case _ChangePasswordRequest():
return $default(_that.currentPassword,_that.newPassword);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String currentPassword,  String newPassword)?  $default,) {final _that = this;
switch (_that) {
case _ChangePasswordRequest() when $default != null:
return $default(_that.currentPassword,_that.newPassword);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChangePasswordRequest implements ChangePasswordRequest {
  const _ChangePasswordRequest({required this.currentPassword, required this.newPassword});
  factory _ChangePasswordRequest.fromJson(Map<String, dynamic> json) => _$ChangePasswordRequestFromJson(json);

@override final  String currentPassword;
@override final  String newPassword;

/// Create a copy of ChangePasswordRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChangePasswordRequestCopyWith<_ChangePasswordRequest> get copyWith => __$ChangePasswordRequestCopyWithImpl<_ChangePasswordRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChangePasswordRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChangePasswordRequest&&(identical(other.currentPassword, currentPassword) || other.currentPassword == currentPassword)&&(identical(other.newPassword, newPassword) || other.newPassword == newPassword));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPassword,newPassword);

@override
String toString() {
  return 'ChangePasswordRequest(currentPassword: $currentPassword, newPassword: $newPassword)';
}


}

/// @nodoc
abstract mixin class _$ChangePasswordRequestCopyWith<$Res> implements $ChangePasswordRequestCopyWith<$Res> {
  factory _$ChangePasswordRequestCopyWith(_ChangePasswordRequest value, $Res Function(_ChangePasswordRequest) _then) = __$ChangePasswordRequestCopyWithImpl;
@override @useResult
$Res call({
 String currentPassword, String newPassword
});




}
/// @nodoc
class __$ChangePasswordRequestCopyWithImpl<$Res>
    implements _$ChangePasswordRequestCopyWith<$Res> {
  __$ChangePasswordRequestCopyWithImpl(this._self, this._then);

  final _ChangePasswordRequest _self;
  final $Res Function(_ChangePasswordRequest) _then;

/// Create a copy of ChangePasswordRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentPassword = null,Object? newPassword = null,}) {
  return _then(_ChangePasswordRequest(
currentPassword: null == currentPassword ? _self.currentPassword : currentPassword // ignore: cast_nullable_to_non_nullable
as String,newPassword: null == newPassword ? _self.newPassword : newPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ChangeEmailRequest {

 String get newEmail; String get currentPassword;
/// Create a copy of ChangeEmailRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeEmailRequestCopyWith<ChangeEmailRequest> get copyWith => _$ChangeEmailRequestCopyWithImpl<ChangeEmailRequest>(this as ChangeEmailRequest, _$identity);

  /// Serializes this ChangeEmailRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeEmailRequest&&(identical(other.newEmail, newEmail) || other.newEmail == newEmail)&&(identical(other.currentPassword, currentPassword) || other.currentPassword == currentPassword));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,newEmail,currentPassword);

@override
String toString() {
  return 'ChangeEmailRequest(newEmail: $newEmail, currentPassword: $currentPassword)';
}


}

/// @nodoc
abstract mixin class $ChangeEmailRequestCopyWith<$Res>  {
  factory $ChangeEmailRequestCopyWith(ChangeEmailRequest value, $Res Function(ChangeEmailRequest) _then) = _$ChangeEmailRequestCopyWithImpl;
@useResult
$Res call({
 String newEmail, String currentPassword
});




}
/// @nodoc
class _$ChangeEmailRequestCopyWithImpl<$Res>
    implements $ChangeEmailRequestCopyWith<$Res> {
  _$ChangeEmailRequestCopyWithImpl(this._self, this._then);

  final ChangeEmailRequest _self;
  final $Res Function(ChangeEmailRequest) _then;

/// Create a copy of ChangeEmailRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? newEmail = null,Object? currentPassword = null,}) {
  return _then(ChangeEmailRequest(
newEmail: null == newEmail ? _self.newEmail : newEmail // ignore: cast_nullable_to_non_nullable
as String,currentPassword: null == currentPassword ? _self.currentPassword : currentPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChangeEmailRequest].
extension ChangeEmailRequestPatterns on ChangeEmailRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChangeEmailRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChangeEmailRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChangeEmailRequest value)  $default,){
final _that = this;
switch (_that) {
case _ChangeEmailRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChangeEmailRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ChangeEmailRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String newEmail,  String currentPassword)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChangeEmailRequest() when $default != null:
return $default(_that.newEmail,_that.currentPassword);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String newEmail,  String currentPassword)  $default,) {final _that = this;
switch (_that) {
case _ChangeEmailRequest():
return $default(_that.newEmail,_that.currentPassword);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String newEmail,  String currentPassword)?  $default,) {final _that = this;
switch (_that) {
case _ChangeEmailRequest() when $default != null:
return $default(_that.newEmail,_that.currentPassword);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChangeEmailRequest implements ChangeEmailRequest {
  const _ChangeEmailRequest({required this.newEmail, required this.currentPassword});
  factory _ChangeEmailRequest.fromJson(Map<String, dynamic> json) => _$ChangeEmailRequestFromJson(json);

@override final  String newEmail;
@override final  String currentPassword;

/// Create a copy of ChangeEmailRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChangeEmailRequestCopyWith<_ChangeEmailRequest> get copyWith => __$ChangeEmailRequestCopyWithImpl<_ChangeEmailRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChangeEmailRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChangeEmailRequest&&(identical(other.newEmail, newEmail) || other.newEmail == newEmail)&&(identical(other.currentPassword, currentPassword) || other.currentPassword == currentPassword));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,newEmail,currentPassword);

@override
String toString() {
  return 'ChangeEmailRequest(newEmail: $newEmail, currentPassword: $currentPassword)';
}


}

/// @nodoc
abstract mixin class _$ChangeEmailRequestCopyWith<$Res> implements $ChangeEmailRequestCopyWith<$Res> {
  factory _$ChangeEmailRequestCopyWith(_ChangeEmailRequest value, $Res Function(_ChangeEmailRequest) _then) = __$ChangeEmailRequestCopyWithImpl;
@override @useResult
$Res call({
 String newEmail, String currentPassword
});




}
/// @nodoc
class __$ChangeEmailRequestCopyWithImpl<$Res>
    implements _$ChangeEmailRequestCopyWith<$Res> {
  __$ChangeEmailRequestCopyWithImpl(this._self, this._then);

  final _ChangeEmailRequest _self;
  final $Res Function(_ChangeEmailRequest) _then;

/// Create a copy of ChangeEmailRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? newEmail = null,Object? currentPassword = null,}) {
  return _then(_ChangeEmailRequest(
newEmail: null == newEmail ? _self.newEmail : newEmail // ignore: cast_nullable_to_non_nullable
as String,currentPassword: null == currentPassword ? _self.currentPassword : currentPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$EmailChangeStartedResponse {

 String get message; String get otpSentTo; int get expiresInSeconds;
/// Create a copy of EmailChangeStartedResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmailChangeStartedResponseCopyWith<EmailChangeStartedResponse> get copyWith => _$EmailChangeStartedResponseCopyWithImpl<EmailChangeStartedResponse>(this as EmailChangeStartedResponse, _$identity);

  /// Serializes this EmailChangeStartedResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailChangeStartedResponse&&(identical(other.message, message) || other.message == message)&&(identical(other.otpSentTo, otpSentTo) || other.otpSentTo == otpSentTo)&&(identical(other.expiresInSeconds, expiresInSeconds) || other.expiresInSeconds == expiresInSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,otpSentTo,expiresInSeconds);

@override
String toString() {
  return 'EmailChangeStartedResponse(message: $message, otpSentTo: $otpSentTo, expiresInSeconds: $expiresInSeconds)';
}


}

/// @nodoc
abstract mixin class $EmailChangeStartedResponseCopyWith<$Res>  {
  factory $EmailChangeStartedResponseCopyWith(EmailChangeStartedResponse value, $Res Function(EmailChangeStartedResponse) _then) = _$EmailChangeStartedResponseCopyWithImpl;
@useResult
$Res call({
 String message, String otpSentTo, int expiresInSeconds
});




}
/// @nodoc
class _$EmailChangeStartedResponseCopyWithImpl<$Res>
    implements $EmailChangeStartedResponseCopyWith<$Res> {
  _$EmailChangeStartedResponseCopyWithImpl(this._self, this._then);

  final EmailChangeStartedResponse _self;
  final $Res Function(EmailChangeStartedResponse) _then;

/// Create a copy of EmailChangeStartedResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? otpSentTo = null,Object? expiresInSeconds = null,}) {
  return _then(EmailChangeStartedResponse(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,otpSentTo: null == otpSentTo ? _self.otpSentTo : otpSentTo // ignore: cast_nullable_to_non_nullable
as String,expiresInSeconds: null == expiresInSeconds ? _self.expiresInSeconds : expiresInSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [EmailChangeStartedResponse].
extension EmailChangeStartedResponsePatterns on EmailChangeStartedResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmailChangeStartedResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmailChangeStartedResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmailChangeStartedResponse value)  $default,){
final _that = this;
switch (_that) {
case _EmailChangeStartedResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmailChangeStartedResponse value)?  $default,){
final _that = this;
switch (_that) {
case _EmailChangeStartedResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  String otpSentTo,  int expiresInSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmailChangeStartedResponse() when $default != null:
return $default(_that.message,_that.otpSentTo,_that.expiresInSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  String otpSentTo,  int expiresInSeconds)  $default,) {final _that = this;
switch (_that) {
case _EmailChangeStartedResponse():
return $default(_that.message,_that.otpSentTo,_that.expiresInSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  String otpSentTo,  int expiresInSeconds)?  $default,) {final _that = this;
switch (_that) {
case _EmailChangeStartedResponse() when $default != null:
return $default(_that.message,_that.otpSentTo,_that.expiresInSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EmailChangeStartedResponse implements EmailChangeStartedResponse {
  const _EmailChangeStartedResponse({required this.message, required this.otpSentTo, required this.expiresInSeconds});
  factory _EmailChangeStartedResponse.fromJson(Map<String, dynamic> json) => _$EmailChangeStartedResponseFromJson(json);

@override final  String message;
@override final  String otpSentTo;
@override final  int expiresInSeconds;

/// Create a copy of EmailChangeStartedResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmailChangeStartedResponseCopyWith<_EmailChangeStartedResponse> get copyWith => __$EmailChangeStartedResponseCopyWithImpl<_EmailChangeStartedResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EmailChangeStartedResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmailChangeStartedResponse&&(identical(other.message, message) || other.message == message)&&(identical(other.otpSentTo, otpSentTo) || other.otpSentTo == otpSentTo)&&(identical(other.expiresInSeconds, expiresInSeconds) || other.expiresInSeconds == expiresInSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,otpSentTo,expiresInSeconds);

@override
String toString() {
  return 'EmailChangeStartedResponse(message: $message, otpSentTo: $otpSentTo, expiresInSeconds: $expiresInSeconds)';
}


}

/// @nodoc
abstract mixin class _$EmailChangeStartedResponseCopyWith<$Res> implements $EmailChangeStartedResponseCopyWith<$Res> {
  factory _$EmailChangeStartedResponseCopyWith(_EmailChangeStartedResponse value, $Res Function(_EmailChangeStartedResponse) _then) = __$EmailChangeStartedResponseCopyWithImpl;
@override @useResult
$Res call({
 String message, String otpSentTo, int expiresInSeconds
});




}
/// @nodoc
class __$EmailChangeStartedResponseCopyWithImpl<$Res>
    implements _$EmailChangeStartedResponseCopyWith<$Res> {
  __$EmailChangeStartedResponseCopyWithImpl(this._self, this._then);

  final _EmailChangeStartedResponse _self;
  final $Res Function(_EmailChangeStartedResponse) _then;

/// Create a copy of EmailChangeStartedResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? otpSentTo = null,Object? expiresInSeconds = null,}) {
  return _then(_EmailChangeStartedResponse(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,otpSentTo: null == otpSentTo ? _self.otpSentTo : otpSentTo // ignore: cast_nullable_to_non_nullable
as String,expiresInSeconds: null == expiresInSeconds ? _self.expiresInSeconds : expiresInSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ChangeEmailConfirmRequest {

 String get newEmail; String get code;
/// Create a copy of ChangeEmailConfirmRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeEmailConfirmRequestCopyWith<ChangeEmailConfirmRequest> get copyWith => _$ChangeEmailConfirmRequestCopyWithImpl<ChangeEmailConfirmRequest>(this as ChangeEmailConfirmRequest, _$identity);

  /// Serializes this ChangeEmailConfirmRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeEmailConfirmRequest&&(identical(other.newEmail, newEmail) || other.newEmail == newEmail)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,newEmail,code);

@override
String toString() {
  return 'ChangeEmailConfirmRequest(newEmail: $newEmail, code: $code)';
}


}

/// @nodoc
abstract mixin class $ChangeEmailConfirmRequestCopyWith<$Res>  {
  factory $ChangeEmailConfirmRequestCopyWith(ChangeEmailConfirmRequest value, $Res Function(ChangeEmailConfirmRequest) _then) = _$ChangeEmailConfirmRequestCopyWithImpl;
@useResult
$Res call({
 String newEmail, String code
});




}
/// @nodoc
class _$ChangeEmailConfirmRequestCopyWithImpl<$Res>
    implements $ChangeEmailConfirmRequestCopyWith<$Res> {
  _$ChangeEmailConfirmRequestCopyWithImpl(this._self, this._then);

  final ChangeEmailConfirmRequest _self;
  final $Res Function(ChangeEmailConfirmRequest) _then;

/// Create a copy of ChangeEmailConfirmRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? newEmail = null,Object? code = null,}) {
  return _then(ChangeEmailConfirmRequest(
newEmail: null == newEmail ? _self.newEmail : newEmail // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChangeEmailConfirmRequest].
extension ChangeEmailConfirmRequestPatterns on ChangeEmailConfirmRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChangeEmailConfirmRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChangeEmailConfirmRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChangeEmailConfirmRequest value)  $default,){
final _that = this;
switch (_that) {
case _ChangeEmailConfirmRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChangeEmailConfirmRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ChangeEmailConfirmRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String newEmail,  String code)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChangeEmailConfirmRequest() when $default != null:
return $default(_that.newEmail,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String newEmail,  String code)  $default,) {final _that = this;
switch (_that) {
case _ChangeEmailConfirmRequest():
return $default(_that.newEmail,_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String newEmail,  String code)?  $default,) {final _that = this;
switch (_that) {
case _ChangeEmailConfirmRequest() when $default != null:
return $default(_that.newEmail,_that.code);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChangeEmailConfirmRequest implements ChangeEmailConfirmRequest {
  const _ChangeEmailConfirmRequest({required this.newEmail, required this.code});
  factory _ChangeEmailConfirmRequest.fromJson(Map<String, dynamic> json) => _$ChangeEmailConfirmRequestFromJson(json);

@override final  String newEmail;
@override final  String code;

/// Create a copy of ChangeEmailConfirmRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChangeEmailConfirmRequestCopyWith<_ChangeEmailConfirmRequest> get copyWith => __$ChangeEmailConfirmRequestCopyWithImpl<_ChangeEmailConfirmRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChangeEmailConfirmRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChangeEmailConfirmRequest&&(identical(other.newEmail, newEmail) || other.newEmail == newEmail)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,newEmail,code);

@override
String toString() {
  return 'ChangeEmailConfirmRequest(newEmail: $newEmail, code: $code)';
}


}

/// @nodoc
abstract mixin class _$ChangeEmailConfirmRequestCopyWith<$Res> implements $ChangeEmailConfirmRequestCopyWith<$Res> {
  factory _$ChangeEmailConfirmRequestCopyWith(_ChangeEmailConfirmRequest value, $Res Function(_ChangeEmailConfirmRequest) _then) = __$ChangeEmailConfirmRequestCopyWithImpl;
@override @useResult
$Res call({
 String newEmail, String code
});




}
/// @nodoc
class __$ChangeEmailConfirmRequestCopyWithImpl<$Res>
    implements _$ChangeEmailConfirmRequestCopyWith<$Res> {
  __$ChangeEmailConfirmRequestCopyWithImpl(this._self, this._then);

  final _ChangeEmailConfirmRequest _self;
  final $Res Function(_ChangeEmailConfirmRequest) _then;

/// Create a copy of ChangeEmailConfirmRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? newEmail = null,Object? code = null,}) {
  return _then(_ChangeEmailConfirmRequest(
newEmail: null == newEmail ? _self.newEmail : newEmail // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$FavouriteRouteCreateRequest {

 String get originStopId; String get destinationStopId; String? get label;
/// Create a copy of FavouriteRouteCreateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FavouriteRouteCreateRequestCopyWith<FavouriteRouteCreateRequest> get copyWith => _$FavouriteRouteCreateRequestCopyWithImpl<FavouriteRouteCreateRequest>(this as FavouriteRouteCreateRequest, _$identity);

  /// Serializes this FavouriteRouteCreateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavouriteRouteCreateRequest&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,originStopId,destinationStopId,label);

@override
String toString() {
  return 'FavouriteRouteCreateRequest(originStopId: $originStopId, destinationStopId: $destinationStopId, label: $label)';
}


}

/// @nodoc
abstract mixin class $FavouriteRouteCreateRequestCopyWith<$Res>  {
  factory $FavouriteRouteCreateRequestCopyWith(FavouriteRouteCreateRequest value, $Res Function(FavouriteRouteCreateRequest) _then) = _$FavouriteRouteCreateRequestCopyWithImpl;
@useResult
$Res call({
 String originStopId, String destinationStopId, String? label
});




}
/// @nodoc
class _$FavouriteRouteCreateRequestCopyWithImpl<$Res>
    implements $FavouriteRouteCreateRequestCopyWith<$Res> {
  _$FavouriteRouteCreateRequestCopyWithImpl(this._self, this._then);

  final FavouriteRouteCreateRequest _self;
  final $Res Function(FavouriteRouteCreateRequest) _then;

/// Create a copy of FavouriteRouteCreateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? originStopId = null,Object? destinationStopId = null,Object? label = freezed,}) {
  return _then(FavouriteRouteCreateRequest(
originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FavouriteRouteCreateRequest].
extension FavouriteRouteCreateRequestPatterns on FavouriteRouteCreateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FavouriteRouteCreateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FavouriteRouteCreateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FavouriteRouteCreateRequest value)  $default,){
final _that = this;
switch (_that) {
case _FavouriteRouteCreateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FavouriteRouteCreateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _FavouriteRouteCreateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String originStopId,  String destinationStopId,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FavouriteRouteCreateRequest() when $default != null:
return $default(_that.originStopId,_that.destinationStopId,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String originStopId,  String destinationStopId,  String? label)  $default,) {final _that = this;
switch (_that) {
case _FavouriteRouteCreateRequest():
return $default(_that.originStopId,_that.destinationStopId,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String originStopId,  String destinationStopId,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _FavouriteRouteCreateRequest() when $default != null:
return $default(_that.originStopId,_that.destinationStopId,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FavouriteRouteCreateRequest implements FavouriteRouteCreateRequest {
  const _FavouriteRouteCreateRequest({required this.originStopId, required this.destinationStopId, this.label});
  factory _FavouriteRouteCreateRequest.fromJson(Map<String, dynamic> json) => _$FavouriteRouteCreateRequestFromJson(json);

@override final  String originStopId;
@override final  String destinationStopId;
@override final  String? label;

/// Create a copy of FavouriteRouteCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavouriteRouteCreateRequestCopyWith<_FavouriteRouteCreateRequest> get copyWith => __$FavouriteRouteCreateRequestCopyWithImpl<_FavouriteRouteCreateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FavouriteRouteCreateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavouriteRouteCreateRequest&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,originStopId,destinationStopId,label);

@override
String toString() {
  return 'FavouriteRouteCreateRequest(originStopId: $originStopId, destinationStopId: $destinationStopId, label: $label)';
}


}

/// @nodoc
abstract mixin class _$FavouriteRouteCreateRequestCopyWith<$Res> implements $FavouriteRouteCreateRequestCopyWith<$Res> {
  factory _$FavouriteRouteCreateRequestCopyWith(_FavouriteRouteCreateRequest value, $Res Function(_FavouriteRouteCreateRequest) _then) = __$FavouriteRouteCreateRequestCopyWithImpl;
@override @useResult
$Res call({
 String originStopId, String destinationStopId, String? label
});




}
/// @nodoc
class __$FavouriteRouteCreateRequestCopyWithImpl<$Res>
    implements _$FavouriteRouteCreateRequestCopyWith<$Res> {
  __$FavouriteRouteCreateRequestCopyWithImpl(this._self, this._then);

  final _FavouriteRouteCreateRequest _self;
  final $Res Function(_FavouriteRouteCreateRequest) _then;

/// Create a copy of FavouriteRouteCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? originStopId = null,Object? destinationStopId = null,Object? label = freezed,}) {
  return _then(_FavouriteRouteCreateRequest(
originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$FavouriteRouteResponse {

 String get id; String get originStopId; String get originStopName; String get destinationStopId; String get destinationStopName;/// The passenger's own name for it, e.g. "Home to work".
 String? get label; DateTime get createdAt;
/// Create a copy of FavouriteRouteResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FavouriteRouteResponseCopyWith<FavouriteRouteResponse> get copyWith => _$FavouriteRouteResponseCopyWithImpl<FavouriteRouteResponse>(this as FavouriteRouteResponse, _$identity);

  /// Serializes this FavouriteRouteResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavouriteRouteResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.originStopName, originStopName) || other.originStopName == originStopName)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.destinationStopName, destinationStopName) || other.destinationStopName == destinationStopName)&&(identical(other.label, label) || other.label == label)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,originStopId,originStopName,destinationStopId,destinationStopName,label,createdAt);

@override
String toString() {
  return 'FavouriteRouteResponse(id: $id, originStopId: $originStopId, originStopName: $originStopName, destinationStopId: $destinationStopId, destinationStopName: $destinationStopName, label: $label, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FavouriteRouteResponseCopyWith<$Res>  {
  factory $FavouriteRouteResponseCopyWith(FavouriteRouteResponse value, $Res Function(FavouriteRouteResponse) _then) = _$FavouriteRouteResponseCopyWithImpl;
@useResult
$Res call({
 String id, String originStopId, String originStopName, String destinationStopId, String destinationStopName, String? label, DateTime createdAt
});




}
/// @nodoc
class _$FavouriteRouteResponseCopyWithImpl<$Res>
    implements $FavouriteRouteResponseCopyWith<$Res> {
  _$FavouriteRouteResponseCopyWithImpl(this._self, this._then);

  final FavouriteRouteResponse _self;
  final $Res Function(FavouriteRouteResponse) _then;

/// Create a copy of FavouriteRouteResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? originStopId = null,Object? originStopName = null,Object? destinationStopId = null,Object? destinationStopName = null,Object? label = freezed,Object? createdAt = null,}) {
  return _then(FavouriteRouteResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,originStopName: null == originStopName ? _self.originStopName : originStopName // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopName: null == destinationStopName ? _self.destinationStopName : destinationStopName // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FavouriteRouteResponse].
extension FavouriteRouteResponsePatterns on FavouriteRouteResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FavouriteRouteResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FavouriteRouteResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FavouriteRouteResponse value)  $default,){
final _that = this;
switch (_that) {
case _FavouriteRouteResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FavouriteRouteResponse value)?  $default,){
final _that = this;
switch (_that) {
case _FavouriteRouteResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String originStopId,  String originStopName,  String destinationStopId,  String destinationStopName,  String? label,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FavouriteRouteResponse() when $default != null:
return $default(_that.id,_that.originStopId,_that.originStopName,_that.destinationStopId,_that.destinationStopName,_that.label,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String originStopId,  String originStopName,  String destinationStopId,  String destinationStopName,  String? label,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _FavouriteRouteResponse():
return $default(_that.id,_that.originStopId,_that.originStopName,_that.destinationStopId,_that.destinationStopName,_that.label,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String originStopId,  String originStopName,  String destinationStopId,  String destinationStopName,  String? label,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FavouriteRouteResponse() when $default != null:
return $default(_that.id,_that.originStopId,_that.originStopName,_that.destinationStopId,_that.destinationStopName,_that.label,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FavouriteRouteResponse implements FavouriteRouteResponse {
  const _FavouriteRouteResponse({required this.id, required this.originStopId, required this.originStopName, required this.destinationStopId, required this.destinationStopName, this.label, required this.createdAt});
  factory _FavouriteRouteResponse.fromJson(Map<String, dynamic> json) => _$FavouriteRouteResponseFromJson(json);

@override final  String id;
@override final  String originStopId;
@override final  String originStopName;
@override final  String destinationStopId;
@override final  String destinationStopName;
/// The passenger's own name for it, e.g. "Home to work".
@override final  String? label;
@override final  DateTime createdAt;

/// Create a copy of FavouriteRouteResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavouriteRouteResponseCopyWith<_FavouriteRouteResponse> get copyWith => __$FavouriteRouteResponseCopyWithImpl<_FavouriteRouteResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FavouriteRouteResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavouriteRouteResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.originStopId, originStopId) || other.originStopId == originStopId)&&(identical(other.originStopName, originStopName) || other.originStopName == originStopName)&&(identical(other.destinationStopId, destinationStopId) || other.destinationStopId == destinationStopId)&&(identical(other.destinationStopName, destinationStopName) || other.destinationStopName == destinationStopName)&&(identical(other.label, label) || other.label == label)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,originStopId,originStopName,destinationStopId,destinationStopName,label,createdAt);

@override
String toString() {
  return 'FavouriteRouteResponse(id: $id, originStopId: $originStopId, originStopName: $originStopName, destinationStopId: $destinationStopId, destinationStopName: $destinationStopName, label: $label, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FavouriteRouteResponseCopyWith<$Res> implements $FavouriteRouteResponseCopyWith<$Res> {
  factory _$FavouriteRouteResponseCopyWith(_FavouriteRouteResponse value, $Res Function(_FavouriteRouteResponse) _then) = __$FavouriteRouteResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String originStopId, String originStopName, String destinationStopId, String destinationStopName, String? label, DateTime createdAt
});




}
/// @nodoc
class __$FavouriteRouteResponseCopyWithImpl<$Res>
    implements _$FavouriteRouteResponseCopyWith<$Res> {
  __$FavouriteRouteResponseCopyWithImpl(this._self, this._then);

  final _FavouriteRouteResponse _self;
  final $Res Function(_FavouriteRouteResponse) _then;

/// Create a copy of FavouriteRouteResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? originStopId = null,Object? originStopName = null,Object? destinationStopId = null,Object? destinationStopName = null,Object? label = freezed,Object? createdAt = null,}) {
  return _then(_FavouriteRouteResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,originStopId: null == originStopId ? _self.originStopId : originStopId // ignore: cast_nullable_to_non_nullable
as String,originStopName: null == originStopName ? _self.originStopName : originStopName // ignore: cast_nullable_to_non_nullable
as String,destinationStopId: null == destinationStopId ? _self.destinationStopId : destinationStopId // ignore: cast_nullable_to_non_nullable
as String,destinationStopName: null == destinationStopName ? _self.destinationStopName : destinationStopName // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
