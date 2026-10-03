import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/home/data/location_service.dart';
import 'package:mobile/passenger/search/domain/journey.dart';
import 'package:mobile/passenger/search/presentation/search_results_screen.dart';
import 'package:mobile/passenger/search/presentation/search_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../home/home_helpers.dart';
import 'search_helpers.dart';

String _text(WidgetTester tester, String field) =>
    tester.widget<TextField>(searchField(field)).controller!.text;

void main() {
  group('stop search', () {
    testWidgets('2 letters or more, after 300 ms without typing', (
      tester,
    ) async {
      final world = morning();
      final stops = CountingStops(world.backend);
      await openSearch(
        tester,
        world: world,
        overrides: [routeRepositoryProvider.overrideWithValue(stops)],
      );

      await tester.enterText(searchField('to'), 'T');
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('Type 2 letters or more to search stops.'),
        findsOneWidget,
      );

      // Typing on before the pause: one request, for the last text.
      await tester.enterText(searchField('to'), 'Te');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(searchField('to'), 'Tem');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(stops.stopQueries, ['Tem']);
      expect(find.text('Tema'), findsOneWidget);

      await chooseStop(tester, 'Tema');
      expect(_text(tester, 'to'), 'Tema');
    });

    testWidgets('no match says so', (tester) async {
      await openSearch(tester, world: morning());
      await typeStop(tester, 'to', 'Kumasi');
      expect(find.text('No stops match "Kumasi".'), findsOneWidget);
    });
  });

  group('pickup (decision 19)', () {
    testWidgets('Current location by default: the backend picks the stop', (
      tester,
    ) async {
      final world = morning();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = nearMadina;
      await openSearch(tester, world: world);
      expect(_text(tester, 'from'), 'Current location');

      await typeStop(tester, 'to', 'Circle');
      await chooseStop(tester, 'Circle');
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsScreen), findsOneWidget);
      // The header names the stop the backend boarded the trips at.
      expect(find.text('Madina → Circle'), findsOneWidget);
      expect(find.text('Current location'), findsOneWidget);
    });

    testWidgets('a chosen stop, with nearby stops offered first', (
      tester,
    ) async {
      final world = morning();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = nearMadina;
      await openSearch(tester, world: world);

      await tester.tap(searchField('from'));
      await tester.pumpAndSettle();
      expect(find.text('Nearby stops'), findsOneWidget);
      expect(find.text('50 m away'), findsOneWidget);

      await typeStop(tester, 'from', 'Osu');
      await chooseStop(tester, 'Osu');
      await typeStop(tester, 'to', 'Circle');
      await chooseStop(tester, 'Circle');
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();

      expect(find.text('Osu → Circle'), findsOneWidget);
    });

    testWidgets('location refused: From must be a chosen stop', (tester) async {
      await openSearch(tester, world: morning());
      expect(_text(tester, 'from'), '');
      expect(
        find.text('Location is off. Choose a pickup stop.'),
        findsOneWidget,
      );

      await typeStop(tester, 'to', 'Circle');
      await chooseStop(tester, 'Circle');
      final search = tester.widget<TroskyButton>(
        find.widgetWithText(TroskyButton, 'Search'),
      );
      expect(search.onPressed, isNull);
    });

    testWidgets('NO_PICKUP_NEARBY: a clear message, then choose a stop', (
      tester,
    ) async {
      final world = morning();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = kumasi;
      await openSearch(tester, world: world);
      await typeStop(tester, 'to', 'Circle');
      await chooseStop(tester, 'Circle');
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();

      expect(
        find.text('No pickup stop is within walking distance of you.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose a pickup stop'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(_text(tester, 'from'), '');
      expect(_text(tester, 'to'), 'Circle');
      expect(
        tester.widget<TextField>(searchField('from')).focusNode!.hasFocus,
        isTrue,
      );
    });
  });

  group('shortcuts', () {
    testWidgets('a favourite chip fills both stops', (tester) async {
      await openSearch(tester, world: morning());
      await tester.tap(find.text('Kaneshie → Lapaz'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'from'), 'Kaneshie');
      expect(_text(tester, 'to'), 'Lapaz');
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('recent searches: newest first, 5 at most, a tap fills both', (
      tester,
    ) async {
      final world = morning();
      final stops = MockBackend.stops;
      SearchStop stop(String name) =>
          SearchStop(id: stops[name]!.id, name: name);
      world.searches.searches = [
        for (final (from, to) in const [
          ('Osu', 'Tema'),
          ('Legon', 'Circle'),
          ('Madina', 'Osu'),
          ('Tema', 'Achimota'),
          ('Lapaz', 'Circle'),
        ])
          RecentSearch(origin: StopOrigin(stop(from)), destination: stop(to)),
      ];
      await openSearch(tester, world: world);
      expect(find.text('Recent searches'), findsOneWidget);

      await tester.tap(find.text('Legon → Circle'));
      await tester.pumpAndSettle();
      expect((_text(tester, 'from'), _text(tester, 'to')), ('Legon', 'Circle'));

      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      final saved = world.searches.searches;
      expect(saved, hasLength(5));
      expect(saved.first.destination.name, 'Circle');
      expect((saved.first.origin as StopOrigin).stop.name, 'Legon');
      // The oldest dropped off; the repeat moved up, not doubled.
      expect(saved.map((s) => s.destination.name), [
        'Circle',
        'Tema',
        'Osu',
        'Achimota',
        'Circle',
      ]);
    });

    testWidgets('Schedule picks a date and a time', (tester) async {
      await openSearch(tester, world: morning());
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule'), findsNothing);
      expect(find.textContaining('·'), findsWidgets);
    });
  });

  group('from Home', () {
    testWidgets('a favourite chip searches at once', (tester) async {
      await openHome(tester, world: morning());
      await tester.tap(find.text('Madina → Circle'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchResultsScreen), findsOneWidget);

      await tapLabel(tester, 'Back');
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        (_text(tester, 'from'), _text(tester, 'to')),
        ('Madina', 'Circle'),
      );
    });
  });

  testWidgets('360 x 640 at text scale 1.3, keyboard open: no overflow, '
      'Search above the keyboard', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openSearch(tester, world: morning(), size: const Size(360, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await typeStop(tester, 'to', 'Ci');
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Search').last).bottom,
      lessThanOrEqualTo(640 - 300),
    );
  });
}
