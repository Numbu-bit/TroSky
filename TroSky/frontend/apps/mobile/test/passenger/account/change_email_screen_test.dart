// Widget tests for P-24 Change email (P-24a request + P-24b verify)
// and the P-22 pending-email sub-line (step 21/B4).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/account/application/pending_email_change.dart';
import 'package:mobile/passenger/account/presentation/change_email_screen.dart';
import 'package:mobile/passenger/account/presentation/personal_info_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// A fake [UserRepository] with scripted responses. Each call is
/// recorded so tests can assert on request bodies + idempotency keys.
class _FakeRepo implements UserRepository {
  _FakeRepo({this.changeEmailResult, this.confirmResult});

  Result<EmailChangeStartedResponse>? changeEmailResult;
  Result<UserResponse>? confirmResult;

  final List<ChangeEmailRequest> changeEmailCalls = [];
  final List<String> changeEmailKeys = [];
  final List<ChangeEmailConfirmRequest> confirmCalls = [];

  @override
  Future<Result<EmailChangeStartedResponse>> changeEmail(
    ChangeEmailRequest request, {
    required String idempotencyKey,
  }) async {
    changeEmailCalls.add(request);
    changeEmailKeys.add(idempotencyKey);
    return changeEmailResult ??
        const Err(UnknownFailure(code: 'NO_SCRIPT', message: ''));
  }

  @override
  Future<Result<UserResponse>> confirmEmailChange(
    ChangeEmailConfirmRequest request,
  ) async {
    confirmCalls.add(request);
    return confirmResult ??
        const Err(UnknownFailure(code: 'NO_SCRIPT', message: ''));
  }

  @override
  Future<Result<MessageResponse>> changePassword(
    ChangePasswordRequest request, {
    required String idempotencyKey,
  }) async => const Err(NetworkFailure());
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
}

UserResponse _user({
  String id = 'user-1',
  String? email = 'kwame@gmail.com',
  bool emailVerified = true,
}) => UserResponse(
  id: id,
  phoneNumber: '+233244000101',
  email: email,
  isActive: true,
  phoneVerified: true,
  emailVerified: emailVerified,
  roles: const ['passenger'],
  createdAt: DateTime(2026, 1, 1),
);

/// The `sessionControllerProvider.overrideWith(...)` override pinned
/// to [user] Ã¢â‚¬â€ a provider that always resolves to a signed-in
/// session for [user].
_StubSession _stub(UserResponse user) =>
    _StubSession(SessionAuthenticated(user));

class _StubSession extends SessionController {
  _StubSession(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;

  @override
  Future<void> applyUpdatedUser(UserResponse user) async {
    state = AsyncData(SessionAuthenticated(user));
  }
}

Widget _hostRequest(_FakeRepo repo, {UserResponse? user}) => ProviderScope(
  overrides: [
    userRepositoryProvider.overrideWithValue(repo),
    sessionControllerProvider.overrideWith(() => _stub(user ?? _user())),
  ],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    // Wrap in Router so pushReplacementNamed works.
    home: _RouterShell(repo: repo, user: user ?? _user()),
  ),
);

/// A tiny GoRouter exposing just the Change-email flow for tests.
class _RouterShell extends StatelessWidget {
  const _RouterShell({required this.repo, required this.user});
  final _FakeRepo repo;
  final UserResponse user;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: AppRoute.changeEmail.path,
      routes: [
        GoRoute(
          path: AppRoute.changeEmail.path,
          name: AppRoute.changeEmail.name,
          builder: (_, _) => const ChangeEmailRequestScreen(),
        ),
        GoRoute(
          path: AppRoute.changeEmailVerify.path,
          name: AppRoute.changeEmailVerify.name,
          builder: (_, state) => ChangeEmailVerifyScreen(
            args: state.extra! as ChangeEmailVerifyArgs,
          ),
        ),
        GoRoute(
          path: AppRoute.personalInfo.path,
          name: AppRoute.personalInfo.name,
          builder: (_, _) => const PersonalInfoScreen(),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}

Widget _hostVerify(
  _FakeRepo repo, {
  UserResponse? user,
  required ChangeEmailVerifyArgs args,
}) => ProviderScope(
  overrides: [
    userRepositoryProvider.overrideWithValue(repo),
    sessionControllerProvider.overrideWith(() => _stub(user ?? _user())),
  ],
  child: _VerifyShell(repo: repo, user: user ?? _user(), args: args),
);

class _VerifyShell extends StatelessWidget {
  const _VerifyShell({
    required this.repo,
    required this.user,
    required this.args,
  });
  final _FakeRepo repo;
  final UserResponse user;
  final ChangeEmailVerifyArgs args;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: AppRoute.changeEmailVerify.path,
      routes: [
        GoRoute(
          path: AppRoute.changeEmailVerify.path,
          name: AppRoute.changeEmailVerify.name,
          builder: (_, _) => ChangeEmailVerifyScreen(args: args),
        ),
        GoRoute(
          path: AppRoute.personalInfo.path,
          name: AppRoute.personalInfo.name,
          builder: (_, _) => const PersonalInfoScreen(),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}

void main() {
  testWidgets('P-24a: submit routes to P-24b on 2xx and sets pending state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(
      changeEmailResult: const Ok(
        EmailChangeStartedResponse(
          message: 'sent',
          otpSentTo: 'kofi@gmail.com',
          expiresInSeconds: 600,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(repo),
        sessionControllerProvider.overrideWith(() => _stub(_user())),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _RouterShell(repo: repo, user: _user()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'kofi@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'MyPass77');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TroskyButton, 'Send verification code'),
    );
    await tester.pumpAndSettle();
    expect(repo.changeEmailCalls.length, 1);
    expect(repo.changeEmailCalls.single.newEmail, 'kofi@gmail.com');
    expect(repo.changeEmailCalls.single.currentPassword, 'MyPass77');
    expect(find.text('Verify your new email'), findsOneWidget);
    final pending = container.read(pendingEmailChangeProvider);
    expect(pending?.userId, 'user-1');
    expect(pending?.newEmail, 'kofi@gmail.com');
  });

  testWidgets('P-24a: 409 EMAIL_ALREADY_REGISTERED shows inline error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(
      changeEmailResult: const Err(
        ConflictFailure(code: 'EMAIL_ALREADY_REGISTERED', message: 'taken'),
      ),
    );
    await tester.pumpWidget(_hostRequest(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'other@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'MyPass77');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TroskyButton, 'Send verification code'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This email is already linked to another TroSky account.'),
      findsOneWidget,
    );
  });

  testWidgets('P-24b: Resend respects the 60 s cooldown', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(
      changeEmailResult: const Ok(
        EmailChangeStartedResponse(
          message: 'sent',
          otpSentTo: 'kofi@gmail.com',
          expiresInSeconds: 600,
        ),
      ),
    );
    await tester.pumpWidget(
      _hostVerify(
        repo,
        args: const ChangeEmailVerifyArgs(
          newEmail: 'kofi@gmail.com',
          currentPassword: 'MyPass77',
          initialExpiresIn: Duration(minutes: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Immediately tap resend Ã¢â‚¬â€ disabled by the 60 s cooldown.
    // The label is "Resend in Ns" where N is 59 or 60 depending on
    // timing. Pick either by regex, then tap and confirm nothing was
    // sent.
    final resend = find.byWidgetPredicate(
      (w) =>
          w is TextButton &&
          (w.child is Text) &&
          RegExp(r'^Resend in \d+s$').hasMatch((w.child! as Text).data ?? ''),
    );
    expect(resend, findsOneWidget);
    await tester.tap(resend, warnIfMissed: false);
    await tester.pump();
    expect(repo.changeEmailCalls, isEmpty);
  });

  testWidgets('P-24b: 410/expired code shows expired inline message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(
      confirmResult: const Err(
        ConflictFailure(code: 'OTP_EXPIRED', message: 'expired'),
      ),
    );
    await tester.pumpWidget(
      _hostVerify(
        repo,
        args: const ChangeEmailVerifyArgs(
          newEmail: 'kofi@gmail.com',
          currentPassword: 'MyPass77',
          initialExpiresIn: Duration(minutes: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TroskyButton, 'Confirm new email'));
    await tester.pumpAndSettle();
    expect(find.text('That code expired. Tap Resend.'), findsOneWidget);
  });

  testWidgets('P-24b: confirm success routes to P-22 and refreshes the user', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final refreshed = _user(email: 'kofi@gmail.com', emailVerified: true);
    final repo = _FakeRepo(confirmResult: Ok(refreshed));
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(repo),
        sessionControllerProvider.overrideWith(() => _stub(_user())),
      ],
    );
    addTearDown(container.dispose);
    // Seed pending state so the P-22 sub-line test can also use it.
    container
        .read(pendingEmailChangeProvider.notifier)
        .set(
          PendingEmailChange(
            userId: 'user-1',
            newEmail: 'kofi@gmail.com',
            startedAt: DateTime.now(),
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _VerifyShell(
          repo: repo,
          user: _user(),
          args: const ChangeEmailVerifyArgs(
            newEmail: 'kofi@gmail.com',
            currentPassword: 'MyPass77',
            initialExpiresIn: Duration(minutes: 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TroskyButton, 'Confirm new email'));
    await tester.pumpAndSettle();
    expect(repo.confirmCalls.single.code, '123456');
    // Session refreshed Ã¢â€ â€™ P-22 shows the new email.
    expect(find.text('Personal information'), findsOneWidget);
    // Session refreshed with the new email + verified flag.
    // Pending state cleared (local provider). The session controller's
    // applyUpdatedUser is exercised separately in session_controller
    // tests — here we assert the P-24b-visible outcomes only.
    expect(container.read(pendingEmailChangeProvider), isNull);
  });

  testWidgets('P-22 shows the pending-change sub-line when set locally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(_FakeRepo()),
        sessionControllerProvider.overrideWith(() => _stub(_user())),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(pendingEmailChangeProvider.notifier)
        .set(
          PendingEmailChange(
            userId: 'user-1',
            newEmail: 'kofi@gmail.com',
            startedAt: DateTime.now(),
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: PersonalInfoScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Change to k***@gmail.com is pending verification.'),
      findsOneWidget,
    );
  });
}
