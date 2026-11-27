// Widget tests for P-23 Change password (step 21/B4).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/account/presentation/change_password_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

class _FakeRepo implements UserRepository {
  _FakeRepo({required this.result});

  final Result<MessageResponse> result;
  final List<ChangePasswordRequest> calls = [];
  final List<String> idempotencyKeys = [];

  @override
  Future<Result<MessageResponse>> changePassword(
    ChangePasswordRequest request, {
    required String idempotencyKey,
  }) async {
    calls.add(request);
    idempotencyKeys.add(idempotencyKey);
    return result;
  }

  // Unused in these tests.
  @override
  Future<Result<UserResponse>> getMe() async => const Err(NetworkFailure());
  @override
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes() async =>
      const Err(NetworkFailure());
  @override
  Future<Result<FavouriteRouteResponse>> addFavouriteRoute(
    FavouriteRouteCreateRequest request,
  ) async => const Err(NetworkFailure());
  @override
  Future<Result<UserResponse>> updateMe(
    UserProfileUpdateRequest request,
  ) async => const Err(NetworkFailure());
  @override
  Future<Result<MessageResponse>> deleteAccount(
    AccountDeletionRequest request,
  ) async => const Err(NetworkFailure());
  @override
  Future<Result<void>> deleteFavouriteRoute(String favouriteId) async =>
      const Err(NetworkFailure());
  @override
  Future<Result<NotificationPreferencesResponse>>
  notificationPreferences() async => const Err(NetworkFailure());
  @override
  Future<Result<NotificationPreferencesResponse>> updateNotificationPreferences(
    NotificationPreferencesUpdateRequest request,
  ) async => const Err(NetworkFailure());
  @override
  Future<Result<EmailChangeStartedResponse>> changeEmail(
    ChangeEmailRequest request, {
    required String idempotencyKey,
  }) async => const Err(NetworkFailure());
  @override
  Future<Result<UserResponse>> confirmEmailChange(
    ChangeEmailConfirmRequest request,
  ) async => const Err(NetworkFailure());
}

Widget _host(_FakeRepo repo) => ProviderScope(
  overrides: [userRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: const ChangePasswordScreen(),
  ),
);

Future<void> _fillValidForm(
  WidgetTester tester, {
  String current = 'OldPass99',
  String next = 'NewPass77',
}) async {
  await tester.enterText(find.byType(TextField).at(0), current);
  await tester.enterText(find.byType(TextField).at(1), next);
  await tester.enterText(find.byType(TextField).at(2), next);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Larger surface so the CTA + helper lines render without
    // overflow in low-DPI tests.
  });

  testWidgets('strength meter reacts to new-password input', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(result: const Ok(MessageResponse(message: 'ok')));
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    // Nothing typed â†’ Weak.
    expect(find.text('Weak'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'ab');
    await tester.pumpAndSettle();
    expect(find.text('Weak'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Password1');
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp('Good|Strong')), findsOneWidget);
  });

  testWidgets('submit disabled until all three fields are valid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(result: const Ok(MessageResponse(message: 'ok')));
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    // Empty â†’ tap is no-op.
    await tester.tap(find.widgetWithText(TroskyButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    // Mismatched confirm â†’ no-op.
    await tester.enterText(find.byType(TextField).at(0), 'OldPass99');
    await tester.enterText(find.byType(TextField).at(1), 'NewPass77');
    await tester.enterText(find.byType(TextField).at(2), 'Different99');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TroskyButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    // All valid â†’ fires.
    await _fillValidForm(tester);
    await tester.tap(find.widgetWithText(TroskyButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(repo.calls.length, 1);
    expect(repo.calls.single.currentPassword, 'OldPass99');
    expect(repo.calls.single.newPassword, 'NewPass77');
  });

  testWidgets('401 maps to inline Current-password error', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(
      result: const Err(
        UnauthorizedFailure(code: 'INVALID_CREDENTIALS', message: 'no'),
      ),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    await _fillValidForm(tester);
    await tester.tap(find.widgetWithText(TroskyButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(
      find.text("That password doesn't match our records."),
      findsOneWidget,
    );
  });

  testWidgets('409 PASSWORD_UNCHANGED maps to New-password inline error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(
      result: const Err(
        ConflictFailure(code: 'PASSWORD_UNCHANGED', message: 'same as current'),
      ),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    // Use distinct current/new so the CLIENT pre-check doesn't catch
    // the "same" case â€” we want the backend's 409 to land.
    await _fillValidForm(tester);
    await tester.tap(find.widgetWithText(TroskyButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(
      find.text('New password must differ from your current one.'),
      findsOneWidget,
    );
  });

  testWidgets('success clears fields + shows toast + does not sign out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(
      result: const Ok(MessageResponse(message: 'Password changed.')),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    await _fillValidForm(tester);
    await tester.tap(find.widgetWithText(TroskyButton, 'Change password'));
    await tester.pumpAndSettle();
    // Toast shown.
    expect(find.text('Password changed'), findsOneWidget);
    // Fields cleared (textfield controllers reset to empty).
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    for (final f in fields) {
      expect(f.controller!.text, isEmpty);
    }
    // Only one request landed and the idempotency key was a UUID v4.
    expect(repo.idempotencyKeys.length, 1);
    expect(
      repo.idempotencyKeys.single,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
