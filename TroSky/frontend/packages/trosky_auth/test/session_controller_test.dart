import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import 'support.dart';

/// An [AuthRepository] whose refresh can be switched to fail offline.
class _FlakyAuth implements AuthRepository {
  _FlakyAuth(this._inner);

  final AuthRepository _inner;
  bool offline = true;

  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request) async =>
      offline ? const Err(NetworkFailure()) : _inner.refresh(request);

  @override
  Future<Result<RegisterResponse>> register(RegisterRequest r) =>
      _inner.register(r);
  @override
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest r) =>
      _inner.verifyOtp(r);
  @override
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest r) =>
      _inner.resendOtp(r);
  @override
  Future<Result<TokenPairResponse>> login(LoginRequest r) => _inner.login(r);
  @override
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest r) =>
      _inner.otpLogin(r);
  @override
  Future<Result<void>> logout() => _inner.logout();
}

void main() {
  late MockBackend backend;
  late InMemoryRefreshTokenStore store;
  late InMemoryUserCache cache;

  setUp(() {
    backend = MockBackend();
    store = InMemoryRefreshTokenStore();
    cache = InMemoryUserCache();
  });

  ProviderContainer start({List<Object> extra = const []}) =>
      appContainer(backend: backend, store: store, cache: cache, extra: extra);

  Future<SessionState> session(ProviderContainer c) =>
      c.read(sessionControllerProvider.future);

  SessionController controller(ProviderContainer c) =>
      c.read(sessionControllerProvider.notifier);

  Future<void> signInAsPassenger(ProviderContainer c) async {
    await session(c);
    final result = await controller(
      c,
    ).signIn(identifier: '0241234567', password: MockBackend.seedPassword);
    expect(result.isOk, isTrue);
  }

  group('restore on app start', () {
    test('nothing saved: unauthenticated', () async {
      expect(await session(start()), isA<SessionUnauthenticated>());
    });

    test('a saved session comes back with the user and roles', () async {
      await signInAsPassenger(start());
      final saved = store.token;

      // The app starts again.
      final state = await session(start());

      expect(state, isA<SessionAuthenticated>());
      expect((state as SessionAuthenticated).roles, ['passenger']);
      expect(state.user.profile?.fullName, 'Ama Mensah');
      // The refresh token was rotated and the new one saved.
      expect(store.token, isNot(saved));
    });

    test('a session ended elsewhere: expired, and the token is gone', () async {
      await signInAsPassenger(start());
      // The same refresh token used twice: the backend calls it theft.
      final stolen = store.token!;
      backend.refresh(RefreshRequest(refreshToken: stolen));

      final state = await session(start());

      expect(state, isA<SessionExpired>());
      expect(
        (state as SessionExpired).reason.code,
        'REFRESH_TOKEN_REUSE_DETECTED',
      );
      expect(store.token, isNull);
    });

    ProviderContainer offlineStart(
      _FlakyAuth Function(SessionTokens Function()) make,
    ) {
      late final ProviderContainer container;
      final flaky = make(() => container.read(tokenManagerProvider));
      container = start(
        extra: [authRepositoryProvider.overrideWithValue(flaky)],
      );
      return container;
    }

    test('offline: opens as the last user seen, then checks again', () async {
      await signInAsPassenger(start());
      late _FlakyAuth flaky;
      final container = offlineStart(
        (tokens) =>
            flaky = _FlakyAuth(MockAuthRepository(backend, tokens: tokens)),
      );

      final offline = await session(container);
      expect(offline, isA<SessionAuthenticated>());
      expect((offline as SessionAuthenticated).offline, isTrue);
      expect(offline.user.profile?.fullName, 'Ama Mensah');
      expect(store.token, isNotNull);

      flaky.offline = false;
      await controller(container).restore();
      final online = container.read(sessionControllerProvider).value;
      expect((online! as SessionAuthenticated).offline, isFalse);
    });

    test('offline with nothing cached: an error, the session kept', () async {
      await signInAsPassenger(start());
      cache.user = null;
      final container = offlineStart(
        (tokens) => _FlakyAuth(MockAuthRepository(backend, tokens: tokens)),
      );

      await expectLater(session(container), throwsA(isA<NetworkFailure>()));
      expect(store.token, isNotNull);
    });

    test('a suspended account is signed out on start', () async {
      await signInAsPassenger(start());
      backend.suspend('0241234567');

      final state = await session(start());

      expect(state, isA<SessionExpired>());
      expect((state as SessionExpired).reason, isA<AccountSuspendedFailure>());
      expect(store.token, isNull);
      expect(cache.user, isNull);
    });
  });

  group('sign in', () {
    test('a wrong password changes nothing', () async {
      final c = start();
      await session(c);
      final result = await controller(
        c,
      ).signIn(identifier: '0241234567', password: 'wrong');
      expect(result.failureOrNull?.code, 'INVALID_CREDENTIALS');
      expect(
        c.read(sessionControllerProvider).value,
        isA<SessionUnauthenticated>(),
      );
      expect(store.token, isNull);
    });

    test('with a one-time code', () async {
      final c = start();
      await session(c);
      await c
          .read(authRepositoryProvider)
          .resendOtp(
            const ResendOtpRequest(
              target: '0201234567',
              purpose: OtpPurpose.login,
            ),
          );
      final result = await controller(
        c,
      ).signInWithOtp(target: '0201234567', code: MockBackend.otpCode);
      expect(result.valueOrNull?.roles, ['driver']);
    });
  });

  group('sign up', () {
    Future<Result<UserResponse>> signUp(
      ProviderContainer c, {
      RegistrableRole role = RegistrableRole.passenger,
    }) async {
      await session(c);
      final registered = await controller(c).register(
        RegisterRequest(
          phoneNumber: '055 123 4567',
          email: 'efua.owusu@gmail.com',
          password: 'Kumasi2026',
          fullName: 'Efua Owusu',
          role: role,
          // In Kumasi: passengers sign up in Ghana only.
          latitude: 6.6885,
          longitude: -1.6244,
        ),
      );
      return controller(c).verifyRegistration(
        otpTarget: registered.valueOrNull!.otpSentTo,
        code: MockBackend.otpCode,
        identifier: '055 123 4567',
        password: 'Kumasi2026',
      );
    }

    test(
      'verify then sign in silently with the details just entered',
      () async {
        final c = start();
        final result = await signUp(c);

        expect(result.valueOrNull?.phoneNumber, '+233551234567');
        final state = c.read(sessionControllerProvider).value;
        expect(state, isA<SessionAuthenticated>());
        expect((state as SessionAuthenticated).roles, ['passenger']);
        expect(store.token, isNotNull);
      },
    );

    test('as a driver', () async {
      final c = start();
      await signUp(c, role: RegistrableRole.driver);
      final state = c.read(sessionControllerProvider).value!;
      expect(sessionAllowsMode(state, AppMode.driver), isTrue);
      expect(sessionAllowsMode(state, AppMode.passenger), isFalse);
    });

    test('a wrong code stops before signing in', () async {
      final c = start();
      await session(c);
      final registered = await controller(c).register(
        const RegisterRequest(
          phoneNumber: '0551234567',
          email: 'efua.owusu@gmail.com',
          password: 'Kumasi2026',
          fullName: 'Efua Owusu',
          latitude: 6.6885,
          longitude: -1.6244,
        ),
      );
      final result = await controller(c).verifyRegistration(
        otpTarget: registered.valueOrNull!.otpSentTo,
        code: '000000',
        identifier: '0551234567',
        password: 'Kumasi2026',
      );
      expect(result.failureOrNull?.code, 'OTP_INVALID');
      expect(
        c.read(sessionControllerProvider).value,
        isA<SessionUnauthenticated>(),
      );
    });
  });

  test('sign out revokes only this session and forgets the token', () async {
    final c = start();
    await signInAsPassenger(c);
    // The same account on another phone.
    backend.login(
      const LoginRequest(
        identifier: '0241234567',
        password: MockBackend.seedPassword,
      ),
    );
    expect(backend.activeSessions('0241234567'), 2);

    await controller(c).signOut();

    expect(
      c.read(sessionControllerProvider).value,
      isA<SessionUnauthenticated>(),
    );
    expect(store.token, isNull);
    expect(c.read(tokenManagerProvider).accessToken, isNull);
    // No reuse alarm: the other phone is still signed in.
    expect(backend.activeSessions('0241234567'), 1);
  });

  test('an expired access token is refreshed during use', () async {
    final c = start();
    await signInAsPassenger(c);
    final before = store.token;
    backend.expireAccessTokens();

    final me = await c.read(userRepositoryProvider).getMe();

    expect(me.isOk, isTrue);
    expect(store.token, isNot(before));
  });

  test('a session revoked during use becomes expired', () async {
    final c = start();
    await signInAsPassenger(c);
    // Someone used the refresh token behind our back.
    backend.refresh(RefreshRequest(refreshToken: store.token!));
    backend.expireAccessTokens();

    final me = await c.read(userRepositoryProvider).getMe();
    await Future<void>.delayed(Duration.zero);

    expect(me.failureOrNull?.code, 'REFRESH_TOKEN_REUSE_DETECTED');
    expect(c.read(sessionControllerProvider).value, isA<SessionExpired>());
    expect(store.token, isNull);
  });
}
