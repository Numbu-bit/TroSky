import 'package:trosky_core/trosky_core.dart';

import '../client/interceptors.dart';
import '../dto/auth_dto.dart';
import '../dto/user_dto.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import 'mock_backend.dart';

/// Runs an authenticated [MockBackend] call the way the live client does:
/// with the current access token, refreshing once on an expired token.
Future<Result<T>> _authenticated<T>(
  SessionTokens tokens,
  Duration latency,
  Result<T> Function(String? accessToken) call,
) async {
  if (latency > Duration.zero) await Future<void>.delayed(latency);
  final first = call(tokens.accessToken);
  if (first.failureOrNull?.code != 'UNAUTHORIZED' ||
      tokens.accessToken == null) {
    return first;
  }
  final refreshed = await tokens.refresh();
  return switch (refreshed) {
    Ok(:final value) => call(value),
    Err(:final failure) => Err(failure),
  };
}

/// [AuthRepository] on a [MockBackend] (`API_MODE=mock`).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;

  /// How long each call takes, to see loading states.
  final Duration latency;

  Future<Result<T>> _call<T>(Result<T> Function() call) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return call();
  }

  @override
  Future<Result<RegisterResponse>> register(RegisterRequest request) =>
      _call(() => _backend.register(request));

  @override
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest request) =>
      _call(() => _backend.verifyOtp(request));

  @override
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest request) =>
      _call(() => _backend.resendOtp(request));

  @override
  Future<Result<TokenPairResponse>> login(LoginRequest request) =>
      _call(() => _backend.login(request));

  @override
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest request) =>
      _call(() => _backend.otpLogin(request));

  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request) =>
      _call(() => _backend.refresh(request));

  @override
  Future<Result<void>> logout() =>
      _authenticated(_tokens(), latency, _backend.logout);
}

/// [UserRepository] on a [MockBackend] (`API_MODE=mock`).
class MockUserRepository implements UserRepository {
  MockUserRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;
  final Duration latency;

  @override
  Future<Result<UserResponse>> getMe() =>
      _authenticated(_tokens(), latency, _backend.getMe);
}
