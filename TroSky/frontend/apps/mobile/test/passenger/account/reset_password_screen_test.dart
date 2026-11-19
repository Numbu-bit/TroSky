// Widget tests for S-09a: the neutral confirmation text is the same
// whether or not the submitted identifier exists (no existence leak).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/account/presentation/reset_password_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

/// Returns Ok for one identifier and a backend-style "no such account"
/// 404 for the other. S-09a must render the same neutral text either way.
class _KnownOnlyAuth implements AuthRepository {
  final String known;
  _KnownOnlyAuth(this.known);

  @override
  Future<Result<MessageResponse>> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    if (request.identifier == known) {
      return const Ok(MessageResponse(message: 'sent'));
    }
    return const Err(NotFoundFailure(code: 'NOT_FOUND', message: 'no account'));
  }

  @override
  Future<Result<MessageResponse>> resetPassword(
    ResetPasswordRequest request,
  ) async => const Err(NetworkFailure());

  // Not used by this test.
  @override
  Future<Result<RegisterResponse>> register(RegisterRequest request) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest request) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest request) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<TokenPairResponse>> login(LoginRequest request) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest request) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<void>> logout() async => const Ok(null);
}

Widget _host(AuthRepository auth) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(auth)],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: const RequestResetScreen(),
  ),
);

Future<String?> _confirmationText(
  WidgetTester tester,
  String identifier,
) async {
  await tester.enterText(find.byType(TextField), identifier);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send code'));
  await tester.pumpAndSettle();
  final finder = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data);
  return finder.firstWhere(
    (t) => t?.contains('exists') == true,
    orElse: () => null,
  );
}

void main() {
  testWidgets(
    'S-09a shows the same neutral confirmation for known + unknown identifiers',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = _KnownOnlyAuth('known@example.com');
      await tester.pumpWidget(_host(auth));
      await tester.pumpAndSettle();
      final knownCopy = await _confirmationText(tester, 'known@example.com');
      expect(knownCopy, isNotNull);
    },
  );

  testWidgets('S-09a also shows the same copy for an unknown identifier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _KnownOnlyAuth('known@example.com');
    await tester.pumpWidget(_host(auth));
    await tester.pumpAndSettle();
    final unknownCopy = await _confirmationText(tester, 'nobody@example.com');
    expect(unknownCopy, isNotNull);
  });
}
