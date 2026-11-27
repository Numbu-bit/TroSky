// Favourites screen (step 21/close-stubs-C) — Places section.

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
  _FakeUser({this.places = const []});
  List<FavouritePlaceResponse> places;

  @override
  Future<Result<List<FavouritePlaceResponse>>> listFavouritePlaces() async =>
      Ok(places);

  @override
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes() async =>
      const Ok([]);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FavouritePlaceResponse _place({
  required FavouritePlaceKind kind,
  String label = 'Home',
  String id = 'p1',
}) => FavouritePlaceResponse(
  id: id,
  kind: kind,
  label: label,
  stopId: 's1',
  stopName: 'Madina',
  latitude: 5.68,
  longitude: -0.17,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

Widget _host(UserRepository repo) => ProviderScope(
  overrides: [userRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale('en')],
    home: FavouritesScreen(),
  ),
);

void main() {
  testWidgets('empty Places section shows both Add Home and Add Work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_FakeUser()));
    await tester.pumpAndSettle();
    expect(find.text('Add Home'), findsOneWidget);
    expect(find.text('Add Work'), findsOneWidget);
  });

  testWidgets('when Home is set, Add Home is gone but Add Work stays', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        _FakeUser(
          places: [_place(kind: FavouritePlaceKind.home, label: 'Home')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add Home'), findsNothing);
    expect(find.text('Add Work'), findsOneWidget);
    // The Home row's label shows and its stop subtitle shows.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Madina'), findsOneWidget);
  });

  testWidgets('Routes section renders below Places (secondary)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_FakeUser()));
    await tester.pumpAndSettle();
    final placesY = tester.getTopLeft(find.text('PLACES')).dy;
    final routesY = tester.getTopLeft(find.text('SAVED ROUTES')).dy;
    expect(
      routesY,
      greaterThan(placesY),
      reason: 'Saved routes section should be below Places',
    );
  });
}
