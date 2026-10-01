import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/auth/presentation/details_screen.dart';
import 'package:mobile/entry/auth/presentation/sign_in_screen.dart';
import 'package:mobile/entry/auth/presentation/verify_code_screen.dart';
import 'package:mobile/entry/auth/presentation/welcome_screen.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../helpers/fakes.dart';
import 'auth_helpers.dart';

/// Refresh fails offline; everything else is the mock.
class _OfflineAuth implements AuthRepository {
  _OfflineAuth(this._inner);

  final AuthRepository _inner;

  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request) async =>
      const Err(NetworkFailure());

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

Future<void> signIn(WidgetTester tester, {String phone = '0241234567'}) async {
  await enter(tester, 'XX XXX XXXX', phone);
  await tester.enterText(find.byType(TextField).last, MockBackend.seedPassword);
  await tapVisible(tester, find.text('Sign in'));
}

void main() {
  group('post-sign-in routing', () {
    testWidgets('driver account in passenger mode → switch to driver', (
      tester,
    ) async {
      final world = await openSignIn(tester);
      await signIn(tester, phone: '0201234567');
      expect(find.text('This is a driver account'), findsOneWidget);

      await tapVisible(tester, find.text('Switch to driver mode'));
      expect(world.modes.mode, AppMode.driver);
      expect(find.text('driverHome'), findsOneWidget);
    });

    testWidgets('driver account in passenger mode → use another account', (
      tester,
    ) async {
      final world = await openSignIn(tester);
      await signIn(tester, phone: '0201234567');
      await tapVisible(tester, find.text('Use another account'));
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(world.tokens.token, isNull);
    });

    testWidgets('passenger account in driver mode → S-10 → become a driver', (
      tester,
    ) async {
      await openSignIn(tester, world: TestWorld(mode: AppMode.driver));
      await signIn(tester);
      expect(
        find.text("This account isn't a driver account yet"),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Become a driver'));
      expect(find.text('driverOnboarding'), findsOneWidget);
    });

    testWidgets('S-10 → continue as passenger', (tester) async {
      final world = TestWorld(mode: AppMode.driver);
      await openSignIn(tester, world: world);
      await signIn(tester);
      await tapVisible(tester, find.text('Continue as passenger'));
      expect(world.modes.mode, AppMode.passenger);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a driver awaiting approval', (tester) async {
      final world = TestWorld(mode: AppMode.driver);
      world.backend.setDriverStatus('0201234567', ApprovalStatus.pending);
      await openSignIn(tester, world: world);
      await signIn(tester, phone: '0201234567');
      expect(find.text('driverAwaitingApproval'), findsOneWidget);
    });

    testWidgets('driver sign-up → D-01', (tester) async {
      final world = await openWelcome(tester);
      await tapVisible(tester, link('Sign up as a driver'));
      await enter(tester, 'XX XXX XXXX', '0551234567');
      await tapVisible(tester, find.text('Continue'));
      expect(
        find.text('A few more details to create your driver account.'),
        findsOneWidget,
      );
      await submitDetails(tester);
      final input = find.descendant(
        of: find.byType(VerifyCodeScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, MockBackend.otpCode);
      await tester.pumpAndSettle();

      expect(find.text('driverOnboarding'), findsOneWidget);
      expect(world.cache.user?.roles, ['driver']);
    });
  });

  group('offline start (decision 9)', () {
    testWidgets('a saved session opens home with the offline banner', (
      tester,
    ) async {
      final world = TestWorld()
        ..tokens.token = 'mock.refresh.saved-on-a-previous-run'
        ..cache.user = UserResponse(
          id: 'u1',
          phoneNumber: MockBackend.passengerPhone,
          isActive: true,
          phoneVerified: true,
          emailVerified: false,
          roles: const ['passenger'],
          createdAt: DateTime.utc(2026, 7),
        );
      setScreenSize(tester, const Size(360, 806));
      await tester.pumpWidget(
        testApp(
          world: world,
          overrides: [
            authRepositoryProvider.overrideWith(
              (ref) => _OfflineAuth(
                MockAuthRepository(
                  world.backend,
                  tokens: () => ref.read(tokenManagerProvider),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump(splashMinimumDuration);
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(
        find.text("You're offline. Showing your last saved details."),
        findsOneWidget,
      );
      // Network trouble never signs out.
      expect(world.tokens.token, isNotNull);
    });
  });

  group('every auth screen at 360 x 640, text scale 1.3', () {
    Future<void> check(
      WidgetTester tester,
      Future<void> Function() open,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open();
      expect(tester.takeException(), isNull);
    }

    testWidgets('S-04', (tester) async {
      await check(
        tester,
        () => openWelcome(tester, size: const Size(360, 640)),
      );
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('S-05', (tester) async {
      await check(tester, () => openSignIn(tester, size: const Size(360, 640)));
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('S-06', (tester) async {
      await check(
        tester,
        () => openDetails(tester, size: const Size(360, 640)),
      );
      expect(find.byType(DetailsScreen), findsOneWidget);
    });

    testWidgets('S-07', (tester) async {
      await check(tester, () async {
        await openDetails(tester, size: const Size(360, 640));
        await submitDetails(tester);
      });
      expect(find.byType(VerifyCodeScreen), findsOneWidget);
    });
  });

  group('the keyboard never covers the field or the button', () {
    Future<void> expectAboveKeyboard(
      WidgetTester tester,
      Finder field,
      Finder button,
    ) async {
      await tester.tap(field);
      // A 300 px keyboard opens on a 640 px screen.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      const visibleBottom = 640.0 - 300;
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(visibleBottom));
      expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(visibleBottom));
    }

    testWidgets('Welcome: phone and Continue', (tester) async {
      await openWelcome(tester, size: const Size(360, 640));
      await expectAboveKeyboard(
        tester,
        field('XX XXX XXXX'),
        find.text('Continue'),
      );
    });

    testWidgets('Your details: password and Create account', (tester) async {
      await openDetails(tester, size: const Size(360, 640));
      await expectAboveKeyboard(
        tester,
        field('At least 8 characters'),
        find.text('Create account'),
      );
    });

    testWidgets('errors appearing under an open keyboard', (tester) async {
      await openDetails(tester, size: const Size(360, 640));
      // The password field and the button fit above the keyboard together.
      await tester.tap(field('At least 8 characters'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      // Create account with nothing filled in: the name and email errors
      // appear above and push the field and the button down.
      final button = find.text('Create account');
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(640.0 - 300));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(640.0 - 300));
    });

    testWidgets('Sign in: phone and Sign in', (tester) async {
      await openSignIn(tester, size: const Size(360, 640));
      await expectAboveKeyboard(
        tester,
        field('XX XXX XXXX'),
        find.text('Sign in').last,
      );
    });
  });

  testWidgets('screen readers hear the fields and the back button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openDetails(tester);
    // Each field's own node carries its label, not just the text above it.
    expect(
      tester.getSemantics(field('e.g. Ama Mensah')).label,
      contains('FULL NAME'),
    );
    expect(
      tester.getSemantics(field('you@gmail.com')).label,
      contains('EMAIL'),
    );
    expect(
      tester.getSemantics(field('At least 8 characters')).label,
      contains('PASSWORD'),
    );
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Show'), findsOneWidget);
    semantics.dispose();
  });
}
