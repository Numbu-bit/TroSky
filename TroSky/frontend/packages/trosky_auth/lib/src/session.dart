import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

import 'providers.dart';
import 'token_manager.dart';

part 'session.g.dart';

/// Who is signed in. While the session is being restored at app start the
/// controller is loading: that is the "unknown" state.
sealed class SessionState {
  const SessionState();
}

/// Nobody is signed in.
final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

/// Signed in as [user].
final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);

  final UserResponse user;

  /// Role slugs from the backend, e.g. `passenger`, `driver`.
  List<String> get roles => user.roles;
}

/// There was a session, but the backend ended it ([reason]): logged out
/// elsewhere, token reuse, suspension. The user has to sign in again.
final class SessionExpired extends SessionState {
  const SessionExpired(this.reason);

  final AppFailure reason;
}

/// Riverpod retries a failed provider on its own, and `.future` waits
/// through the retries. A restore that fails offline must fail at once, so
/// the app can move on and offer [SessionController.restore].
Duration? _noRetry(int retryCount, Object error) => null;

/// The session: restores it on app start and signs in and out.
///
/// On start, a saved refresh token is exchanged for a new pair and the user
/// is loaded. If the network is down the state is an error (the saved
/// session is kept); [restore] tries again.
@Riverpod(keepAlive: true, retry: _noRetry)
class SessionController extends _$SessionController {
  @override
  Future<SessionState> build() async {
    final tokens = ref.watch(tokenManagerProvider);
    final ended = tokens.sessionEnded.listen((reason) {
      if (state.value is SessionAuthenticated) {
        state = AsyncData(SessionExpired(reason));
      }
    });
    ref.onDispose(ended.cancel);
    return _restore(tokens);
  }

  TokenManager get _tokens => ref.read(tokenManagerProvider);

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Tries the start-up restore again, e.g. after a network failure.
  Future<void> restore() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _restore(_tokens));
  }

  Future<SessionState> _restore(TokenManager tokens) async {
    if (!await tokens.hasSavedSession) return const SessionUnauthenticated();
    final refreshed = await tokens.refresh();
    if (refreshed case Err(:final failure)) {
      // A network failure keeps the saved session for the next attempt.
      if (!TokenManager.endsSession(failure)) throw failure;
      return SessionExpired(failure);
    }
    return _loadUser();
  }

  Future<SessionState> _loadUser() async {
    final me = await ref.read(userRepositoryProvider).getMe();
    switch (me) {
      case Ok(:final value):
        return SessionAuthenticated(value);
      case Err(:final failure):
        if (!TokenManager.endsSession(failure)) throw failure;
        await _tokens.clear();
        return SessionExpired(failure);
    }
  }

  /// Signs in with a phone number (any form) or email and a password.
  Future<Result<UserResponse>> signIn({
    required String identifier,
    required String password,
    DeviceContext? device,
  }) async => _start(
    await _auth.login(
      LoginRequest(identifier: identifier, password: password, device: device),
    ),
  );

  /// Signs in with a code from `resendOtp(purpose: login)`.
  Future<Result<UserResponse>> signInWithOtp({
    required String target,
    required String code,
    DeviceContext? device,
  }) async => _start(
    await _auth.otpLogin(
      OtpLoginRequest(target: target, code: code, device: device),
    ),
  );

  /// Creates the account and sends the code. Verify it with
  /// [verifyRegistration], using [RegisterResponse.otpSentTo] as the target.
  Future<Result<RegisterResponse>> register(RegisterRequest request) =>
      _auth.register(request);

  /// Verifies the registration code, then signs in with the phone and
  /// password just entered: verify-otp returns no tokens.
  Future<Result<UserResponse>> verifyRegistration({
    required String otpTarget,
    required String code,
    required String phone,
    required String password,
  }) async {
    final verified = await _auth.verifyOtp(
      VerifyOtpRequest(
        target: otpTarget,
        purpose: OtpPurpose.registration,
        code: code,
      ),
    );
    if (verified case Err(:final failure)) return Err(failure);
    return signIn(identifier: phone, password: password);
  }

  /// Signs out this device.
  ///
  /// The saved refresh token is deleted first: once the backend has
  /// revoked the session it would treat that token as stolen if it were
  /// ever used, and revoke every session of the account. The logout call
  /// is best-effort; offline, the session simply expires on the server.
  Future<void> signOut() async {
    await _tokens.forgetRefreshToken();
    await _auth.logout();
    await _tokens.clear();
    state = const AsyncData(SessionUnauthenticated());
  }

  Future<Result<UserResponse>> _start(Result<TokenPairResponse> login) async {
    if (login case Err(:final failure)) return Err(failure);
    await _tokens.save(login.valueOrNull!);
    final me = await ref.read(userRepositoryProvider).getMe();
    switch (me) {
      case Ok(:final value):
        state = AsyncData(SessionAuthenticated(value));
      case Err():
        await _tokens.clear();
    }
    return me;
  }
}
