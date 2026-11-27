// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfileResponse _$UserProfileResponseFromJson(Map<String, dynamic> json) =>
    _UserProfileResponse(
      fullName: json['full_name'] as String,
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth'] as String),
      gender: json['gender'] as String?,
      preferredLanguage: json['preferred_language'] as String,
      avatarUrl: json['avatar_url'] as String?,
      ghanaCardNumber: json['ghana_card_number'] as String?,
      ghanaCardVerified: json['ghana_card_verified'] as bool,
    );

Map<String, dynamic> _$UserProfileResponseToJson(
  _UserProfileResponse instance,
) => <String, dynamic>{
  'full_name': instance.fullName,
  'date_of_birth': ?instance.dateOfBirth?.toIso8601String(),
  'gender': ?instance.gender,
  'preferred_language': instance.preferredLanguage,
  'avatar_url': ?instance.avatarUrl,
  'ghana_card_number': ?instance.ghanaCardNumber,
  'ghana_card_verified': instance.ghanaCardVerified,
};

_UserResponse _$UserResponseFromJson(Map<String, dynamic> json) =>
    _UserResponse(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String?,
      isActive: json['is_active'] as bool,
      phoneVerified: json['phone_verified'] as bool,
      emailVerified: json['email_verified'] as bool,
      roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profile'] == null
          ? null
          : UserProfileResponse.fromJson(
              json['profile'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$UserResponseToJson(_UserResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phone_number': instance.phoneNumber,
      'email': ?instance.email,
      'is_active': instance.isActive,
      'phone_verified': instance.phoneVerified,
      'email_verified': instance.emailVerified,
      'roles': instance.roles,
      'created_at': instance.createdAt.toIso8601String(),
      'profile': ?instance.profile?.toJson(),
    };

_UserProfileUpdateRequest _$UserProfileUpdateRequestFromJson(
  Map<String, dynamic> json,
) => _UserProfileUpdateRequest(
  fullName: json['full_name'] as String?,
  dateOfBirth: json['date_of_birth'] == null
      ? null
      : DateTime.parse(json['date_of_birth'] as String),
  gender: json['gender'] as String?,
  preferredLanguage: json['preferred_language'] as String?,
  avatarUrl: json['avatar_url'] as String?,
);

Map<String, dynamic> _$UserProfileUpdateRequestToJson(
  _UserProfileUpdateRequest instance,
) => <String, dynamic>{
  'full_name': ?instance.fullName,
  'date_of_birth': ?instance.dateOfBirth?.toIso8601String(),
  'gender': ?instance.gender,
  'preferred_language': ?instance.preferredLanguage,
  'avatar_url': ?instance.avatarUrl,
};

_AccountDeletionRequest _$AccountDeletionRequestFromJson(
  Map<String, dynamic> json,
) => _AccountDeletionRequest(
  password: json['password'] as String,
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$AccountDeletionRequestToJson(
  _AccountDeletionRequest instance,
) => <String, dynamic>{
  'password': instance.password,
  'reason': ?instance.reason,
};

_ChangePasswordRequest _$ChangePasswordRequestFromJson(
  Map<String, dynamic> json,
) => _ChangePasswordRequest(
  currentPassword: json['current_password'] as String,
  newPassword: json['new_password'] as String,
);

Map<String, dynamic> _$ChangePasswordRequestToJson(
  _ChangePasswordRequest instance,
) => <String, dynamic>{
  'current_password': instance.currentPassword,
  'new_password': instance.newPassword,
};

_ChangeEmailRequest _$ChangeEmailRequestFromJson(Map<String, dynamic> json) =>
    _ChangeEmailRequest(
      newEmail: json['new_email'] as String,
      currentPassword: json['current_password'] as String,
    );

Map<String, dynamic> _$ChangeEmailRequestToJson(_ChangeEmailRequest instance) =>
    <String, dynamic>{
      'new_email': instance.newEmail,
      'current_password': instance.currentPassword,
    };

_EmailChangeStartedResponse _$EmailChangeStartedResponseFromJson(
  Map<String, dynamic> json,
) => _EmailChangeStartedResponse(
  message: json['message'] as String,
  otpSentTo: json['otp_sent_to'] as String,
  expiresInSeconds: (json['expires_in_seconds'] as num).toInt(),
);

Map<String, dynamic> _$EmailChangeStartedResponseToJson(
  _EmailChangeStartedResponse instance,
) => <String, dynamic>{
  'message': instance.message,
  'otp_sent_to': instance.otpSentTo,
  'expires_in_seconds': instance.expiresInSeconds,
};

_ChangeEmailConfirmRequest _$ChangeEmailConfirmRequestFromJson(
  Map<String, dynamic> json,
) => _ChangeEmailConfirmRequest(
  newEmail: json['new_email'] as String,
  code: json['code'] as String,
);

Map<String, dynamic> _$ChangeEmailConfirmRequestToJson(
  _ChangeEmailConfirmRequest instance,
) => <String, dynamic>{'new_email': instance.newEmail, 'code': instance.code};

_FavouriteRouteCreateRequest _$FavouriteRouteCreateRequestFromJson(
  Map<String, dynamic> json,
) => _FavouriteRouteCreateRequest(
  originStopId: json['origin_stop_id'] as String,
  destinationStopId: json['destination_stop_id'] as String,
  label: json['label'] as String?,
);

Map<String, dynamic> _$FavouriteRouteCreateRequestToJson(
  _FavouriteRouteCreateRequest instance,
) => <String, dynamic>{
  'origin_stop_id': instance.originStopId,
  'destination_stop_id': instance.destinationStopId,
  'label': ?instance.label,
};

_FavouriteRouteResponse _$FavouriteRouteResponseFromJson(
  Map<String, dynamic> json,
) => _FavouriteRouteResponse(
  id: json['id'] as String,
  originStopId: json['origin_stop_id'] as String,
  originStopName: json['origin_stop_name'] as String,
  destinationStopId: json['destination_stop_id'] as String,
  destinationStopName: json['destination_stop_name'] as String,
  label: json['label'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$FavouriteRouteResponseToJson(
  _FavouriteRouteResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'origin_stop_id': instance.originStopId,
  'origin_stop_name': instance.originStopName,
  'destination_stop_id': instance.destinationStopId,
  'destination_stop_name': instance.destinationStopName,
  'label': ?instance.label,
  'created_at': instance.createdAt.toIso8601String(),
};
