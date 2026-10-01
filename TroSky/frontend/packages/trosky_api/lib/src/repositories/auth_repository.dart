import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/auth_dto.dart';

/// `/auth/*` (backend/app/api/v1/auth.py).
abstract interface class AuthRepository {
  /// 201 with where the code went. Fails with `PHONE_ALREADY_REGISTERED`,
  /// `EMAIL_ALREADY_REGISTERED`, `PASSWORD_POLICY_VIOLATION`,
  /// `EMAIL_REQUIRED`, `EMAIL_DOMAIN_NOT_ALLOWED` or `VALIDATION_ERROR`.
  Future<Result<RegisterResponse>> register(RegisterRequest request);

  /// Fails with `OTP_NOT_FOUND`, `OTP_EXPIRED`, `OTP_INVALID` or
  /// `OTP_ATTEMPTS_EXCEEDED`. Returns no tokens.
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest request);

  /// Succeeds the same way whether or not the target has an account; a
  /// code is only sent to an account. `RATE_LIMIT_EXCEEDED` during the
  /// resend cooldown.
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest request);

  /// Fails with `INVALID_CREDENTIALS`, `ACCOUNT_NOT_VERIFIED`,
  /// `ACCOUNT_LOCKED` or `ACCOUNT_SUSPENDED`.
  Future<Result<TokenPairResponse>> login(LoginRequest request);

  /// Fails with `NOT_FOUND` for a target with no account (before the code
  /// is checked), then as [verifyOtp].
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest request);

  /// Rotates the refresh token. `REFRESH_TOKEN_REUSE_DETECTED` means the
  /// token had already been used and every session was revoked.
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request);

  /// Revokes this device's session, refresh tokens included.
  Future<Result<void>> logout();
}

/// [AuthRepository] against the backend.
class LiveAuthRepository implements AuthRepository {
  LiveAuthRepository(this._dio);

  final Dio _dio;

  Future<Result<T>> _post<T>(
    String path,
    Object body,
    T Function(Map<String, dynamic>) parse,
  ) => apiCall(
    () => _dio.post<Object?>(path, data: body, options: publicEndpoint()),
    (data) => parse(jsonObject(data)),
  );

  @override
  Future<Result<RegisterResponse>> register(RegisterRequest request) =>
      _post('/auth/register', request.toJson(), RegisterResponse.fromJson);

  @override
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest request) =>
      _post('/auth/verify-otp', request.toJson(), MessageResponse.fromJson);

  @override
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest request) =>
      _post('/auth/resend-otp', request.toJson(), MessageResponse.fromJson);

  @override
  Future<Result<TokenPairResponse>> login(LoginRequest request) =>
      _post('/auth/login', request.toJson(), TokenPairResponse.fromJson);

  @override
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest request) =>
      _post('/auth/otp-login', request.toJson(), TokenPairResponse.fromJson);

  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request) =>
      _post('/auth/refresh', request.toJson(), TokenPairResponse.fromJson);

  @override
  Future<Result<void>> logout() =>
      apiCall(() => _dio.post<Object?>('/auth/logout'), (_) {});
}
