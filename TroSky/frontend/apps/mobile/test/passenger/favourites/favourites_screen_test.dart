// Widget tests for P-26 Favourites.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/favourites/presentation/favourites_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeUser implements UserRepository {
  _FakeUser(this.favourites);
  final List<FavouriteRouteResponse> favourites;
  final List<String> deletes = [];

  @override
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes() async =>
      Ok(favourites);

  @override
  Future<Result<void>> deleteFavouriteRoute(String id) async {
    deletes.add(id);
    return const Ok(null);
  }

  @override
  Future<Result<UserResponse>> getMe() async => const Err(NetworkFailure());
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
  Future<Result<NotificationPreferencesResponse>>
  notificationPreferences() async => const Err(NetworkFailure());
  @override
  Future<Result<NotificationPreferencesResponse>> updateNotificationPreferences(
    NotificationPreferencesUpdateRequest request,
  ) async => const Err(NetworkFailure());
}

FavouriteRouteResponse _f({required String id, String? label}) =>
    FavouriteRouteResponse(
      id: id,
      originStopId: 'o$id',
      originStopName: 'Madina',
      destinationStopId: 'd$id',
      destinationStopName: 'Circle',
      label: label,
      createdAt: DateTime.utc(2026, 11, 20),
    );

Widget _host(_FakeUser repo) => ProviderScope(
  overrides: [userRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: const FavouritesScreen(),
  ),
);

void main() {
  testWidgets('empty state shows the "Add from Search" helper', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_FakeUser([])));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save routes'), findsOneWidget);
    expect(find.textContaining('tap the heart'), findsOneWidget);
  });

  testWidgets('route rows render the origin → destination copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_FakeUser([_f(id: '1')])));
    await tester.pumpAndSettle();
    expect(find.text('Madina → Circle'), findsOneWidget);
  });
}
