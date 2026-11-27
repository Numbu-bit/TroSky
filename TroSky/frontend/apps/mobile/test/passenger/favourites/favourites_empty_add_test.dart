// Step 21/B2 fix: Favourites empty state gets an "Add a favourite
// route" button that routes to Search.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/favourites/application/favourites_providers.dart';
import 'package:mobile/passenger/favourites/presentation/favourites_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

class _Tel implements TelemetryService {
  final events = <TelemetryEvent>[];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

void main() {
  testWidgets(
    'Favourites empty state shows an Add button + tapping fires telemetry',
    (tester) async {
      final tel = _Tel();
      final router = GoRouter(
        initialLocation: '/favourites',
        routes: [
          GoRoute(
            path: '/favourites',
            builder: (_, _) => const FavouritesScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (_, _) => const Scaffold(body: Text('SEARCH-STUB')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telemetryProvider.overrideWithValue(tel),
            favouritesListProvider.overrideWith((ref) async {
              return const Ok<List<FavouriteRouteResponse>>([]);
            }),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add a favourite route'), findsOneWidget);
      await tester.tap(find.text('Add a favourite route'));
      await tester.pumpAndSettle();
      expect(
        tel.events.any((e) => e.name == 'favourites_empty_add_tapped'),
        isTrue,
      );
      expect(find.text('SEARCH-STUB'), findsOneWidget);
    },
  );
}
