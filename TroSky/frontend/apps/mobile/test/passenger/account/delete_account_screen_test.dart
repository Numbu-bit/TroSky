// Widget tests for P-25 Delete account: type-to-confirm gate + password
// required before the CTA enables.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/account/presentation/delete_account_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeUserRepo implements UserRepository {
  final List<AccountDeletionRequest> deletes = [];

  @override
  Future<Result<MessageResponse>> deleteAccount(
    AccountDeletionRequest request,
  ) async {
    deletes.add(request);
    return const Err(NetworkFailure(message: 'offline'));
  }

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
}

Widget _host(_FakeUserRepo repo) => ProviderScope(
  overrides: [userRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: const DeleteAccountScreen(),
  ),
);

void main() {
  testWidgets(
    'the CTA is disabled until DELETE is typed and a password is entered',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeUserRepo();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      // Tap CTA with nothing typed → no-op.
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(repo.deletes, isEmpty);
      // Type the wrong word → no-op.
      await tester.enterText(find.byType(TextField).at(0), 'delete');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(repo.deletes, isEmpty);
      // Type the exact word → fires.
      await tester.enterText(find.byType(TextField).at(0), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(repo.deletes.length, 1);
      expect(repo.deletes.single.password, 'secret');
    },
  );
}
