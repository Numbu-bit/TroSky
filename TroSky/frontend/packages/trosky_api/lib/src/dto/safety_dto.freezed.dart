// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'safety_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReportIncidentRequest {

 IncidentType get incidentType; IncidentSeverity? get severity; String get description; double? get latitude; double? get longitude;
/// Create a copy of ReportIncidentRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportIncidentRequestCopyWith<ReportIncidentRequest> get copyWith => _$ReportIncidentRequestCopyWithImpl<ReportIncidentRequest>(this as ReportIncidentRequest, _$identity);

  /// Serializes this ReportIncidentRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportIncidentRequest&&(identical(other.incidentType, incidentType) || other.incidentType == incidentType)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.description, description) || other.description == description)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,incidentType,severity,description,latitude,longitude);

@override
String toString() {
  return 'ReportIncidentRequest(incidentType: $incidentType, severity: $severity, description: $description, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $ReportIncidentRequestCopyWith<$Res>  {
  factory $ReportIncidentRequestCopyWith(ReportIncidentRequest value, $Res Function(ReportIncidentRequest) _then) = _$ReportIncidentRequestCopyWithImpl;
@useResult
$Res call({
 IncidentType incidentType, IncidentSeverity? severity, String description, double? latitude, double? longitude
});




}
/// @nodoc
class _$ReportIncidentRequestCopyWithImpl<$Res>
    implements $ReportIncidentRequestCopyWith<$Res> {
  _$ReportIncidentRequestCopyWithImpl(this._self, this._then);

  final ReportIncidentRequest _self;
  final $Res Function(ReportIncidentRequest) _then;

/// Create a copy of ReportIncidentRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? incidentType = null,Object? severity = freezed,Object? description = null,Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(ReportIncidentRequest(
incidentType: null == incidentType ? _self.incidentType : incidentType // ignore: cast_nullable_to_non_nullable
as IncidentType,severity: freezed == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as IncidentSeverity?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReportIncidentRequest].
extension ReportIncidentRequestPatterns on ReportIncidentRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportIncidentRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportIncidentRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportIncidentRequest value)  $default,){
final _that = this;
switch (_that) {
case _ReportIncidentRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportIncidentRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ReportIncidentRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IncidentType incidentType,  IncidentSeverity? severity,  String description,  double? latitude,  double? longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportIncidentRequest() when $default != null:
return $default(_that.incidentType,_that.severity,_that.description,_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IncidentType incidentType,  IncidentSeverity? severity,  String description,  double? latitude,  double? longitude)  $default,) {final _that = this;
switch (_that) {
case _ReportIncidentRequest():
return $default(_that.incidentType,_that.severity,_that.description,_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IncidentType incidentType,  IncidentSeverity? severity,  String description,  double? latitude,  double? longitude)?  $default,) {final _that = this;
switch (_that) {
case _ReportIncidentRequest() when $default != null:
return $default(_that.incidentType,_that.severity,_that.description,_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReportIncidentRequest implements ReportIncidentRequest {
  const _ReportIncidentRequest({required this.incidentType, this.severity, required this.description, this.latitude, this.longitude});
  factory _ReportIncidentRequest.fromJson(Map<String, dynamic> json) => _$ReportIncidentRequestFromJson(json);

@override final  IncidentType incidentType;
@override final  IncidentSeverity? severity;
@override final  String description;
@override final  double? latitude;
@override final  double? longitude;

/// Create a copy of ReportIncidentRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportIncidentRequestCopyWith<_ReportIncidentRequest> get copyWith => __$ReportIncidentRequestCopyWithImpl<_ReportIncidentRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReportIncidentRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportIncidentRequest&&(identical(other.incidentType, incidentType) || other.incidentType == incidentType)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.description, description) || other.description == description)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,incidentType,severity,description,latitude,longitude);

@override
String toString() {
  return 'ReportIncidentRequest(incidentType: $incidentType, severity: $severity, description: $description, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$ReportIncidentRequestCopyWith<$Res> implements $ReportIncidentRequestCopyWith<$Res> {
  factory _$ReportIncidentRequestCopyWith(_ReportIncidentRequest value, $Res Function(_ReportIncidentRequest) _then) = __$ReportIncidentRequestCopyWithImpl;
@override @useResult
$Res call({
 IncidentType incidentType, IncidentSeverity? severity, String description, double? latitude, double? longitude
});




}
/// @nodoc
class __$ReportIncidentRequestCopyWithImpl<$Res>
    implements _$ReportIncidentRequestCopyWith<$Res> {
  __$ReportIncidentRequestCopyWithImpl(this._self, this._then);

  final _ReportIncidentRequest _self;
  final $Res Function(_ReportIncidentRequest) _then;

/// Create a copy of ReportIncidentRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? incidentType = null,Object? severity = freezed,Object? description = null,Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(_ReportIncidentRequest(
incidentType: null == incidentType ? _self.incidentType : incidentType // ignore: cast_nullable_to_non_nullable
as IncidentType,severity: freezed == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as IncidentSeverity?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$IncidentResponse {

 String get id; String get tripId; String get reportedBy;@JsonKey(unknownEnumValue: IncidentType.other) IncidentType get incidentType;@JsonKey(unknownEnumValue: IncidentSeverity.medium) IncidentSeverity get severity; String get description; String? get photoUrl;@JsonKey(unknownEnumValue: IncidentStatus.reported) IncidentStatus get status; String? get resolvedBy; DateTime? get resolvedAt; String? get resolutionNotes; DateTime get createdAt;
/// Create a copy of IncidentResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IncidentResponseCopyWith<IncidentResponse> get copyWith => _$IncidentResponseCopyWithImpl<IncidentResponse>(this as IncidentResponse, _$identity);

  /// Serializes this IncidentResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IncidentResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.reportedBy, reportedBy) || other.reportedBy == reportedBy)&&(identical(other.incidentType, incidentType) || other.incidentType == incidentType)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.description, description) || other.description == description)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.resolvedBy, resolvedBy) || other.resolvedBy == resolvedBy)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.resolutionNotes, resolutionNotes) || other.resolutionNotes == resolutionNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tripId,reportedBy,incidentType,severity,description,photoUrl,status,resolvedBy,resolvedAt,resolutionNotes,createdAt);

@override
String toString() {
  return 'IncidentResponse(id: $id, tripId: $tripId, reportedBy: $reportedBy, incidentType: $incidentType, severity: $severity, description: $description, photoUrl: $photoUrl, status: $status, resolvedBy: $resolvedBy, resolvedAt: $resolvedAt, resolutionNotes: $resolutionNotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $IncidentResponseCopyWith<$Res>  {
  factory $IncidentResponseCopyWith(IncidentResponse value, $Res Function(IncidentResponse) _then) = _$IncidentResponseCopyWithImpl;
@useResult
$Res call({
 String id, String tripId, String reportedBy,@JsonKey(unknownEnumValue: IncidentType.other) IncidentType incidentType,@JsonKey(unknownEnumValue: IncidentSeverity.medium) IncidentSeverity severity, String description, String? photoUrl,@JsonKey(unknownEnumValue: IncidentStatus.reported) IncidentStatus status, String? resolvedBy, DateTime? resolvedAt, String? resolutionNotes, DateTime createdAt
});




}
/// @nodoc
class _$IncidentResponseCopyWithImpl<$Res>
    implements $IncidentResponseCopyWith<$Res> {
  _$IncidentResponseCopyWithImpl(this._self, this._then);

  final IncidentResponse _self;
  final $Res Function(IncidentResponse) _then;

/// Create a copy of IncidentResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tripId = null,Object? reportedBy = null,Object? incidentType = null,Object? severity = null,Object? description = null,Object? photoUrl = freezed,Object? status = null,Object? resolvedBy = freezed,Object? resolvedAt = freezed,Object? resolutionNotes = freezed,Object? createdAt = null,}) {
  return _then(IncidentResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,reportedBy: null == reportedBy ? _self.reportedBy : reportedBy // ignore: cast_nullable_to_non_nullable
as String,incidentType: null == incidentType ? _self.incidentType : incidentType // ignore: cast_nullable_to_non_nullable
as IncidentType,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as IncidentSeverity,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as IncidentStatus,resolvedBy: freezed == resolvedBy ? _self.resolvedBy : resolvedBy // ignore: cast_nullable_to_non_nullable
as String?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolutionNotes: freezed == resolutionNotes ? _self.resolutionNotes : resolutionNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [IncidentResponse].
extension IncidentResponsePatterns on IncidentResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IncidentResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IncidentResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IncidentResponse value)  $default,){
final _that = this;
switch (_that) {
case _IncidentResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IncidentResponse value)?  $default,){
final _that = this;
switch (_that) {
case _IncidentResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String tripId,  String reportedBy, @JsonKey(unknownEnumValue: IncidentType.other)  IncidentType incidentType, @JsonKey(unknownEnumValue: IncidentSeverity.medium)  IncidentSeverity severity,  String description,  String? photoUrl, @JsonKey(unknownEnumValue: IncidentStatus.reported)  IncidentStatus status,  String? resolvedBy,  DateTime? resolvedAt,  String? resolutionNotes,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IncidentResponse() when $default != null:
return $default(_that.id,_that.tripId,_that.reportedBy,_that.incidentType,_that.severity,_that.description,_that.photoUrl,_that.status,_that.resolvedBy,_that.resolvedAt,_that.resolutionNotes,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String tripId,  String reportedBy, @JsonKey(unknownEnumValue: IncidentType.other)  IncidentType incidentType, @JsonKey(unknownEnumValue: IncidentSeverity.medium)  IncidentSeverity severity,  String description,  String? photoUrl, @JsonKey(unknownEnumValue: IncidentStatus.reported)  IncidentStatus status,  String? resolvedBy,  DateTime? resolvedAt,  String? resolutionNotes,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _IncidentResponse():
return $default(_that.id,_that.tripId,_that.reportedBy,_that.incidentType,_that.severity,_that.description,_that.photoUrl,_that.status,_that.resolvedBy,_that.resolvedAt,_that.resolutionNotes,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String tripId,  String reportedBy, @JsonKey(unknownEnumValue: IncidentType.other)  IncidentType incidentType, @JsonKey(unknownEnumValue: IncidentSeverity.medium)  IncidentSeverity severity,  String description,  String? photoUrl, @JsonKey(unknownEnumValue: IncidentStatus.reported)  IncidentStatus status,  String? resolvedBy,  DateTime? resolvedAt,  String? resolutionNotes,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _IncidentResponse() when $default != null:
return $default(_that.id,_that.tripId,_that.reportedBy,_that.incidentType,_that.severity,_that.description,_that.photoUrl,_that.status,_that.resolvedBy,_that.resolvedAt,_that.resolutionNotes,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IncidentResponse implements IncidentResponse {
  const _IncidentResponse({required this.id, required this.tripId, required this.reportedBy, @JsonKey(unknownEnumValue: IncidentType.other) required this.incidentType, @JsonKey(unknownEnumValue: IncidentSeverity.medium) required this.severity, required this.description, this.photoUrl, @JsonKey(unknownEnumValue: IncidentStatus.reported) required this.status, this.resolvedBy, this.resolvedAt, this.resolutionNotes, required this.createdAt});
  factory _IncidentResponse.fromJson(Map<String, dynamic> json) => _$IncidentResponseFromJson(json);

@override final  String id;
@override final  String tripId;
@override final  String reportedBy;
@override@JsonKey(unknownEnumValue: IncidentType.other) final  IncidentType incidentType;
@override@JsonKey(unknownEnumValue: IncidentSeverity.medium) final  IncidentSeverity severity;
@override final  String description;
@override final  String? photoUrl;
@override@JsonKey(unknownEnumValue: IncidentStatus.reported) final  IncidentStatus status;
@override final  String? resolvedBy;
@override final  DateTime? resolvedAt;
@override final  String? resolutionNotes;
@override final  DateTime createdAt;

/// Create a copy of IncidentResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IncidentResponseCopyWith<_IncidentResponse> get copyWith => __$IncidentResponseCopyWithImpl<_IncidentResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IncidentResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IncidentResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.reportedBy, reportedBy) || other.reportedBy == reportedBy)&&(identical(other.incidentType, incidentType) || other.incidentType == incidentType)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.description, description) || other.description == description)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.resolvedBy, resolvedBy) || other.resolvedBy == resolvedBy)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.resolutionNotes, resolutionNotes) || other.resolutionNotes == resolutionNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tripId,reportedBy,incidentType,severity,description,photoUrl,status,resolvedBy,resolvedAt,resolutionNotes,createdAt);

@override
String toString() {
  return 'IncidentResponse(id: $id, tripId: $tripId, reportedBy: $reportedBy, incidentType: $incidentType, severity: $severity, description: $description, photoUrl: $photoUrl, status: $status, resolvedBy: $resolvedBy, resolvedAt: $resolvedAt, resolutionNotes: $resolutionNotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$IncidentResponseCopyWith<$Res> implements $IncidentResponseCopyWith<$Res> {
  factory _$IncidentResponseCopyWith(_IncidentResponse value, $Res Function(_IncidentResponse) _then) = __$IncidentResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String tripId, String reportedBy,@JsonKey(unknownEnumValue: IncidentType.other) IncidentType incidentType,@JsonKey(unknownEnumValue: IncidentSeverity.medium) IncidentSeverity severity, String description, String? photoUrl,@JsonKey(unknownEnumValue: IncidentStatus.reported) IncidentStatus status, String? resolvedBy, DateTime? resolvedAt, String? resolutionNotes, DateTime createdAt
});




}
/// @nodoc
class __$IncidentResponseCopyWithImpl<$Res>
    implements _$IncidentResponseCopyWith<$Res> {
  __$IncidentResponseCopyWithImpl(this._self, this._then);

  final _IncidentResponse _self;
  final $Res Function(_IncidentResponse) _then;

/// Create a copy of IncidentResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tripId = null,Object? reportedBy = null,Object? incidentType = null,Object? severity = null,Object? description = null,Object? photoUrl = freezed,Object? status = null,Object? resolvedBy = freezed,Object? resolvedAt = freezed,Object? resolutionNotes = freezed,Object? createdAt = null,}) {
  return _then(_IncidentResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,reportedBy: null == reportedBy ? _self.reportedBy : reportedBy // ignore: cast_nullable_to_non_nullable
as String,incidentType: null == incidentType ? _self.incidentType : incidentType // ignore: cast_nullable_to_non_nullable
as IncidentType,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as IncidentSeverity,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as IncidentStatus,resolvedBy: freezed == resolvedBy ? _self.resolvedBy : resolvedBy // ignore: cast_nullable_to_non_nullable
as String?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolutionNotes: freezed == resolutionNotes ? _self.resolutionNotes : resolutionNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$TriggerSosRequest {

 double? get latitude; double? get longitude;
/// Create a copy of TriggerSosRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TriggerSosRequestCopyWith<TriggerSosRequest> get copyWith => _$TriggerSosRequestCopyWithImpl<TriggerSosRequest>(this as TriggerSosRequest, _$identity);

  /// Serializes this TriggerSosRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TriggerSosRequest&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude);

@override
String toString() {
  return 'TriggerSosRequest(latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $TriggerSosRequestCopyWith<$Res>  {
  factory $TriggerSosRequestCopyWith(TriggerSosRequest value, $Res Function(TriggerSosRequest) _then) = _$TriggerSosRequestCopyWithImpl;
@useResult
$Res call({
 double? latitude, double? longitude
});




}
/// @nodoc
class _$TriggerSosRequestCopyWithImpl<$Res>
    implements $TriggerSosRequestCopyWith<$Res> {
  _$TriggerSosRequestCopyWithImpl(this._self, this._then);

  final TriggerSosRequest _self;
  final $Res Function(TriggerSosRequest) _then;

/// Create a copy of TriggerSosRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(TriggerSosRequest(
latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [TriggerSosRequest].
extension TriggerSosRequestPatterns on TriggerSosRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TriggerSosRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TriggerSosRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TriggerSosRequest value)  $default,){
final _that = this;
switch (_that) {
case _TriggerSosRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TriggerSosRequest value)?  $default,){
final _that = this;
switch (_that) {
case _TriggerSosRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? latitude,  double? longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TriggerSosRequest() when $default != null:
return $default(_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? latitude,  double? longitude)  $default,) {final _that = this;
switch (_that) {
case _TriggerSosRequest():
return $default(_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? latitude,  double? longitude)?  $default,) {final _that = this;
switch (_that) {
case _TriggerSosRequest() when $default != null:
return $default(_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TriggerSosRequest implements TriggerSosRequest {
  const _TriggerSosRequest({this.latitude, this.longitude});
  factory _TriggerSosRequest.fromJson(Map<String, dynamic> json) => _$TriggerSosRequestFromJson(json);

@override final  double? latitude;
@override final  double? longitude;

/// Create a copy of TriggerSosRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TriggerSosRequestCopyWith<_TriggerSosRequest> get copyWith => __$TriggerSosRequestCopyWithImpl<_TriggerSosRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TriggerSosRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TriggerSosRequest&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude);

@override
String toString() {
  return 'TriggerSosRequest(latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$TriggerSosRequestCopyWith<$Res> implements $TriggerSosRequestCopyWith<$Res> {
  factory _$TriggerSosRequestCopyWith(_TriggerSosRequest value, $Res Function(_TriggerSosRequest) _then) = __$TriggerSosRequestCopyWithImpl;
@override @useResult
$Res call({
 double? latitude, double? longitude
});




}
/// @nodoc
class __$TriggerSosRequestCopyWithImpl<$Res>
    implements _$TriggerSosRequestCopyWith<$Res> {
  __$TriggerSosRequestCopyWithImpl(this._self, this._then);

  final _TriggerSosRequest _self;
  final $Res Function(_TriggerSosRequest) _then;

/// Create a copy of TriggerSosRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(_TriggerSosRequest(
latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$SosAlertResponse {

 String get id;/// Null for an off-trip SOS (`POST /sos`).
 String? get tripId; String get triggeredBy;@JsonKey(unknownEnumValue: SosAlertStatus.active) SosAlertStatus get status; String? get acknowledgedBy; DateTime? get acknowledgedAt; String? get resolvedBy; DateTime? get resolvedAt; String? get resolutionNotes; DateTime get createdAt;
/// Create a copy of SosAlertResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SosAlertResponseCopyWith<SosAlertResponse> get copyWith => _$SosAlertResponseCopyWithImpl<SosAlertResponse>(this as SosAlertResponse, _$identity);

  /// Serializes this SosAlertResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SosAlertResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&(identical(other.status, status) || other.status == status)&&(identical(other.acknowledgedBy, acknowledgedBy) || other.acknowledgedBy == acknowledgedBy)&&(identical(other.acknowledgedAt, acknowledgedAt) || other.acknowledgedAt == acknowledgedAt)&&(identical(other.resolvedBy, resolvedBy) || other.resolvedBy == resolvedBy)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.resolutionNotes, resolutionNotes) || other.resolutionNotes == resolutionNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tripId,triggeredBy,status,acknowledgedBy,acknowledgedAt,resolvedBy,resolvedAt,resolutionNotes,createdAt);

@override
String toString() {
  return 'SosAlertResponse(id: $id, tripId: $tripId, triggeredBy: $triggeredBy, status: $status, acknowledgedBy: $acknowledgedBy, acknowledgedAt: $acknowledgedAt, resolvedBy: $resolvedBy, resolvedAt: $resolvedAt, resolutionNotes: $resolutionNotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SosAlertResponseCopyWith<$Res>  {
  factory $SosAlertResponseCopyWith(SosAlertResponse value, $Res Function(SosAlertResponse) _then) = _$SosAlertResponseCopyWithImpl;
@useResult
$Res call({
 String id, String? tripId, String triggeredBy,@JsonKey(unknownEnumValue: SosAlertStatus.active) SosAlertStatus status, String? acknowledgedBy, DateTime? acknowledgedAt, String? resolvedBy, DateTime? resolvedAt, String? resolutionNotes, DateTime createdAt
});




}
/// @nodoc
class _$SosAlertResponseCopyWithImpl<$Res>
    implements $SosAlertResponseCopyWith<$Res> {
  _$SosAlertResponseCopyWithImpl(this._self, this._then);

  final SosAlertResponse _self;
  final $Res Function(SosAlertResponse) _then;

/// Create a copy of SosAlertResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tripId = freezed,Object? triggeredBy = null,Object? status = null,Object? acknowledgedBy = freezed,Object? acknowledgedAt = freezed,Object? resolvedBy = freezed,Object? resolvedAt = freezed,Object? resolutionNotes = freezed,Object? createdAt = null,}) {
  return _then(SosAlertResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tripId: freezed == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String?,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SosAlertStatus,acknowledgedBy: freezed == acknowledgedBy ? _self.acknowledgedBy : acknowledgedBy // ignore: cast_nullable_to_non_nullable
as String?,acknowledgedAt: freezed == acknowledgedAt ? _self.acknowledgedAt : acknowledgedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolvedBy: freezed == resolvedBy ? _self.resolvedBy : resolvedBy // ignore: cast_nullable_to_non_nullable
as String?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolutionNotes: freezed == resolutionNotes ? _self.resolutionNotes : resolutionNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SosAlertResponse].
extension SosAlertResponsePatterns on SosAlertResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SosAlertResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SosAlertResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SosAlertResponse value)  $default,){
final _that = this;
switch (_that) {
case _SosAlertResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SosAlertResponse value)?  $default,){
final _that = this;
switch (_that) {
case _SosAlertResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? tripId,  String triggeredBy, @JsonKey(unknownEnumValue: SosAlertStatus.active)  SosAlertStatus status,  String? acknowledgedBy,  DateTime? acknowledgedAt,  String? resolvedBy,  DateTime? resolvedAt,  String? resolutionNotes,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SosAlertResponse() when $default != null:
return $default(_that.id,_that.tripId,_that.triggeredBy,_that.status,_that.acknowledgedBy,_that.acknowledgedAt,_that.resolvedBy,_that.resolvedAt,_that.resolutionNotes,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? tripId,  String triggeredBy, @JsonKey(unknownEnumValue: SosAlertStatus.active)  SosAlertStatus status,  String? acknowledgedBy,  DateTime? acknowledgedAt,  String? resolvedBy,  DateTime? resolvedAt,  String? resolutionNotes,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SosAlertResponse():
return $default(_that.id,_that.tripId,_that.triggeredBy,_that.status,_that.acknowledgedBy,_that.acknowledgedAt,_that.resolvedBy,_that.resolvedAt,_that.resolutionNotes,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? tripId,  String triggeredBy, @JsonKey(unknownEnumValue: SosAlertStatus.active)  SosAlertStatus status,  String? acknowledgedBy,  DateTime? acknowledgedAt,  String? resolvedBy,  DateTime? resolvedAt,  String? resolutionNotes,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SosAlertResponse() when $default != null:
return $default(_that.id,_that.tripId,_that.triggeredBy,_that.status,_that.acknowledgedBy,_that.acknowledgedAt,_that.resolvedBy,_that.resolvedAt,_that.resolutionNotes,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SosAlertResponse implements SosAlertResponse {
  const _SosAlertResponse({required this.id, this.tripId, required this.triggeredBy, @JsonKey(unknownEnumValue: SosAlertStatus.active) required this.status, this.acknowledgedBy, this.acknowledgedAt, this.resolvedBy, this.resolvedAt, this.resolutionNotes, required this.createdAt});
  factory _SosAlertResponse.fromJson(Map<String, dynamic> json) => _$SosAlertResponseFromJson(json);

@override final  String id;
/// Null for an off-trip SOS (`POST /sos`).
@override final  String? tripId;
@override final  String triggeredBy;
@override@JsonKey(unknownEnumValue: SosAlertStatus.active) final  SosAlertStatus status;
@override final  String? acknowledgedBy;
@override final  DateTime? acknowledgedAt;
@override final  String? resolvedBy;
@override final  DateTime? resolvedAt;
@override final  String? resolutionNotes;
@override final  DateTime createdAt;

/// Create a copy of SosAlertResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SosAlertResponseCopyWith<_SosAlertResponse> get copyWith => __$SosAlertResponseCopyWithImpl<_SosAlertResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SosAlertResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SosAlertResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&(identical(other.status, status) || other.status == status)&&(identical(other.acknowledgedBy, acknowledgedBy) || other.acknowledgedBy == acknowledgedBy)&&(identical(other.acknowledgedAt, acknowledgedAt) || other.acknowledgedAt == acknowledgedAt)&&(identical(other.resolvedBy, resolvedBy) || other.resolvedBy == resolvedBy)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.resolutionNotes, resolutionNotes) || other.resolutionNotes == resolutionNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tripId,triggeredBy,status,acknowledgedBy,acknowledgedAt,resolvedBy,resolvedAt,resolutionNotes,createdAt);

@override
String toString() {
  return 'SosAlertResponse(id: $id, tripId: $tripId, triggeredBy: $triggeredBy, status: $status, acknowledgedBy: $acknowledgedBy, acknowledgedAt: $acknowledgedAt, resolvedBy: $resolvedBy, resolvedAt: $resolvedAt, resolutionNotes: $resolutionNotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SosAlertResponseCopyWith<$Res> implements $SosAlertResponseCopyWith<$Res> {
  factory _$SosAlertResponseCopyWith(_SosAlertResponse value, $Res Function(_SosAlertResponse) _then) = __$SosAlertResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String? tripId, String triggeredBy,@JsonKey(unknownEnumValue: SosAlertStatus.active) SosAlertStatus status, String? acknowledgedBy, DateTime? acknowledgedAt, String? resolvedBy, DateTime? resolvedAt, String? resolutionNotes, DateTime createdAt
});




}
/// @nodoc
class __$SosAlertResponseCopyWithImpl<$Res>
    implements _$SosAlertResponseCopyWith<$Res> {
  __$SosAlertResponseCopyWithImpl(this._self, this._then);

  final _SosAlertResponse _self;
  final $Res Function(_SosAlertResponse) _then;

/// Create a copy of SosAlertResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tripId = freezed,Object? triggeredBy = null,Object? status = null,Object? acknowledgedBy = freezed,Object? acknowledgedAt = freezed,Object? resolvedBy = freezed,Object? resolvedAt = freezed,Object? resolutionNotes = freezed,Object? createdAt = null,}) {
  return _then(_SosAlertResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tripId: freezed == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String?,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SosAlertStatus,acknowledgedBy: freezed == acknowledgedBy ? _self.acknowledgedBy : acknowledgedBy // ignore: cast_nullable_to_non_nullable
as String?,acknowledgedAt: freezed == acknowledgedAt ? _self.acknowledgedAt : acknowledgedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolvedBy: freezed == resolvedBy ? _self.resolvedBy : resolvedBy // ignore: cast_nullable_to_non_nullable
as String?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolutionNotes: freezed == resolutionNotes ? _self.resolutionNotes : resolutionNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$RateBookingRequest {

 int get score; String? get comment; int? get safety; int? get cleanliness; int? get professionalism; int? get timeliness;
/// Create a copy of RateBookingRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RateBookingRequestCopyWith<RateBookingRequest> get copyWith => _$RateBookingRequestCopyWithImpl<RateBookingRequest>(this as RateBookingRequest, _$identity);

  /// Serializes this RateBookingRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RateBookingRequest&&(identical(other.score, score) || other.score == score)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.safety, safety) || other.safety == safety)&&(identical(other.cleanliness, cleanliness) || other.cleanliness == cleanliness)&&(identical(other.professionalism, professionalism) || other.professionalism == professionalism)&&(identical(other.timeliness, timeliness) || other.timeliness == timeliness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,score,comment,safety,cleanliness,professionalism,timeliness);

@override
String toString() {
  return 'RateBookingRequest(score: $score, comment: $comment, safety: $safety, cleanliness: $cleanliness, professionalism: $professionalism, timeliness: $timeliness)';
}


}

/// @nodoc
abstract mixin class $RateBookingRequestCopyWith<$Res>  {
  factory $RateBookingRequestCopyWith(RateBookingRequest value, $Res Function(RateBookingRequest) _then) = _$RateBookingRequestCopyWithImpl;
@useResult
$Res call({
 int score, String? comment, int? safety, int? cleanliness, int? professionalism, int? timeliness
});




}
/// @nodoc
class _$RateBookingRequestCopyWithImpl<$Res>
    implements $RateBookingRequestCopyWith<$Res> {
  _$RateBookingRequestCopyWithImpl(this._self, this._then);

  final RateBookingRequest _self;
  final $Res Function(RateBookingRequest) _then;

/// Create a copy of RateBookingRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? score = null,Object? comment = freezed,Object? safety = freezed,Object? cleanliness = freezed,Object? professionalism = freezed,Object? timeliness = freezed,}) {
  return _then(RateBookingRequest(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,safety: freezed == safety ? _self.safety : safety // ignore: cast_nullable_to_non_nullable
as int?,cleanliness: freezed == cleanliness ? _self.cleanliness : cleanliness // ignore: cast_nullable_to_non_nullable
as int?,professionalism: freezed == professionalism ? _self.professionalism : professionalism // ignore: cast_nullable_to_non_nullable
as int?,timeliness: freezed == timeliness ? _self.timeliness : timeliness // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RateBookingRequest].
extension RateBookingRequestPatterns on RateBookingRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RateBookingRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RateBookingRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RateBookingRequest value)  $default,){
final _that = this;
switch (_that) {
case _RateBookingRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RateBookingRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RateBookingRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int score,  String? comment,  int? safety,  int? cleanliness,  int? professionalism,  int? timeliness)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RateBookingRequest() when $default != null:
return $default(_that.score,_that.comment,_that.safety,_that.cleanliness,_that.professionalism,_that.timeliness);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int score,  String? comment,  int? safety,  int? cleanliness,  int? professionalism,  int? timeliness)  $default,) {final _that = this;
switch (_that) {
case _RateBookingRequest():
return $default(_that.score,_that.comment,_that.safety,_that.cleanliness,_that.professionalism,_that.timeliness);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int score,  String? comment,  int? safety,  int? cleanliness,  int? professionalism,  int? timeliness)?  $default,) {final _that = this;
switch (_that) {
case _RateBookingRequest() when $default != null:
return $default(_that.score,_that.comment,_that.safety,_that.cleanliness,_that.professionalism,_that.timeliness);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RateBookingRequest implements RateBookingRequest {
  const _RateBookingRequest({required this.score, this.comment, this.safety, this.cleanliness, this.professionalism, this.timeliness});
  factory _RateBookingRequest.fromJson(Map<String, dynamic> json) => _$RateBookingRequestFromJson(json);

@override final  int score;
@override final  String? comment;
@override final  int? safety;
@override final  int? cleanliness;
@override final  int? professionalism;
@override final  int? timeliness;

/// Create a copy of RateBookingRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RateBookingRequestCopyWith<_RateBookingRequest> get copyWith => __$RateBookingRequestCopyWithImpl<_RateBookingRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RateBookingRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RateBookingRequest&&(identical(other.score, score) || other.score == score)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.safety, safety) || other.safety == safety)&&(identical(other.cleanliness, cleanliness) || other.cleanliness == cleanliness)&&(identical(other.professionalism, professionalism) || other.professionalism == professionalism)&&(identical(other.timeliness, timeliness) || other.timeliness == timeliness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,score,comment,safety,cleanliness,professionalism,timeliness);

@override
String toString() {
  return 'RateBookingRequest(score: $score, comment: $comment, safety: $safety, cleanliness: $cleanliness, professionalism: $professionalism, timeliness: $timeliness)';
}


}

/// @nodoc
abstract mixin class _$RateBookingRequestCopyWith<$Res> implements $RateBookingRequestCopyWith<$Res> {
  factory _$RateBookingRequestCopyWith(_RateBookingRequest value, $Res Function(_RateBookingRequest) _then) = __$RateBookingRequestCopyWithImpl;
@override @useResult
$Res call({
 int score, String? comment, int? safety, int? cleanliness, int? professionalism, int? timeliness
});




}
/// @nodoc
class __$RateBookingRequestCopyWithImpl<$Res>
    implements _$RateBookingRequestCopyWith<$Res> {
  __$RateBookingRequestCopyWithImpl(this._self, this._then);

  final _RateBookingRequest _self;
  final $Res Function(_RateBookingRequest) _then;

/// Create a copy of RateBookingRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? score = null,Object? comment = freezed,Object? safety = freezed,Object? cleanliness = freezed,Object? professionalism = freezed,Object? timeliness = freezed,}) {
  return _then(_RateBookingRequest(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,safety: freezed == safety ? _self.safety : safety // ignore: cast_nullable_to_non_nullable
as int?,cleanliness: freezed == cleanliness ? _self.cleanliness : cleanliness // ignore: cast_nullable_to_non_nullable
as int?,professionalism: freezed == professionalism ? _self.professionalism : professionalism // ignore: cast_nullable_to_non_nullable
as int?,timeliness: freezed == timeliness ? _self.timeliness : timeliness // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$RatingResponse {

 String get id; String get bookingId; String get tripId; String? get driverId; int get score; String? get comment; int? get safety; int? get cleanliness; int? get professionalism; int? get timeliness; DateTime get createdAt;
/// Create a copy of RatingResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RatingResponseCopyWith<RatingResponse> get copyWith => _$RatingResponseCopyWithImpl<RatingResponse>(this as RatingResponse, _$identity);

  /// Serializes this RatingResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RatingResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.score, score) || other.score == score)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.safety, safety) || other.safety == safety)&&(identical(other.cleanliness, cleanliness) || other.cleanliness == cleanliness)&&(identical(other.professionalism, professionalism) || other.professionalism == professionalism)&&(identical(other.timeliness, timeliness) || other.timeliness == timeliness)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingId,tripId,driverId,score,comment,safety,cleanliness,professionalism,timeliness,createdAt);

@override
String toString() {
  return 'RatingResponse(id: $id, bookingId: $bookingId, tripId: $tripId, driverId: $driverId, score: $score, comment: $comment, safety: $safety, cleanliness: $cleanliness, professionalism: $professionalism, timeliness: $timeliness, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RatingResponseCopyWith<$Res>  {
  factory $RatingResponseCopyWith(RatingResponse value, $Res Function(RatingResponse) _then) = _$RatingResponseCopyWithImpl;
@useResult
$Res call({
 String id, String bookingId, String tripId, String? driverId, int score, String? comment, int? safety, int? cleanliness, int? professionalism, int? timeliness, DateTime createdAt
});




}
/// @nodoc
class _$RatingResponseCopyWithImpl<$Res>
    implements $RatingResponseCopyWith<$Res> {
  _$RatingResponseCopyWithImpl(this._self, this._then);

  final RatingResponse _self;
  final $Res Function(RatingResponse) _then;

/// Create a copy of RatingResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookingId = null,Object? tripId = null,Object? driverId = freezed,Object? score = null,Object? comment = freezed,Object? safety = freezed,Object? cleanliness = freezed,Object? professionalism = freezed,Object? timeliness = freezed,Object? createdAt = null,}) {
  return _then(RatingResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,safety: freezed == safety ? _self.safety : safety // ignore: cast_nullable_to_non_nullable
as int?,cleanliness: freezed == cleanliness ? _self.cleanliness : cleanliness // ignore: cast_nullable_to_non_nullable
as int?,professionalism: freezed == professionalism ? _self.professionalism : professionalism // ignore: cast_nullable_to_non_nullable
as int?,timeliness: freezed == timeliness ? _self.timeliness : timeliness // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RatingResponse].
extension RatingResponsePatterns on RatingResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RatingResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RatingResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RatingResponse value)  $default,){
final _that = this;
switch (_that) {
case _RatingResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RatingResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RatingResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String bookingId,  String tripId,  String? driverId,  int score,  String? comment,  int? safety,  int? cleanliness,  int? professionalism,  int? timeliness,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RatingResponse() when $default != null:
return $default(_that.id,_that.bookingId,_that.tripId,_that.driverId,_that.score,_that.comment,_that.safety,_that.cleanliness,_that.professionalism,_that.timeliness,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String bookingId,  String tripId,  String? driverId,  int score,  String? comment,  int? safety,  int? cleanliness,  int? professionalism,  int? timeliness,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _RatingResponse():
return $default(_that.id,_that.bookingId,_that.tripId,_that.driverId,_that.score,_that.comment,_that.safety,_that.cleanliness,_that.professionalism,_that.timeliness,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String bookingId,  String tripId,  String? driverId,  int score,  String? comment,  int? safety,  int? cleanliness,  int? professionalism,  int? timeliness,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _RatingResponse() when $default != null:
return $default(_that.id,_that.bookingId,_that.tripId,_that.driverId,_that.score,_that.comment,_that.safety,_that.cleanliness,_that.professionalism,_that.timeliness,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RatingResponse implements RatingResponse {
  const _RatingResponse({required this.id, required this.bookingId, required this.tripId, this.driverId, required this.score, this.comment, this.safety, this.cleanliness, this.professionalism, this.timeliness, required this.createdAt});
  factory _RatingResponse.fromJson(Map<String, dynamic> json) => _$RatingResponseFromJson(json);

@override final  String id;
@override final  String bookingId;
@override final  String tripId;
@override final  String? driverId;
@override final  int score;
@override final  String? comment;
@override final  int? safety;
@override final  int? cleanliness;
@override final  int? professionalism;
@override final  int? timeliness;
@override final  DateTime createdAt;

/// Create a copy of RatingResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RatingResponseCopyWith<_RatingResponse> get copyWith => __$RatingResponseCopyWithImpl<_RatingResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RatingResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RatingResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.score, score) || other.score == score)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.safety, safety) || other.safety == safety)&&(identical(other.cleanliness, cleanliness) || other.cleanliness == cleanliness)&&(identical(other.professionalism, professionalism) || other.professionalism == professionalism)&&(identical(other.timeliness, timeliness) || other.timeliness == timeliness)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingId,tripId,driverId,score,comment,safety,cleanliness,professionalism,timeliness,createdAt);

@override
String toString() {
  return 'RatingResponse(id: $id, bookingId: $bookingId, tripId: $tripId, driverId: $driverId, score: $score, comment: $comment, safety: $safety, cleanliness: $cleanliness, professionalism: $professionalism, timeliness: $timeliness, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RatingResponseCopyWith<$Res> implements $RatingResponseCopyWith<$Res> {
  factory _$RatingResponseCopyWith(_RatingResponse value, $Res Function(_RatingResponse) _then) = __$RatingResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String bookingId, String tripId, String? driverId, int score, String? comment, int? safety, int? cleanliness, int? professionalism, int? timeliness, DateTime createdAt
});




}
/// @nodoc
class __$RatingResponseCopyWithImpl<$Res>
    implements _$RatingResponseCopyWith<$Res> {
  __$RatingResponseCopyWithImpl(this._self, this._then);

  final _RatingResponse _self;
  final $Res Function(_RatingResponse) _then;

/// Create a copy of RatingResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookingId = null,Object? tripId = null,Object? driverId = freezed,Object? score = null,Object? comment = freezed,Object? safety = freezed,Object? cleanliness = freezed,Object? professionalism = freezed,Object? timeliness = freezed,Object? createdAt = null,}) {
  return _then(_RatingResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,safety: freezed == safety ? _self.safety : safety // ignore: cast_nullable_to_non_nullable
as int?,cleanliness: freezed == cleanliness ? _self.cleanliness : cleanliness // ignore: cast_nullable_to_non_nullable
as int?,professionalism: freezed == professionalism ? _self.professionalism : professionalism // ignore: cast_nullable_to_non_nullable
as int?,timeliness: freezed == timeliness ? _self.timeliness : timeliness // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
