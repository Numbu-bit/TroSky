// Request and response bodies of /auth/*, field for field as in
// backend/app/schemas/auth.py. JSON keys are snake_case (see build.yaml).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_dto.freezed.dart';
part 'auth_dto.g.dart';

/// `RegistrableRole`: roles open to self-registration.
@JsonEnum(fieldRename: FieldRename.snake)
enum RegistrableRole { passenger, driver, fleetOwner }

/// `OtpPurpose`.
@JsonEnum(fieldRename: FieldRename.snake)
enum OtpPurpose {
  registration,
  login,
  passwordReset,
  phoneVerification,
  emailVerification,
}

/// `OtpChannel`.
@JsonEnum(fieldRename: FieldRename.snake)
enum OtpChannel { sms, email }

/// `DevicePlatform`.
@JsonEnum(fieldRename: FieldRename.snake)
enum DevicePlatform { ios, android, web }

/// `POST /auth/register`. [phoneNumber] may be in any form the backend
/// accepts; [email] must be on an allowed domain (Gmail by default).
/// A passenger also sends where they are now ([latitude] and [longitude],
/// both or neither): the backend only lets passengers sign up in the
/// countries TroSky serves (`PASSENGER_SIGNUP_COUNTRIES`, Ghana). It checks
/// the position and doesn't keep it; the app doesn't keep it either.
@freezed
abstract class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest({
    required String phoneNumber,
    String? email,
    required String password,
    required String fullName,
    @Default(RegistrableRole.passenger) RegistrableRole role,
    @Default('en') String preferredLanguage,
    double? latitude,
    double? longitude,
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
}

/// 201 from `POST /auth/register`. [otpSentTo] is where the code went, the
/// phone or (when codes go by email) the email address, and is the
/// `target` to verify it with.
@freezed
abstract class RegisterResponse with _$RegisterResponse {
  const factory RegisterResponse({
    required String userId,
    required String phoneNumber,
    required String otpSentTo,
    required String message,
  }) = _RegisterResponse;

  factory RegisterResponse.fromJson(Map<String, dynamic> json) =>
      _$RegisterResponseFromJson(json);
}

/// `POST /auth/verify-otp`.
@freezed
abstract class VerifyOtpRequest with _$VerifyOtpRequest {
  const factory VerifyOtpRequest({
    required String target,
    required OtpPurpose purpose,
    required String code,
  }) = _VerifyOtpRequest;

  factory VerifyOtpRequest.fromJson(Map<String, dynamic> json) =>
      _$VerifyOtpRequestFromJson(json);
}

/// `POST /auth/resend-otp`.
@freezed
abstract class ResendOtpRequest with _$ResendOtpRequest {
  const factory ResendOtpRequest({
    required String target,
    required OtpPurpose purpose,
    @Default(OtpChannel.sms) OtpChannel channel,
  }) = _ResendOtpRequest;

  factory ResendOtpRequest.fromJson(Map<String, dynamic> json) =>
      _$ResendOtpRequestFromJson(json);
}

/// The device a login comes from. With all of [deviceId], [platform] and
/// [pushToken], the backend also registers the device for push.
@freezed
abstract class DeviceContext with _$DeviceContext {
  const factory DeviceContext({
    String? deviceId,
    String? deviceName,
    DevicePlatform? platform,
    String? pushToken,
  }) = _DeviceContext;

  factory DeviceContext.fromJson(Map<String, dynamic> json) =>
      _$DeviceContextFromJson(json);
}

/// `POST /auth/login`. [identifier] is a phone number (any form) or email.
@freezed
abstract class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String identifier,
    required String password,
    DeviceContext? device,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

/// `POST /auth/otp-login`, after `resend-otp` with purpose `login`.
@freezed
abstract class OtpLoginRequest with _$OtpLoginRequest {
  const factory OtpLoginRequest({
    required String target,
    required String code,
    DeviceContext? device,
  }) = _OtpLoginRequest;

  factory OtpLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$OtpLoginRequestFromJson(json);
}

/// `POST /auth/refresh`.
@freezed
abstract class RefreshRequest with _$RefreshRequest {
  const factory RefreshRequest({required String refreshToken}) =
      _RefreshRequest;

  factory RefreshRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshRequestFromJson(json);
}

/// Login and refresh both answer with a new pair. [expiresIn] is the access
/// token's lifetime in seconds. The refresh token rotates: the one sent is
/// dead once this arrives.
@freezed
abstract class TokenPairResponse with _$TokenPairResponse {
  const factory TokenPairResponse({
    required String accessToken,
    required String refreshToken,
    @Default('bearer') String tokenType,
    required int expiresIn,
    required String sessionId,
  }) = _TokenPairResponse;

  factory TokenPairResponse.fromJson(Map<String, dynamic> json) =>
      _$TokenPairResponseFromJson(json);
}

/// `MessageResponse`, e.g. from verify-otp and resend-otp.
@freezed
abstract class MessageResponse with _$MessageResponse {
  const factory MessageResponse({required String message}) = _MessageResponse;

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      _$MessageResponseFromJson(json);
}
