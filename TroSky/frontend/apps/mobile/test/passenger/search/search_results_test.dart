import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../home/home_helpers.dart';
import 'search_helpers.dart';

Iterable<String> _plates(WidgetTester tester) => tester
    .widgetList<TroskyTripCard>(find.byType(TroskyTripCard))
    .map((c) => c.plate ?? '');

TroskyTripCard _card(WidgetTester tester, String plate) => tester
    .widgetList<TroskyTripCard>(find.byType(TroskyTripCard))
    .firstWhere((c) => c.plate == plate);

/// Three live trips whose orders differ by price and by arrival.
List<TripSearchResultResponse> _threeTrips() => [
  liveTrip(
    id: 'a',
    plate: 'A-1',
    departs: DateTime(2026, 10, 1, 9, 10),
    minutes: 80,
    fare: '10.00',
    type: VehicleType.sedan,
  ),
  liveTrip(
    id: 'b',
    plate: 'B-2',
    departs: DateTime(2026, 10, 1, 9, 20),
    minutes: 40,
    fare: '12.00',
  ),
  liveTrip(
    id: 'c',
    plate: 'C-3',
    departs: DateTime(2026, 10, 1, 9, 30),
    minutes: 40,
    fare: '8.00',
    type: VehicleType.bus,
  ),
];

void main() {
  group('mock mode: the full P6 design', () {
    testWidgets('approaching vehicles, best match, fare with saving', (
      tester,
    ) async {
      await openResults(tester);

      expect(find.text('Madina → Circle'), findsOneWidget);
      expect(
        find.text('Showing vehicles still approaching your stop'),
        findsOneWidget,
      );
      expect(_plates(tester).take(3), ['GR-4821', 'GR-2204', 'GR-7743']);
      final best = _card(tester, 'GR-4821');
      expect(best.tag, 'BEST MATCH');
      expect(best.highlighted, isTrue);
      expect(best.times, 'Departs 09:03 · ETA 09:53');
      expect(
        (best.seatsLabel, best.seatsColor),
        ('5 seats', TroskyChipColor.green),
      );
      expect(best.badge, '~3 min away · approaching your stop');
      expect(
        (best.fare?.soloPrice, best.fare?.price, best.fare?.saving),
        ('₵38', '₵14', 'Save 63%'),
      );
      final few = _card(tester, 'GR-2204');
      expect(
        (few.title, few.seatsLabel, few.seatsColor),
        ('Saloon Car', '2 seats', TroskyChipColor.amber),
      );
      expect(few.fare?.saving, 'Save 60%');
    });

    testWidgets('passed vehicles: hidden, then shown after the approaching '
        'ones', (tester) async {
      await openResults(tester, size: const Size(360, 1600));
      expect(find.text('Already passed your stop — unavailable'), findsNothing);
      // The dashed button sits right after the approaching vehicles.
      final button = find.text('Show 2 vehicles that already passed your stop');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(_plates(tester).take(5), [
        'GR-4821',
        'GR-2204',
        'GR-7743',
        'GR-1190',
        'GR-5531',
      ]);
      final passed = _card(tester, 'GR-1190');
      expect(
        (passed.passed, passed.seatsLabel, passed.onPressed),
        (true, 'Passed', null),
      );
      expect(find.text('Hide passed'), findsOneWidget);

      await tester.tap(find.text('Hide passed'));
      await tester.pumpAndSettle();
      expect(find.text('Show all'), findsOneWidget);
      expect(_plates(tester), isNot(contains('GR-1190')));
    });

    testWidgets('a card with seats opens Seat Selection; a full one is not '
        'tappable', (tester) async {
      await openResults(tester);
      // 09:30 is the first of the 15-minute departures; 10:00 is full.
      await tester.scrollUntilVisible(
        find.text('Departs 10:00 · ETA 10:50'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      final full = tester.widget<TroskyTripCard>(
        find.ancestor(
          of: find.text('Departs 10:00 · ETA 10:50'),
          matching: find.byType(TroskyTripCard),
        ),
      );
      expect(
        (full.seatsLabel, full.fare, full.onPressed),
        ('Full', null, null),
      );

      await tester.scrollUntilVisible(
        find.text('Departs 09:03 · ETA 09:53'),
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Departs 09:03 · ETA 09:53'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Departs 09:03 · ETA 09:53'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Your Seat'), findsOneWidget);
      expect(
        find.text('Madina → Circle · GR-4821 · Departs 09:03'),
        findsOneWidget,
      );
    });
  });

  group('live mode (decisions 20 and 21)', () {
    testWidgets("the backend's fare, where to board, no approaching banner", (
      tester,
    ) async {
      final world = morning();
      await openLiveResults(
        tester,
        world,
        ScriptedTrips(world.backend, [
          liveTrip(id: 't1', departs: DateTime(2026, 10, 1, 9, 15)),
        ]),
      );
      final card = _card(tester, 'GT 4402-26');
      expect(card.fare?.price, '₵8');
      expect((card.fare?.soloPrice, card.fare?.saving), (null, null));
      expect(card.badge, 'Board at Accra Madina · 350 m away');
      expect(card.badgeKind, TroskyTripBadgeKind.boardAt);
      expect(card.times, 'Departs 09:15 · ETA 10:00');
      expect(card.tag, 'BEST MATCH');
      expect(
        find.text('Showing vehicles still approaching your stop'),
        findsNothing,
      );
      expect(find.byType(TroskyDashedButton), findsNothing);
    });

    testWidgets('a pickup without a distance, and a fare with pesewas', (
      tester,
    ) async {
      final world = morning();
      await openLiveResults(
        tester,
        world,
        ScriptedTrips(world.backend, [
          liveTrip(
            id: 't1',
            departs: DateTime(2026, 10, 1, 9, 15),
            fare: '7.50',
            walk: null,
          ),
        ]),
      );
      final card = _card(tester, 'GT 4402-26');
      expect(card.badge, 'Board at Accra Madina');
      expect(card.fare?.price, '₵7.50');
    });
  });

  group('filter pills (decision 22)', () {
    testWidgets('Cheapest and Fastest sort; tapping again goes back', (
      tester,
    ) async {
      final world = morning();
      await openLiveResults(
        tester,
        world,
        ScriptedTrips(world.backend, _threeTrips()),
      );
      expect(_plates(tester), ['A-1', 'B-2', 'C-3']);
      expect(_card(tester, 'A-1').tag, 'BEST MATCH');

      await tapPill(tester, 'Cheapest');
      expect(_plates(tester), ['C-3', 'A-1', 'B-2']);
      expect(_card(tester, 'C-3').tag, 'BEST MATCH');

      await tapPill(tester, 'Fastest');
      expect(_plates(tester), ['B-2', 'C-3', 'A-1']);

      await tapPill(tester, 'Fastest');
      expect(_plates(tester), ['A-1', 'B-2', 'C-3']);
    });

    testWidgets('Minibus shows only minibuses, and says when none', (
      tester,
    ) async {
      final world = morning();
      final trips = _threeTrips();
      await openLiveResults(tester, world, ScriptedTrips(world.backend, trips));
      await tapPill(tester, 'Minibus');
      expect(_plates(tester), ['B-2']);
    });

    testWidgets('Minibus with none among the trips', (tester) async {
      final world = morning();
      await openLiveResults(
        tester,
        world,
        ScriptedTrips(world.backend, [_threeTrips().first]),
      );
      await tapPill(tester, 'Minibus');
      expect(find.text('No minibuses among these trips.'), findsOneWidget);
      await tester.tap(find.text('Show all vehicles'));
      await tester.pumpAndSettle();
      expect(_plates(tester), ['A-1']);
    });

    testWidgets('Now searches from now; Schedule from the picked time', (
      tester,
    ) async {
      final world = morning();
      final routes = ScriptedTrips(world.backend, _threeTrips());
      await openLiveResults(tester, world, routes);
      final now = routes.queries.single;
      final utc = DateTime(2026, 10, 1, 9).toUtc();
      expect(now.travelDate, DateTime.utc(utc.year, utc.month, utc.day));
      expect(
        now.departureAfter,
        Duration(hours: utc.hour, minutes: utc.minute),
      );
      expect(now.destinationStopId, MockBackend.stops['Circle']!.id);
      expect(now.originStopId, MockBackend.stops['Madina']!.id);

      await tapPill(tester, 'Schedule');
      // The date picker: the 3rd; then the time picker as it opens.
      await tester.tap(find.text('3'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(routes.queries, hasLength(2));
      final picked = DateTime(2026, 10, 3, 9).toUtc();
      expect(
        routes.queries.last.travelDate,
        DateTime.utc(picked.year, picked.month, picked.day),
      );
      expect(find.text('Sat 3 Oct · 09:00'), findsOneWidget);

      await tapPill(tester, 'Now');
      expect(find.text('Schedule'), findsOneWidget);
    });
  });

  group('loading more, refreshing, states', () {
    testWidgets('the next page loads as the list nears its end', (
      tester,
    ) async {
      final world = morning();
      final routes = ScriptedTrips(world.backend, [
        for (var i = 0; i < 45; i++)
          liveTrip(
            id: 't$i',
            plate: 'P-$i',
            departs: DateTime(
              2026,
              10,
              1,
              9,
              15,
            ).add(Duration(minutes: 10 * i)),
          ),
      ]);
      await openLiveResults(tester, world, routes);
      expect(routes.queries.map((q) => q.offset), [0]);

      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
        await tester.pumpAndSettle();
      }
      expect(routes.queries.map((q) => q.offset), [0, 20, 40]);
      expect(find.text('P-44', skipOffstage: false), findsOneWidget);
    });

    testWidgets('pull to refresh asks again', (tester) async {
      final world = morning();
      final routes = ScriptedTrips(world.backend, _threeTrips());
      await openLiveResults(tester, world, routes);
      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(routes.queries.map((q) => q.offset), [0, 0]);
    });

    testWidgets('empty: try another time', (tester) async {
      final world = morning();
      await openLiveResults(tester, world, ScriptedTrips(world.backend, []));
      expect(find.text('No vehicles on this route right now'), findsOneWidget);
      await tester.tap(find.text('Try another time'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('an error, then Retry', (tester) async {
      final world = morning();
      final routes = ScriptedTrips(world.backend, _threeTrips(), failures: 1);
      await openLiveResults(tester, world, routes);
      expect(find.byType(TroskyTripCard), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(_plates(tester), ['A-1', 'B-2', 'C-3']);
    });

    testWidgets('skeleton cards while the first page loads', (tester) async {
      final world = morning();
      final routes = _HeldTrips(world.backend, _threeTrips());
      await openLiveResults(tester, world, routes);
      expect(find.bySemanticsLabel('Loading trips'), findsOneWidget);
      expect(find.byType(TroskyTripCard), findsNothing);

      routes.release();
      await tester.pumpAndSettle();
      expect(_plates(tester), ['A-1', 'B-2', 'C-3']);
    });

    testWidgets('offline start: the offline banner on the results', (
      tester,
    ) async {
      final world = morning();
      world.tokens.token = 'mock.refresh.saved';
      world.cache.user = UserResponse(
        id: '2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41',
        phoneNumber: MockBackend.passengerPhone,
        isActive: true,
        phoneVerified: true,
        emailVerified: false,
        roles: const ['passenger'],
        createdAt: DateTime.utc(2026, 7),
      );
      world.home.favourites['2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41'] = [
        FavouriteRouteResponse(
          id: 'f1',
          originStopId: MockBackend.stops['Madina']!.id,
          originStopName: 'Madina',
          destinationStopId: MockBackend.stops['Circle']!.id,
          destinationStopName: 'Circle',
          createdAt: DateTime.utc(2026, 9),
        ),
      ];
      await openResults(
        tester,
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
      );
      expect(
        find.text("You're offline. Showing your last saved details."),
        findsOneWidget,
      );
    });
  });

  group('save this route', () {
    testWidgets('a route already saved: a filled star', (tester) async {
      await openResults(tester);
      expect(
        find.bySemanticsLabel('Saved to your favourite routes'),
        findsOneWidget,
      );
      await tapLabel(tester, 'Saved to your favourite routes');
      expect(
        find.text('This route is already in your favourites.'),
        findsOneWidget,
      );
    });

    testWidgets('a new route: saved, then on Home', (tester) async {
      final world = await openSearch(tester, world: morning());
      await tester.tap(find.text('Kaneshie → Lapaz'));
      await tester.pumpAndSettle();
      await typeStop(tester, 'to', 'Tema');
      await chooseStop(tester, 'Tema');
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();

      await tapLabel(tester, 'Save this route');
      expect(find.text('Saved to your favourite routes.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Saved to your favourite routes'),
        findsOneWidget,
      );
      final token = world.backend
          .login(
            const LoginRequest(
              identifier: '0241234567',
              password: MockBackend.seedPassword,
            ),
          )
          .valueOrNull!
          .accessToken;
      expect(
        world.backend
            .listFavouriteRoutes(token)
            .valueOrNull!
            .last
            .destinationStopName,
        'Tema',
      );
    });

    testWidgets('FAVOURITE_ROUTE_EXISTS when the list on the phone is old', (
      tester,
    ) async {
      final world = morning();
      await searchFor(
        tester,
        'Madina',
        'Circle',
        world: world,
        overrides: [wrapUserRepository(world, _ForgetfulFavourites.new)],
      );
      await tapLabel(tester, 'Save this route');
      expect(
        find.text('This route is already in your favourites.'),
        findsOneWidget,
      );
    });

    testWidgets('FAVOURITE_ROUTES_LIMIT at 20', (tester) async {
      final world = morning();
      final token = world.backend
          .login(
            const LoginRequest(
              identifier: '0241234567',
              password: MockBackend.seedPassword,
            ),
          )
          .valueOrNull!
          .accessToken;
      final names = MockBackend.stops.keys.toList();
      for (final from in names) {
        for (final to in names) {
          if (from == to) continue;
          world.backend.addFavouriteRoute(
            token,
            FavouriteRouteCreateRequest(
              originStopId: MockBackend.stops[from]!.id,
              destinationStopId: MockBackend.stops[to]!.id,
            ),
          );
        }
      }
      await searchFor(
        tester,
        'Madina',
        'Circle',
        world: world,
        overrides: [wrapUserRepository(world, _ForgetfulFavourites.new)],
      );
      // Madina → Circle exists; the limit check comes first.
      await tapLabel(tester, 'Save this route');
      expect(
        find.text('You can save up to 20 routes. Remove one first.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('360 x 640 at text scale 1.3: no overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openResults(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    final button = find.text('Show 2 vehicles that already passed your stop');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers hear a card as one sentence, and can open it', (
    tester,
  ) async {
    await openResults(tester);
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Minibus GR-4821')),
    );
    expect(
      node.label,
      'Minibus GR-4821. Departs 09:03 · ETA 09:53. 5 seats.. BEST MATCH. '
      '~3 min away · approaching your stop. ₵14. was ₵38. Save 63%',
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });
}

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

/// Favourites on the phone are empty (an old list); saving goes to the
/// backend.
class _ForgetfulFavourites implements UserRepository {
  _ForgetfulFavourites(this._inner);

  final UserRepository _inner;

  @override
  Future<Result<UserResponse>> getMe() => _inner.getMe();

  @override
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes() async =>
      const Ok([]);

  @override
  Future<Result<FavouriteRouteResponse>> addFavouriteRoute(
    FavouriteRouteCreateRequest request,
  ) => _inner.addFavouriteRoute(request);
}

/// A search that answers only when [release]d.
class _HeldTrips extends ScriptedTrips {
  _HeldTrips(super.backend, super.trips);

  final Completer<void> _gate = Completer();

  void release() => _gate.complete();

  @override
  Future<Result<Paginated<TripSearchResultResponse>>> searchTrips(
    TripSearchQuery query,
  ) async {
    await _gate.future;
    return super.searchTrips(query);
  }
}
