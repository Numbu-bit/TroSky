import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/auth/presentation/verify_code_screen.dart';
import 'package:mobile/entry/auth/presentation/welcome_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../helpers/fakes.dart';
import 'auth_helpers.dart';

/// Answers every login with 429, as the backend's rate limit would.
class _RateLimitedAuth implements AuthRepository {
  _RateLimitedAuth(this._inner);

  final AuthRepository _inner;

  @override
  Future<Result<TokenPairResponse>> login(LoginRequest request) async => Err(
    AppFailure.fromResponse(
      statusCode: 429,
      body: {
        'error': {
          'code': 'RATE_LIMIT_EXCEEDED',
          'message': 'Too many requests.',
          'details': {'rule': 'auth:login', 'limit': 10, 'window_seconds': 300},
          'request_id': 'r',
        },
      },
    ),
  );

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
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest r) =>
      _inner.otpLogin(r);
  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest r) =>
      _inner.refresh(r);
  @override
  Future<Result<void>> logout() => _inner.logout();
}

Future<void> typeCode(WidgetTester tester, String code) async {
  final input = find.descendant(
    of: find.byType(VerifyCodeScreen),
    matching: find.byType(TextField),
  );
  await tester.enterText(input, code);
  await tester.pumpAndSettle();
}

Future<void> signIn(
  WidgetTester tester, {
  String phone = '0241234567',
  String password = MockBackend.seedPassword,
}) async {
  await enter(tester, 'XX XXX XXXX', phone);
  await tester.enterText(find.byType(TextField).last, password);
  await tapVisible(tester, find.text('Sign in'));
}

void main() {
  group('S-07 Code verification', () {
    testWidgets('a wrong code, then the right one signs in silently', (
      tester,
    ) async {
      final world = await openDetails(tester);
      await submitDetails(tester);

      await typeCode(tester, '000000');
      expect(
        find.text("That code isn't right. Check it and try again."),
        findsOneWidget,
      );

      await typeCode(tester, MockBackend.otpCode);
      expect(find.text('home'), findsOneWidget);
      expect(world.tokens.token, isNotNull);
      expect(world.cache.user?.phoneNumber, '+233551234567');
    });

    testWidgets('resend counts down 60 s, then sends again', (tester) async {
      final world = await openDetails(tester);
      await submitDetails(tester);
      expect(find.text('Resend code in 60 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend code in 30 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      world.now = world.now.add(const Duration(seconds: 61));
      await tester.pump();

      await tapVisible(tester, link('Resend code'));
      expect(find.text('A new code is on its way.'), findsOneWidget);
      expect(find.text('Resend code in 60 s'), findsOneWidget);
    });

    testWidgets('an expired code says so', (tester) async {
      final world = await openDetails(tester);
      await submitDetails(tester);
      world.now = world.now.add(const Duration(minutes: 6));

      await typeCode(tester, MockBackend.otpCode);
      expect(find.text('Code expired — resend'), findsOneWidget);
    });

    testWidgets('too many wrong codes', (tester) async {
      await openDetails(tester);
      await submitDetails(tester);
      for (var i = 0; i < MockBackend.otpMaxAttempts; i++) {
        await typeCode(tester, '00000$i');
      }
      await typeCode(tester, MockBackend.otpCode);
      expect(
        find.text('Too many wrong codes. Resend a new code.'),
        findsOneWidget,
      );
    });

    testWidgets('a code pasted with spaces is cleaned up', (tester) async {
      await openDetails(tester);
      await submitDetails(tester);
      await typeCode(tester, '123 456');
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('S-05 Sign in', () {
    testWidgets('an existing passenger signs in to home', (tester) async {
      await openSignIn(tester);
      await signIn(tester);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('with email', (tester) async {
      await openSignIn(tester);
      await tapVisible(tester, link('Use email instead'));
      await enter(tester, 'you@gmail.com', 'ama.mensah@gmail.com');
      await tester.enterText(
        find.byType(TextField).last,
        MockBackend.seedPassword,
      );
      await tapVisible(tester, find.text('Sign in'));
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a wrong password', (tester) async {
      await openSignIn(tester);
      await signIn(tester, password: 'Wrong2026');
      expect(
        find.text("That phone number, email or password isn't right."),
        findsOneWidget,
      );
    });

    testWidgets('a locked account shows when it unlocks', (tester) async {
      await openSignIn(tester);
      for (var i = 0; i < MockBackend.loginMaxFailedAttempts; i++) {
        await signIn(tester, password: 'Wrong2026');
      }
      await signIn(tester);
      expect(
        find.textContaining('Too many wrong passwords. Try again after'),
        findsOneWidget,
      );
    });

    testWidgets('a suspended account', (tester) async {
      final world = TestWorld()..backend.suspend('0241234567');
      await openSignIn(tester, world: world);
      await signIn(tester);
      expect(
        find.text('This account is suspended. Contact TroSky support.'),
        findsOneWidget,
      );
    });

    testWidgets('a rate limit', (tester) async {
      final world = TestWorld();
      late final _RateLimitedAuth auth;
      await openSignIn(
        tester,
        world: world,
        overrides: [
          authRepositoryProvider.overrideWith((ref) {
            return auth = _RateLimitedAuth(
              MockAuthRepository(
                world.backend,
                tokens: () => ref.read(tokenManagerProvider),
              ),
            );
          }),
        ],
      );
      await signIn(tester);
      expect(
        find.text('Too many tries. Wait 300 s and try again.'),
        findsOneWidget,
      );
      expect(auth, isNotNull);
    });

    testWidgets('an unverified account verifies with a fresh code, then '
        'signs in', (tester) async {
      final world = TestWorld();
      world.backend.register(
        const RegisterRequest(
          phoneNumber: '0551234567',
          email: 'efua.owusu@gmail.com',
          password: 'Kumasi2026',
          fullName: 'Efua Owusu',
        ),
      );
      world.now = world.now.add(const Duration(seconds: 61));
      await openSignIn(tester, world: world);
      await signIn(tester, phone: '0551234567', password: 'Kumasi2026');

      expect(find.byType(VerifyCodeScreen), findsOneWidget);
      expect(
        find.text('Code sent by text to +233 55 ••• ••67'),
        findsOneWidget,
      );
      expect(find.text('Resend code in 60 s'), findsOneWidget);

      await typeCode(tester, MockBackend.otpCode);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('an unverified account inside the cooldown waits it out', (
      tester,
    ) async {
      final world = TestWorld();
      world.backend.register(
        const RegisterRequest(
          phoneNumber: '0551234567',
          email: 'efua.owusu@gmail.com',
          password: 'Kumasi2026',
          fullName: 'Efua Owusu',
        ),
      );
      world.now = world.now.add(const Duration(seconds: 20));
      await openSignIn(tester, world: world);
      await signIn(tester, phone: '0551234567', password: 'Kumasi2026');

      // The 429 carries cooldown_seconds; the countdown uses it.
      expect(find.text('Resend code in 60 s'), findsOneWidget);
    });
  });

  group('Sign in with a code', () {
    Future<void> requestCode(WidgetTester tester, String phone) async {
      await tapVisible(tester, link('Sign in with a code'));
      expect(find.text('Sign in with a code'), findsWidgets);
      await enter(tester, 'XX XXX XXXX', phone);
      await tapVisible(tester, find.text('Send code'));
    }

    testWidgets('an existing driver gets in', (tester) async {
      await openSignIn(tester, world: TestWorld(mode: AppMode.driver));
      await requestCode(tester, '0201234567');
      expect(find.byType(VerifyCodeScreen), findsOneWidget);

      await typeCode(tester, MockBackend.otpCode);
      expect(find.text('driverHome'), findsOneWidget);
    });

    testWidgets('a number with no account says so, with Create account', (
      tester,
    ) async {
      await openSignIn(tester);
      await requestCode(tester, '0551234567');
      await typeCode(tester, MockBackend.otpCode);
      expect(find.text('No account for this number'), findsOneWidget);

      await tapVisible(tester, link('Create account'));
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('after the cooldown it hints the number may have no account', (
      tester,
    ) async {
      await openSignIn(tester);
      await requestCode(tester, '0551234567');
      expect(
        find.text('No code? Check this number has a TroSky account.'),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 60));
      expect(
        find.text('No code? Check this number has a TroSky account.'),
        findsOneWidget,
      );
    });
  });
}
