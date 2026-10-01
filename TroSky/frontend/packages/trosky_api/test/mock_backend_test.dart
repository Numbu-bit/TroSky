import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

/// The mock must answer like backend/app/services/auth_service.py.
void main() {
  late DateTime now;
  late MockBackend backend;

  setUp(() {
    now = DateTime.utc(2026, 10, 1, 9);
    backend = MockBackend(clock: () => now);
  });

  RegisterRequest newPassenger({
    String phone = '0551234567',
    String? email = 'yaw.asante@gmail.com',
    String password = 'Accra2026',
  }) => RegisterRequest(
    phoneNumber: phone,
    email: email,
    password: password,
    fullName: 'Yaw Asante',
  );

  String? code<T>(Result<T> result) => result.failureOrNull?.code;

  group('register', () {
    test('a new phone gets a code by SMS, sent to the E.164 number', () {
      final result = backend.register(newPassenger());

      expect(result.valueOrNull?.otpSentTo, '+233551234567');
      expect(result.valueOrNull?.phoneNumber, '+233551234567');
      expect(backend.outbox.first.to, '+233551234567');
      expect(backend.outbox.first.purpose, OtpPurpose.registration);
      // Plus the best-effort email verification code.
      expect(backend.outbox.last.purpose, OtpPurpose.emailVerification);
    });

    test('with codes by email, the code and otp_sent_to are the email', () {
      backend = MockBackend(clock: () => now, codesByEmail: true);
      final result = backend.register(newPassenger());
      expect(result.valueOrNull?.otpSentTo, 'yaw.asante@gmail.com');
    });

    test('existing phone and email are refused', () {
      expect(
        code(backend.register(newPassenger(phone: '0241234567'))),
        'PHONE_ALREADY_REGISTERED',
      );
      expect(
        code(backend.register(newPassenger(email: 'ama.mensah@gmail.com'))),
        'EMAIL_ALREADY_REGISTERED',
      );
    });

    test('email is required and must be Gmail', () {
      final missing = backend.register(newPassenger(email: null));
      expect(code(missing), 'EMAIL_REQUIRED');
      expect(missing.failureOrNull?.statusCode, 422);

      final wrongDomain = backend.register(
        newPassenger(email: 'yaw@yahoo.com'),
      );
      expect(code(wrongDomain), 'EMAIL_DOMAIN_NOT_ALLOWED');
    });

    test('a weak password is a 409 policy violation', () {
      final result = backend.register(newPassenger(password: 'accra2026'));
      expect(code(result), 'PASSWORD_POLICY_VIOLATION');
      expect(result.failureOrNull?.statusCode, 409);
      expect(
        (result.failureOrNull! as ValidationFailure).fieldErrors['password'],
        ['Password must contain at least one uppercase letter.'],
      );
    });

    test('an invalid phone is a 422 on phone_number', () {
      final result = backend.register(newPassenger(phone: '0251234567'));
      expect(code(result), 'VALIDATION_ERROR');
      expect((result.failureOrNull! as ValidationFailure).fieldErrors.keys, [
        'phone_number',
      ]);
    });
  });

  group('sign-up flow', () {
    test('register → verify → login', () {
      backend.register(newPassenger());

      final beforeVerify = backend.login(
        const LoginRequest(identifier: '0551234567', password: 'Accra2026'),
      );
      expect(code(beforeVerify), 'ACCOUNT_NOT_VERIFIED');
      expect(beforeVerify.failureOrNull?.details, {
        'target': '+233551234567',
        'purpose': 'registration',
      });

      final verified = backend.verifyOtp(
        const VerifyOtpRequest(
          target: '+233551234567',
          purpose: OtpPurpose.registration,
          code: MockBackend.otpCode,
        ),
      );
      expect(verified.isOk, isTrue);

      final login = backend.login(
        const LoginRequest(identifier: '0551234567', password: 'Accra2026'),
      );
      expect(login.valueOrNull?.expiresIn, 900);
    });
  });

  group('OTP', () {
    test('resend for a phone with no account succeeds and sends nothing', () {
      final result = backend.resendOtp(
        const ResendOtpRequest(target: '0551234567', purpose: OtpPurpose.login),
      );
      expect(
        result.valueOrNull?.message,
        'A new verification code has been sent.',
      );
      expect(backend.outbox, isEmpty);
    });

    test('a second resend within 60 s is rate limited, then allowed', () {
      const request = ResendOtpRequest(
        target: '0241234567',
        purpose: OtpPurpose.login,
      );
      expect(backend.resendOtp(request).isOk, isTrue);

      final again = backend.resendOtp(request);
      expect(code(again), 'RATE_LIMIT_EXCEEDED');
      expect(
        (again.failureOrNull! as RateLimitedFailure).retryAfter,
        const Duration(seconds: 60),
      );

      now = now.add(const Duration(seconds: 61));
      expect(backend.resendOtp(request).isOk, isTrue);
    });

    test('otp-login with an unknown phone is NOT_FOUND, whatever the code', () {
      final result = backend.otpLogin(
        const OtpLoginRequest(target: '0551234567', code: '000000'),
      );
      expect(code(result), 'NOT_FOUND');
      expect(result.failureOrNull?.statusCode, 404);
    });

    test('otp-login for an existing passenger', () {
      backend.resendOtp(
        const ResendOtpRequest(
          target: '024 123 4567',
          purpose: OtpPurpose.login,
        ),
      );
      final result = backend.otpLogin(
        const OtpLoginRequest(
          target: '+233241234567',
          code: MockBackend.otpCode,
        ),
      );
      expect(result.isOk, isTrue);
    });

    test('no code requested, wrong code, expired code, too many tries', () {
      const login = OtpLoginRequest(target: '0241234567', code: '654321');
      expect(code(backend.otpLogin(login)), 'OTP_NOT_FOUND');

      backend.resendOtp(
        const ResendOtpRequest(target: '0241234567', purpose: OtpPurpose.login),
      );
      for (var i = 0; i < MockBackend.otpMaxAttempts; i++) {
        expect(code(backend.otpLogin(login)), 'OTP_INVALID');
      }
      expect(code(backend.otpLogin(login)), 'OTP_ATTEMPTS_EXCEEDED');

      now = now.add(const Duration(seconds: 61));
      backend.resendOtp(
        const ResendOtpRequest(target: '0241234567', purpose: OtpPurpose.login),
      );
      now = now.add(const Duration(seconds: 301));
      expect(
        code(
          backend.otpLogin(
            const OtpLoginRequest(
              target: '0241234567',
              code: MockBackend.otpCode,
            ),
          ),
        ),
        'OTP_EXPIRED',
      );
    });
  });

  group('login', () {
    test('existing driver with the seed password', () {
      final result = backend.login(
        const LoginRequest(
          identifier: '0201234567',
          password: MockBackend.seedPassword,
        ),
      );
      expect(result.isOk, isTrue);
    });

    test('unknown phone and wrong password look the same', () {
      expect(
        code(
          backend.login(
            const LoginRequest(identifier: '0551234567', password: 'x'),
          ),
        ),
        'INVALID_CREDENTIALS',
      );
      expect(
        code(
          backend.login(
            const LoginRequest(identifier: '0241234567', password: 'x'),
          ),
        ),
        'INVALID_CREDENTIALS',
      );
    });

    test('five wrong passwords lock the account for 15 minutes', () {
      const wrong = LoginRequest(identifier: '0241234567', password: 'x');
      for (var i = 0; i < MockBackend.loginMaxFailedAttempts; i++) {
        backend.login(wrong);
      }
      final locked = backend.login(
        const LoginRequest(
          identifier: '0241234567',
          password: MockBackend.seedPassword,
        ),
      );
      expect(code(locked), 'ACCOUNT_LOCKED');
      expect(
        (locked.failureOrNull! as AccountLockedFailure).lockedUntil,
        now.add(const Duration(minutes: 15)),
      );
    });

    test('a suspended account', () {
      backend.suspend('0241234567');
      final result = backend.login(
        const LoginRequest(
          identifier: '0241234567',
          password: MockBackend.seedPassword,
        ),
      );
      expect(result.failureOrNull, isA<AccountSuspendedFailure>());
    });
  });

  group('tokens', () {
    TokenPairResponse signIn() => backend
        .login(
          const LoginRequest(
            identifier: '0241234567',
            password: MockBackend.seedPassword,
          ),
        )
        .valueOrNull!;

    test('refresh rotates; the old token reused revokes every session', () {
      final first = signIn();
      final other = signIn();
      final rotated = backend.refresh(
        RefreshRequest(refreshToken: first.refreshToken),
      );
      expect(rotated.isOk, isTrue);
      expect(backend.activeSessions('0241234567'), 2);

      final reused = backend.refresh(
        RefreshRequest(refreshToken: first.refreshToken),
      );
      expect(code(reused), 'REFRESH_TOKEN_REUSE_DETECTED');
      expect(backend.activeSessions('0241234567'), 0);
      expect(code(backend.getMe(other.accessToken)), 'UNAUTHORIZED');
    });

    test(
      'logout revokes the session, so its refresh token counts as reuse',
      () {
        final pair = signIn();
        expect(backend.getMe(pair.accessToken).isOk, isTrue);

        expect(backend.logout(pair.accessToken).isOk, isTrue);
        expect(code(backend.getMe(pair.accessToken)), 'UNAUTHORIZED');
        expect(
          code(
            backend.refresh(RefreshRequest(refreshToken: pair.refreshToken)),
          ),
          'REFRESH_TOKEN_REUSE_DETECTED',
        );
      },
    );

    test('an expired access token is UNAUTHORIZED', () {
      final pair = signIn();
      backend.expireAccessTokens();
      expect(code(backend.getMe(pair.accessToken)), 'UNAUTHORIZED');
    });
  });

  test('GET /users/me returns the profile and roles', () {
    final pair = backend
        .login(
          const LoginRequest(
            identifier: 'kofi.boateng@gmail.com',
            password: MockBackend.seedPassword,
          ),
        )
        .valueOrNull!;
    final me = backend.getMe(pair.accessToken).valueOrNull!;
    expect(me.roles, ['driver']);
    expect(me.profile?.fullName, 'Kofi Boateng');
    expect(me.phoneNumber, MockBackend.driverPhone);
  });
}
