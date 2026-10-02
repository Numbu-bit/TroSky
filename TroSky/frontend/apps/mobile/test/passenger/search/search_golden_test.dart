@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/home/data/location_service.dart';
import 'package:mobile/passenger/search/domain/journey.dart';
import 'package:mobile/passenger/search/presentation/search_results_screen.dart';
import 'package:mobile/passenger/search/presentation/search_screen.dart';
import 'package:trosky_api/trosky_api.dart';

import '../home/home_helpers.dart';
import 'search_helpers.dart';

/// Search (P-02) and Search Results (P-03) in mock mode at 09:00, located
/// next to Madina. Emoji have no font in tests.
Future<void> _golden(WidgetTester tester, Type screen, String name) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
  debugDisableShadows = false;
  try {
    await expectLater(
      find.byType(screen),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('P-02 Search: From focused, nearby stops, favourites, recent', (
    tester,
  ) async {
    final world = morning();
    world.location
      ..permission = LocationPermissionStatus.granted
      ..position = nearMadina;
    SearchStop stop(String name) =>
        SearchStop(id: MockBackend.stops[name]!.id, name: name);
    world.searches.searches = [
      RecentSearch(
        origin: const CurrentLocationOrigin(),
        destination: stop('Circle'),
      ),
      RecentSearch(origin: StopOrigin(stop('Osu')), destination: stop('Tema')),
    ];
    await openSearch(tester, world: world);
    await tester.tap(searchField('from'));
    await _golden(tester, SearchScreen, 'search');
  });

  testWidgets('P-03 Search Results at the design frame, 390 x 844', (
    tester,
  ) async {
    final world = morning();
    world.location
      ..permission = LocationPermissionStatus.granted
      ..position = nearMadina;
    await openHome(tester, world: world, size: const Size(390, 844));
    await tester.tap(find.text('Madina → Circle'));
    await tester.pumpAndSettle();
    await _golden(tester, SearchResultsScreen, 'search_results_390');
  });

  testWidgets('P-03 Search Results on the TECNO BG6, 360 x 806', (
    tester,
  ) async {
    await openHome(tester, world: morning());
    await tester.tap(find.text('Madina → Circle'));
    await tester.pumpAndSettle();
    await _golden(tester, SearchResultsScreen, 'search_results_360');
  });
}
