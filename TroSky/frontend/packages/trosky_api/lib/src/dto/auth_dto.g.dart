// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    _RegisterRequest(
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String?,
      password: json['password'] as String,
      fullName: json['full_name'] as String,
      role:
          $enumDecodeNullable(_$RegistrableRoleEnumMap, json['role']) ??
          RegistrableRole.passenger,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
    );

Map<String, dynamic> _$RegisterRequestToJson(_RegisterRequest instance) =>
    <String, dynamic>{
      'phone_number': instance.phoneNumber,
      'email': ?instance.email,
      'password': instance.password,
      'full_name': instance.fullName,
      'role': _$RegistrableRoleEnumMap[instance.role]!,
      'preferred_language': instance.preferredLanguage,
    };

const _$RegistrableRoleEnumMap = {
  RegistrableRole.passenger: 'passenger',
  RegistrableRole.driver: 'driver',
  RegistrableRole.fleetOwner: 'fleet_owner',
};

_RegisterResponse _$RegisterResponseFromJson(Map<String, dynamic> json) =>
    _RegisterResponse(
      userId: json['user_id'] as String,
      phoneNumber: json['phone_number'] as String,
      otpSentTo: json['otp_sent_to'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$RegisterResponseToJson(_RegisterResponse instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'phone_number': instance.phoneNumber,
      'otp_sent_to': instance.otpSentTo,
      'message': instance.message,
    };

_VerifyOtpRequest _$VerifyOtpRequestFromJson(Map<String, dynamic> json) =>
    _VerifyOtpRequest(
      target: json['target'] as String,
      purpose: $enumDecode(_$OtpPurposeEnumMap, json['purpose']),
      code: json['code'] as String,
    );

Map<String, dynamic> _$VerifyOtpRequestToJson(_VerifyOtpRequest instance) =>
    <String, dynamic>{
      'target': instance.target,
      'purpose': _$OtpPurposeEnumMap[instance.purpose]!,
      'code': instance.code,
    };

const _$OtpPurposeEnumMap = {
  OtpPurpose.registration: 'registration',
  OtpPurpose.login: 'login',
  OtpPurpose.passwordReset: 'password_reset',
  OtpPurpose.phoneVerification: 'phone_verification',
  OtpPurpose.emailVerification: 'email_verification',
};

_ResendOtpRequest _$ResendOtpRequestFromJson(Map<String, dynamic> json) =>
    _ResendOtpRequest(
      target: json['target'] as String,
      purpose: $enumDecode(_$OtpPurposeEnumMap, json['purpose']),
      channel:
          $enumDecodeNullable(_$OtpChannelEnumMap, json['channel']) ??
          OtpChannel.sms,
    );

Map<String, dynamic> _$ResendOtpRequestToJson(_ResendOtpRequest instance) =>
    <String, dynamic>{
      'target': instance.target,
      'purpose': _$OtpPurposeEnumMap[instance.purpose]!,
      'channel': _$OtpChannelEnumMap[instance.channel]!,
    };

const _$OtpChannelEnumMap = {OtpChannel.sms: 'sms', OtpChannel.email: 'email'};

_DeviceContext _$DeviceContextFromJson(Map<String, dynamic> json) =>
    _DeviceContext(
      deviceId: json['device_id'] as String?,
      deviceName: json['device_name'] as String?,
      platform: $enumDecodeNullable(_$DevicePlatformEnumMap, json['platform']),
      pushToken: json['push_token'] as String?,
    );

Map<String, dynamic> _$DeviceContextToJson(_DeviceContext instance) =>
    <String, dynamic>{
      'device_id': ?instance.deviceId,
      'device_name': ?instance.deviceName,
      'platform': ?_$DevicePlatformEnumMap[instance.platform],
      'push_token': ?instance.pushToken,
    };

const _$DevicePlatformEnumMap = {
  DevicePlatform.ios: 'ios',
  DevicePlatform.android: 'android',
  DevicePlatform.web: 'web',
};

_LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) =>
    _LoginRequest(
      identifier: json['identifier'] as String,
      password: json['password'] as String,
      device: json['device'] == null
          ? null
          : DeviceContext.fromJson(json['device'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LoginRequestToJson(_LoginRequest instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'password': instance.password,
      'device': ?instance.device?.toJson(),
    };

_OtpLoginRequest _$OtpLoginRequestFromJson(Map<String, dynamic> json) =>
    _OtpLoginRequest(
      target: json['target'] as String,
      code: json['code'] as String,
      device: json['device'] == null
          ? null
          : DeviceContext.fromJson(json['device'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OtpLoginRequestToJson(_OtpLoginRequest instance) =>
    <String, dynamic>{
      'target': instance.target,
      'code': instance.code,
      'device': ?instance.device?.toJson(),
    };

_RefreshRequest _$RefreshRequestFromJson(Map<String, dynamic> json) =>
    _RefreshRequest(refreshToken: json['refresh_token'] as String);

Map<String, dynamic> _$RefreshRequestToJson(_RefreshRequest instance) =>
    <String, dynamic>{'refresh_token': instance.refreshToken};

_TokenPairResponse _$TokenPairResponseFromJson(Map<String, dynamic> json) =>
    _TokenPairResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: (json['expires_in'] as num).toInt(),
      sessionId: json['session_id'] as String,
    );

Map<String, dynamic> _$TokenPairResponseToJson(_TokenPairResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
      'session_id': instance.sessionId,
    };

_MessageResponse _$MessageResponseFromJson(Map<String, dynamic> json) =>
    _MessageResponse(message: json['message'] as String);

Map<String, dynamic> _$MessageResponseToJson(_MessageResponse instance) =>
    <String, dynamic>{'message': instance.message};
