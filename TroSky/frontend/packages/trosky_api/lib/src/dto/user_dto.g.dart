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
